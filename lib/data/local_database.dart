import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/budget_models.dart';
import '../services/format_service.dart';

/// Repository database lokal SQLite untuk menyimpan Rencana Anggaran,
/// Master Kategori (Bawaan & Kustom), Konfigurasi Kategori per Rencana,
/// serta Riwayat Hasil Optimasi secara persisten dan offline.
class LocalDatabase {
  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'aloka_budget.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE budget_categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        isDefault INTEGER NOT NULL,
        isArchived INTEGER NOT NULL DEFAULT 0,
        isFixedCost INTEGER NOT NULL DEFAULT 0,
        iconKey TEXT NOT NULL DEFAULT 'category'
      )
    ''');

    await db.execute('''
      CREATE TABLE budget_plans (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        monthlyBudget INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE plan_category_inputs (
        id TEXT PRIMARY KEY,
        planId TEXT NOT NULL,
        categoryId TEXT NOT NULL,
        categoryName TEXT NOT NULL,
        categoryType TEXT NOT NULL,
        isActive INTEGER NOT NULL,
        minimumAmount INTEGER NOT NULL,
        targetAmount INTEGER NOT NULL,
        priority TEXT NOT NULL,
        priorityWeight INTEGER NOT NULL,
        isFixedCost INTEGER NOT NULL DEFAULT 0,
        iconKey TEXT NOT NULL DEFAULT 'category'
      )
    ''');

    await db.execute('''
      CREATE TABLE optimization_results (
        id TEXT PRIMARY KEY,
        planId TEXT NOT NULL,
        planName TEXT NOT NULL,
        monthlyBudget INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        inputSnapshot TEXT NOT NULL,
        allocationSnapshot TEXT NOT NULL,
        fitnessScore REAL NOT NULL,
        rawWeightedSum REAL NOT NULL,
        totalAllocated INTEGER NOT NULL,
        unallocatedAmount INTEGER NOT NULL,
        generationsExecuted INTEGER NOT NULL,
        executionTimeMs INTEGER NOT NULL,
        gaParameterSnapshot TEXT NOT NULL,
        algorithmVersion TEXT NOT NULL,
        hasManualAdjustment INTEGER NOT NULL DEFAULT 0,
        summaryExplanation TEXT NOT NULL DEFAULT ''
      )
    ''');

    await _seedInitialData(db);
  }

  /// Mengisi kategori bawaan (Wajib & Opsional) serta contoh rencana awal sesuai dokumen konteks
  Future<void> _seedInitialData(Database db) async {
    const defaultCategories = <BudgetCategory>[
      // 3 Kategori Wajib Bawaan
      BudgetCategory(
        id: 'mand_makan',
        name: 'Makan',
        type: CategoryType.mandatory,
        isDefault: true,
        isFixedCost: false,
        iconKey: 'restaurant',
      ),
      BudgetCategory(
        id: 'mand_transportasi',
        name: 'Transportasi',
        type: CategoryType.mandatory,
        isDefault: true,
        isFixedCost: false,
        iconKey: 'directions_bus',
      ),
      BudgetCategory(
        id: 'mand_internet',
        name: 'Internet/Pulsa',
        type: CategoryType.mandatory,
        isDefault: true,
        isFixedCost: true,
        iconKey: 'wifi',
      ),
      // 4 Kategori Opsional Bawaan
      BudgetCategory(
        id: 'opt_kuliah',
        name: 'Kebutuhan Kuliah',
        type: CategoryType.optional,
        isDefault: true,
        isFixedCost: false,
        iconKey: 'school',
      ),
      BudgetCategory(
        id: 'opt_tabungan',
        name: 'Tabungan',
        type: CategoryType.optional,
        isDefault: true,
        isFixedCost: false,
        iconKey: 'savings',
      ),
      BudgetCategory(
        id: 'opt_liburan',
        name: 'Liburan',
        type: CategoryType.optional,
        isDefault: true,
        isFixedCost: false,
        iconKey: 'beach_access',
      ),
      BudgetCategory(
        id: 'opt_hiburan',
        name: 'Hiburan',
        type: CategoryType.optional,
        isDefault: true,
        isFixedCost: false,
        iconKey: 'movie',
      ),
    ];

    for (final cat in defaultCategories) {
      await db.insert('budget_categories', cat.toMap());
    }

    final now = DateTime.now();
    const defaultPlanId = 'plan_default_01';
    final defaultPlan = BudgetPlan(
      id: defaultPlanId,
      name: 'Anggaran ${FormatService.formatMonthYear(now)}',
      monthlyBudget: 1200000,
      createdAt: now,
      updatedAt: now,
      note: 'Rencana anggaran bulanan mahasiswa',
    );

    await db.insert('budget_plans', defaultPlan.toMap());

    // Gunakan format ID konsisten: inp_${planId}_${categoryId}
    final defaultInputs = <PlanCategoryInput>[
      PlanCategoryInput(
        id: 'inp_${defaultPlanId}_mand_makan',
        planId: defaultPlanId,
        categoryId: 'mand_makan',
        categoryName: 'Makan',
        categoryType: CategoryType.mandatory,
        isActive: true,
        minimumAmount: 500000,
        targetAmount: 600000,
        priority: PriorityLevel.high,
        priorityWeight: PriorityLevel.high.defaultWeight,
        isFixedCost: false,
        iconKey: 'restaurant',
      ),
      PlanCategoryInput(
        id: 'inp_${defaultPlanId}_mand_transportasi',
        planId: defaultPlanId,
        categoryId: 'mand_transportasi',
        categoryName: 'Transportasi',
        categoryType: CategoryType.mandatory,
        isActive: true,
        minimumAmount: 150000,
        targetAmount: 200000,
        priority: PriorityLevel.high,
        priorityWeight: PriorityLevel.high.defaultWeight,
        isFixedCost: false,
        iconKey: 'directions_bus',
      ),
      PlanCategoryInput(
        id: 'inp_${defaultPlanId}_mand_internet',
        planId: defaultPlanId,
        categoryId: 'mand_internet',
        categoryName: 'Internet/Pulsa',
        categoryType: CategoryType.mandatory,
        isActive: true,
        minimumAmount: 100000,
        targetAmount: 100000,
        priority: PriorityLevel.high,
        priorityWeight: PriorityLevel.high.defaultWeight,
        isFixedCost: true,
        iconKey: 'wifi',
      ),
      PlanCategoryInput(
        id: 'inp_${defaultPlanId}_opt_kuliah',
        planId: defaultPlanId,
        categoryId: 'opt_kuliah',
        categoryName: 'Kebutuhan Kuliah',
        categoryType: CategoryType.optional,
        isActive: true,
        minimumAmount: 0,
        targetAmount: 150000,
        priority: PriorityLevel.medium,
        priorityWeight: PriorityLevel.medium.defaultWeight,
        isFixedCost: false,
        iconKey: 'school',
      ),
      PlanCategoryInput(
        id: 'inp_${defaultPlanId}_opt_tabungan',
        planId: defaultPlanId,
        categoryId: 'opt_tabungan',
        categoryName: 'Tabungan',
        categoryType: CategoryType.optional,
        isActive: true,
        minimumAmount: 0,
        targetAmount: 250000,
        priority: PriorityLevel.high,
        priorityWeight: PriorityLevel.high.defaultWeight,
        isFixedCost: false,
        iconKey: 'savings',
      ),
      PlanCategoryInput(
        id: 'inp_${defaultPlanId}_opt_liburan',
        planId: defaultPlanId,
        categoryId: 'opt_liburan',
        categoryName: 'Liburan',
        categoryType: CategoryType.optional,
        isActive: false,
        minimumAmount: 0,
        targetAmount: 150000,
        priority: PriorityLevel.low,
        priorityWeight: PriorityLevel.low.defaultWeight,
        isFixedCost: false,
        iconKey: 'beach_access',
      ),
      PlanCategoryInput(
        id: 'inp_${defaultPlanId}_opt_hiburan',
        planId: defaultPlanId,
        categoryId: 'opt_hiburan',
        categoryName: 'Hiburan',
        categoryType: CategoryType.optional,
        isActive: false,
        minimumAmount: 0,
        targetAmount: 100000,
        priority: PriorityLevel.low,
        priorityWeight: PriorityLevel.low.defaultWeight,
        isFixedCost: false,
        iconKey: 'movie',
      ),
    ];

    for (final input in defaultInputs) {
      await db.insert('plan_category_inputs', input.toMap());
    }
  }

  // ===========================================================================
  // OPERASI RENCANA ANGGARAN & INPUT KATEGORI
  // ===========================================================================

  Future<BudgetPlan> getActivePlan({String? preferredPlanId}) async {
    final db = await database;
    if (preferredPlanId != null) {
      final rows = await db.query(
        'budget_plans',
        where: 'id = ?',
        whereArgs: [preferredPlanId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        return BudgetPlan.fromMap(rows.first);
      }
    }

    final rows = await db.query(
      'budget_plans',
      orderBy: 'updatedAt DESC',
      limit: 1,
    );
    return BudgetPlan.fromMap(rows.first);
  }

  Future<void> updatePlan(BudgetPlan plan) async {
    final db = await database;
    await db.update(
      'budget_plans',
      plan.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  /// Mengambil daftar kategori untuk rencana aktif sekaligus membersihkan
  /// duplikasi berdasarkan categoryId apabila pernah terjadi perbedaan format ID.
  Future<List<PlanCategoryInput>> getPlanCategoryInputs(String planId) async {
    final db = await database;
    final rows = await db.query(
      'plan_category_inputs',
      where: 'planId = ?',
      whereArgs: [planId],
    );

    final rawInputs = rows.map(PlanCategoryInput.fromMap).toList();
    final uniqueByCategoryId = <String, PlanCategoryInput>{};
    bool hasDuplicatesOrLegacyId = false;

    for (final item in rawInputs) {
      final canonicalId = 'inp_${planId}_${item.categoryId}';
      if (uniqueByCategoryId.containsKey(item.categoryId) ||
          item.id != canonicalId) {
        hasDuplicatesOrLegacyId = true;
      }
      // Prioritaskan entri yang sudah memakai canonicalId atau entri terbaru
      if (!uniqueByCategoryId.containsKey(item.categoryId) ||
          item.id == canonicalId) {
        uniqueByCategoryId[item.categoryId] = item.copyWith(
          id: canonicalId,
          planId: planId,
        );
      }
    }

    final inputs = uniqueByCategoryId.values.toList();

    // Jika ditemukan duplikat di database lokal, bersihkan otomatis agar permanen sembuh
    if (hasDuplicatesOrLegacyId) {
      await replacePlanCategoryInputs(planId, inputs);
    }

    // Urutkan kategori wajib di atas, lalu kategori opsional
    inputs.sort((a, b) {
      if (a.categoryType != b.categoryType) {
        return a.categoryType == CategoryType.mandatory ? -1 : 1;
      }
      return a.id.compareTo(b.id);
    });
    return inputs;
  }

  /// Menyimpan atau memperbarui satu/beberapa item kategori tanpa memicu duplikasi categoryId
  Future<void> savePlanCategoryInputs(
    String planId,
    List<PlanCategoryInput> inputs,
  ) async {
    final db = await database;
    final batch = db.batch();
    for (final input in inputs) {
      final canonicalId = 'inp_${planId}_${input.categoryId}';
      final normalized = input.copyWith(
        id: canonicalId,
        planId: planId,
      );
      batch.delete(
        'plan_category_inputs',
        where: 'planId = ? AND categoryId = ?',
        whereArgs: [planId, input.categoryId],
      );
      batch.insert(
        'plan_category_inputs',
        normalized.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Mengganti seluruh daftar kategori pada rencana aktif (digunakan saat memuat Simulasi dari Riwayat)
  /// sehingga tidak ada kategori yang terduplikasi.
  Future<void> replacePlanCategoryInputs(
    String planId,
    List<PlanCategoryInput> inputs,
  ) async {
    final db = await database;
    final deduplicated = <String, PlanCategoryInput>{};
    for (final item in inputs) {
      final canonicalId = 'inp_${planId}_${item.categoryId}';
      deduplicated[item.categoryId] = item.copyWith(
        id: canonicalId,
        planId: planId,
      );
    }

    await db.transaction((txn) async {
      await txn.delete(
        'plan_category_inputs',
        where: 'planId = ?',
        whereArgs: [planId],
      );
      for (final item in deduplicated.values) {
        await txn.insert(
          'plan_category_inputs',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // ===========================================================================
  // OPERASI KATEGORI KUSTOM & ARSIP
  // ===========================================================================

  Future<List<BudgetCategory>> getAllCategories({
    bool includeArchived = false,
  }) async {
    final db = await database;
    final rows = await db.query(
      'budget_categories',
      where: includeArchived ? null : 'isArchived = 0',
    );
    return rows.map(BudgetCategory.fromMap).toList();
  }

  /// Menambahkan kategori kustom baru (Wajib atau Opsional) dan mendaftarkannya ke rencana aktif.
  /// Mencegah nama duplikat.
  Future<PlanCategoryInput> addCustomCategory({
    required String planId,
    required String name,
    required CategoryType type,
    required int minimumAmount,
    required int targetAmount,
    required PriorityLevel priority,
    bool isFixedCost = false,
    String iconKey = 'label',
  }) async {
    final db = await database;
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Nama kategori tidak boleh kosong.');
    }

    final existing = await db.query('budget_categories');
    final isDuplicate = existing.any(
      (row) =>
          (row['name'] as String).toLowerCase() ==
          normalizedName.toLowerCase(),
    );
    if (isDuplicate) {
      throw ArgumentError(
        'Kategori dengan nama "$normalizedName" sudah terdaftar.',
      );
    }

    final categoryId = 'cust_${DateTime.now().millisecondsSinceEpoch}';
    final category = BudgetCategory(
      id: categoryId,
      name: normalizedName,
      type: type,
      isDefault: false,
      isArchived: false,
      isFixedCost: isFixedCost,
      iconKey: iconKey,
    );

    await db.insert('budget_categories', category.toMap());

    final effectiveMin = isFixedCost ? targetAmount : minimumAmount;
    final planInput = PlanCategoryInput(
      id: 'inp_${planId}_$categoryId',
      planId: planId,
      categoryId: categoryId,
      categoryName: normalizedName,
      categoryType: type,
      isActive: true,
      minimumAmount: effectiveMin,
      targetAmount: targetAmount,
      priority: priority,
      priorityWeight: priority.defaultWeight,
      isFixedCost: isFixedCost,
      iconKey: iconKey,
    );

    await db.insert(
      'plan_category_inputs',
      planInput.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return planInput;
  }

  /// Mengarsipkan atau mengaktifkan kembali kategori kustom agar riwayat lama tetap utuh (Bagian 4.C).
  Future<void> setCustomCategoryArchived({
    required String categoryId,
    required String planId,
    required bool archived,
  }) async {
    final db = await database;
    await db.update(
      'budget_categories',
      {'isArchived': archived ? 1 : 0},
      where: 'id = ? AND isDefault = 0',
      whereArgs: [categoryId],
    );

    if (archived) {
      await db.delete(
        'plan_category_inputs',
        where: 'planId = ? AND categoryId = ?',
        whereArgs: [planId, categoryId],
      );
    } else {
      final rows = await db.query(
        'budget_categories',
        where: 'id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final cat = BudgetCategory.fromMap(rows.first);
        final input = PlanCategoryInput(
          id: 'inp_${planId}_${cat.id}',
          planId: planId,
          categoryId: cat.id,
          categoryName: cat.name,
          categoryType: cat.type,
          isActive: cat.type == CategoryType.mandatory,
          minimumAmount: 0,
          targetAmount: 100000,
          priority: PriorityLevel.medium,
          priorityWeight: PriorityLevel.medium.defaultWeight,
          isFixedCost: cat.isFixedCost,
          iconKey: cat.iconKey,
        );
        await db.insert(
          'plan_category_inputs',
          input.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }
  }

  // ===========================================================================
  // OPERASI RIWAYAT HASIL OPTIMASI
  // ===========================================================================

  Future<void> saveOptimizationResult(OptimizationResult result) async {
    final db = await database;
    await db.insert(
      'optimization_results',
      result.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OptimizationResult>> getOptimizationHistory() async {
    final db = await database;
    final rows = await db.query(
      'optimization_results',
      orderBy: 'createdAt DESC',
    );
    return rows.map(OptimizationResult.fromMap).toList();
  }

  Future<OptimizationResult?> getLatestOptimizationResult() async {
    final db = await database;
    final rows = await db.query(
      'optimization_results',
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return OptimizationResult.fromMap(rows.first);
  }

  Future<void> deleteOptimizationResult(String resultId) async {
    final db = await database;
    await db.delete(
      'optimization_results',
      where: 'id = ?',
      whereArgs: [resultId],
    );
  }

  Future<void> clearAllHistory() async {
    final db = await database;
    await db.delete('optimization_results');
  }
}
