import 'package:flutter/foundation.dart';
import '../data/local_database.dart';
import '../data/preferences_service.dart';
import '../models/budget_models.dart';
import '../optimization/feasibility_checker.dart';
import '../optimization/genetic_algorithm_engine.dart';
import '../services/format_service.dart';

/// Controller terpusat (ChangeNotifier) yang menghubungkan antarmuka Flutter
/// dengan penyimpanan SQLite lokal, SharedPreferences, dan mesin Genetic Algorithm.
class AlokaController extends ChangeNotifier {
  final LocalDatabase _db = LocalDatabase.instance;
  final PreferencesService _prefs = PreferencesService.instance;
  final GeneticAlgorithmEngine _gaEngine = const GeneticAlgorithmEngine();

  bool _isLoading = true;
  bool _isOptimizing = false;
  int _selectedNavIndex = 0;

  UserProfile _userProfile = const UserProfile();
  BudgetPlan? _activePlan;
  List<PlanCategoryInput> _categoryInputs = [];
  List<BudgetCategory> _allCategories = [];
  List<OptimizationResult> _history = [];
  OptimizationResult? _latestResult;
  OptimizationResult? _previousResultForComparison;

  bool get isLoading => _isLoading;
  bool get isOptimizing => _isOptimizing;
  int get selectedNavIndex => _selectedNavIndex;

  UserProfile get userProfile => _userProfile;
  BudgetPlan? get activePlan => _activePlan;
  List<PlanCategoryInput> get categoryInputs => List.unmodifiable(_categoryInputs);
  List<BudgetCategory> get allCategories => List.unmodifiable(_allCategories);
  List<OptimizationResult> get history => List.unmodifiable(_history);
  OptimizationResult? get latestResult => _latestResult;
  OptimizationResult? get previousResultForComparison => _previousResultForComparison;

  List<PlanCategoryInput> get mandatoryInputs => _categoryInputs
      .where((c) => c.categoryType == CategoryType.mandatory)
      .toList();

  List<PlanCategoryInput> get optionalInputs => _categoryInputs
      .where((c) => c.categoryType == CategoryType.optional)
      .toList();

  int get activeOptionalCount => optionalInputs.where((c) => c.isActive).length;

  /// Target tabungan pada konfigurasi rencana aktif saat ini
  int get currentSavingsTarget {
    for (final cat in _categoryInputs) {
      if (cat.isActive &&
          (cat.categoryId == 'opt_tabungan' ||
              cat.categoryName.toLowerCase().contains('tabungan'))) {
        return cat.targetAmount;
      }
    }
    return 0;
  }

  /// Laporan pemeriksaan kelayakan real-time (MIN_TOTAL <= B)
  FeasibilityReport get feasibilityReport {
    final budget = _activePlan?.monthlyBudget ?? 0;
    return FeasibilityChecker.check(
      monthlyBudget: budget,
      categories: _categoryInputs,
    );
  }

  /// Inisialisasi data awal dari SQLite dan SharedPreferences
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _userProfile = await _prefs.getUserProfile();
      final preferredPlanId = await _prefs.getActivePlanId();
      _activePlan = await _db.getActivePlan(preferredPlanId: preferredPlanId);
      await _prefs.setActivePlanId(_activePlan!.id);

      _categoryInputs = await _db.getPlanCategoryInputs(_activePlan!.id);
      _allCategories = await _db.getAllCategories(includeArchived: true);
      _history = await _db.getOptimizationHistory();
      _latestResult = _history.isNotEmpty ? _history.first : null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSelectedNavIndex(int index) {
    if (_selectedNavIndex == index) return;
    _selectedNavIndex = index;
    notifyListeners();
  }

  /// Memperbarui profil pengguna (fullname & username)
  Future<void> updateUserProfile({
    required String fullname,
    required String username,
  }) async {
    _userProfile = await _prefs.saveUserProfile(
      fullname: fullname,
      username: username,
    );
    notifyListeners();
  }

  /// Memperbarui informasi rencana anggaran (nama, nominal uang saku bulanan, catatan)
  Future<void> updateActivePlanDetails({
    String? name,
    int? monthlyBudget,
    String? note,
  }) async {
    if (_activePlan == null) return;
    final updated = _activePlan!.copyWith(
      name: (name != null && name.trim().isNotEmpty)
          ? name.trim()
          : _activePlan!.name,
      monthlyBudget: monthlyBudget ?? _activePlan!.monthlyBudget,
      note: note ?? _activePlan!.note,
      updatedAt: DateTime.now(),
    );
    _activePlan = updated;
    await _db.updatePlan(updated);
    notifyListeners();
  }

  /// Memperbarui konfigurasi satu kategori pada rencana aktif
  Future<void> updateCategoryInput(PlanCategoryInput updatedInput) async {
    if (_activePlan == null) return;
    final idx = _categoryInputs.indexWhere(
      (c) => c.id == updatedInput.id || c.categoryId == updatedInput.categoryId,
    );
    if (idx == -1) return;

    // Pastikan kategori wajib selalu aktif dan memakai ID kanonis
    final canonicalId = 'inp_${_activePlan!.id}_${updatedInput.categoryId}';
    final sanitized = (updatedInput.categoryType == CategoryType.mandatory
            ? updatedInput.copyWith(isActive: true)
            : updatedInput)
        .copyWith(
      id: canonicalId,
      planId: _activePlan!.id,
    );

    _categoryInputs[idx] = sanitized;
    await _db.savePlanCategoryInputs(_activePlan!.id, [_categoryInputs[idx]]);
    notifyListeners();
  }

  /// Toggle aktif/nonaktif untuk kategori opsional
  Future<void> toggleOptionalCategory(String inputId, bool isActive) async {
    final idx = _categoryInputs.indexWhere((c) => c.id == inputId);
    if (idx == -1) return;
    final current = _categoryInputs[idx];
    if (current.categoryType == CategoryType.mandatory) return;

    await updateCategoryInput(current.copyWith(isActive: isActive));
  }

  /// Menambahkan kategori kustom baru (Wajib / Opsional)
  Future<void> addCustomCategory({
    required String name,
    required CategoryType type,
    required int minimumAmount,
    required int targetAmount,
    required PriorityLevel priority,
    bool isFixedCost = false,
    String iconKey = 'label',
  }) async {
    if (_activePlan == null) return;
    await _db.addCustomCategory(
      planId: _activePlan!.id,
      name: name,
      type: type,
      minimumAmount: minimumAmount,
      targetAmount: targetAmount,
      priority: priority,
      isFixedCost: isFixedCost,
      iconKey: iconKey,
    );
    _categoryInputs = await _db.getPlanCategoryInputs(_activePlan!.id);
    _allCategories = await _db.getAllCategories(includeArchived: true);
    notifyListeners();
  }

  /// Mengarsipkan atau memulihkan kategori kustom tanpa menghapus riwayat lama
  Future<void> toggleArchiveCustomCategory({
    required String categoryId,
    required bool archived,
  }) async {
    if (_activePlan == null) return;
    await _db.setCustomCategoryArchived(
      categoryId: categoryId,
      planId: _activePlan!.id,
      archived: archived,
    );
    _categoryInputs = await _db.getPlanCategoryInputs(_activePlan!.id);
    _allCategories = await _db.getAllCategories(includeArchived: true);
    notifyListeners();
  }

  /// Menjalankan optimasi Genetic Algorithm dan menyimpan hasilnya ke SQLite
  Future<OptimizationResult> runGeneticOptimization({
    bool saveToHistory = true,
  }) async {
    if (_activePlan == null) {
      throw StateError('Rencana anggaran belum siap.');
    }

    final check = feasibilityReport;
    if (!check.isFeasible) {
      throw StateError(check.summaryMessage);
    }

    _isOptimizing = true;
    notifyListeners();

    try {
      // Beri jeda mikro agar indikator proses UI sempat tampil mulus
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // Jalankan multi-run ringan (3 seed berbeda) di perangkat dan ambil solusi terbaik
      OptimizationResult? bestRun;
      for (int run = 0; run < 3; run++) {
        final candidate = _gaEngine.optimize(
          plan: _activePlan!,
          categories: _categoryInputs,
        );
        if (bestRun == null || candidate.fitnessScore > bestRun.fitnessScore) {
          bestRun = candidate;
        }
      }

      final finalResult = bestRun!;
      _previousResultForComparison = _latestResult;
      _latestResult = finalResult;

      if (saveToHistory) {
        await _db.saveOptimizationResult(finalResult);
        _history = await _db.getOptimizationHistory();
      }

      return finalResult;
    } finally {
      _isOptimizing = false;
      notifyListeners();
    }
  }

  /// Menyimpan salinan hasil yang disesuaikan secara manual oleh pengguna tanpa menimpa hasil GA asli
  Future<OptimizationResult> saveManualAdjustedResult({
    required OptimizationResult originalResult,
    required Map<String, int> adjustedAmountsByCategoryId,
  }) async {
    final adjustedCopy = _gaEngine.createManualAdjustmentCopy(
      original: originalResult,
      updatedAmountsByCategoryId: adjustedAmountsByCategoryId,
    );

    _previousResultForComparison = originalResult;
    _latestResult = adjustedCopy;
    await _db.saveOptimizationResult(adjustedCopy);
    _history = await _db.getOptimizationHistory();
    notifyListeners();
    return adjustedCopy;
  }

  /// Memuat kembali snapshot input dari riwayat lama ke form anggaran untuk disimulasikan ulang
  /// dengan mengganti bersih (replace & deduplicate) kategori rencana aktif tanpa mengubah riwayat lama.
  Future<void> loadSnapshotIntoActivePlan(OptimizationResult historicalResult) async {
    if (_activePlan == null) return;
    final now = DateTime.now();
    final updatedPlan = _activePlan!.copyWith(
      name: 'Simulasi ${FormatService.formatMonthYear(now)}',
      monthlyBudget: historicalResult.monthlyBudget,
      updatedAt: now,
    );
    _activePlan = updatedPlan;
    await _db.updatePlan(updatedPlan);

    // Deduplikasi berdasarkan categoryId dan gunakan ID kanonis agar tidak pernah ganda
    final uniqueByCategoryId = <String, PlanCategoryInput>{};
    for (final item in historicalResult.inputSnapshot) {
      uniqueByCategoryId[item.categoryId] = item.copyWith(
        id: 'inp_${updatedPlan.id}_${item.categoryId}',
        planId: updatedPlan.id,
      );
    }

    await _db.replacePlanCategoryInputs(
      updatedPlan.id,
      uniqueByCategoryId.values.toList(),
    );
    _categoryInputs = await _db.getPlanCategoryInputs(updatedPlan.id);
    _previousResultForComparison = historicalResult;
    notifyListeners();
  }

  Future<void> deleteHistoryItem(String resultId) async {
    await _db.deleteOptimizationResult(resultId);
    _history = await _db.getOptimizationHistory();
    _latestResult = _history.isNotEmpty ? _history.first : null;
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    await _db.clearAllHistory();
    _history = [];
    _latestResult = null;
    _previousResultForComparison = null;
    notifyListeners();
  }
}
