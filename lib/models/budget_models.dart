import 'dart:convert';

/// Jenis kategori pengeluaran: Wajib (selalu aktif) atau Opsional (bisa toggle)
enum CategoryType {
  mandatory,
  optional;

  String get label => this == CategoryType.mandatory ? 'Wajib' : 'Opsional';

  static CategoryType fromString(String value) {
    return value == 'mandatory' ? CategoryType.mandatory : CategoryType.optional;
  }
}

/// Tingkat prioritas kategori beserta bobot numerik awal penelitian
enum PriorityLevel {
  low,
  medium,
  high;

  String get label {
    switch (this) {
      case PriorityLevel.low:
        return 'Rendah';
      case PriorityLevel.medium:
        return 'Sedang';
      case PriorityLevel.high:
        return 'Tinggi';
    }
  }

  /// Bobot numerik default sesuai spesifikasi penelitian: Rendah=1, Sedang=3, Tinggi=5
  int get defaultWeight {
    switch (this) {
      case PriorityLevel.low:
        return 1;
      case PriorityLevel.medium:
        return 3;
      case PriorityLevel.high:
        return 5;
    }
  }

  static PriorityLevel fromString(String value) {
    switch (value) {
      case 'low':
        return PriorityLevel.low;
      case 'high':
        return PriorityLevel.high;
      case 'medium':
      default:
        return PriorityLevel.medium;
    }
  }
}

/// Status pemenuhan target suatu kategori pada hasil optimasi
enum TargetStatus {
  achieved,
  notAchieved,
  inactive;

  String get label {
    switch (this) {
      case TargetStatus.achieved:
        return 'Tercapai';
      case TargetStatus.notAchieved:
        return 'Belum Tercapai';
      case TargetStatus.inactive:
        return 'Nonaktif';
    }
  }

  static TargetStatus fromString(String value) {
    switch (value) {
      case 'achieved':
        return TargetStatus.achieved;
      case 'inactive':
        return TargetStatus.inactive;
      case 'notAchieved':
      default:
        return TargetStatus.notAchieved;
    }
  }
}

/// Entitas 1: BudgetPlan (Rencana Anggaran Bulanan)
class BudgetPlan {
  final String id;
  final String name;
  final int monthlyBudget;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String note;

  const BudgetPlan({
    required this.id,
    required this.name,
    required this.monthlyBudget,
    required this.createdAt,
    required this.updatedAt,
    this.note = '',
  });

  BudgetPlan copyWith({
    String? id,
    String? name,
    int? monthlyBudget,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? note,
  }) {
    return BudgetPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'monthlyBudget': monthlyBudget,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'note': note,
    };
  }

  factory BudgetPlan.fromMap(Map<String, dynamic> map) {
    return BudgetPlan(
      id: map['id'] as String,
      name: map['name'] as String,
      monthlyBudget: (map['monthlyBudget'] as num).toInt(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      note: (map['note'] as String?) ?? '',
    );
  }
}

/// Entitas 2: BudgetCategory (Master Kategori Bawaan maupun Kustom)
class BudgetCategory {
  final String id;
  final String name;
  final CategoryType type;
  final bool isDefault;
  final bool isArchived;
  final bool isFixedCost;
  final String iconKey;

  const BudgetCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.isDefault,
    this.isArchived = false,
    this.isFixedCost = false,
    this.iconKey = 'category',
  });

  BudgetCategory copyWith({
    String? id,
    String? name,
    CategoryType? type,
    bool? isDefault,
    bool? isArchived,
    bool? isFixedCost,
    String? iconKey,
  }) {
    return BudgetCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      isFixedCost: isFixedCost ?? this.isFixedCost,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'isDefault': isDefault ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'isFixedCost': isFixedCost ? 1 : 0,
      'iconKey': iconKey,
    };
  }

  factory BudgetCategory.fromMap(Map<String, dynamic> map) {
    return BudgetCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      type: CategoryType.fromString(map['type'] as String),
      isDefault: (map['isDefault'] as num) == 1,
      isArchived: (map['isArchived'] as num? ?? 0) == 1,
      isFixedCost: (map['isFixedCost'] as num? ?? 0) == 1,
      iconKey: (map['iconKey'] as String?) ?? 'category',
    );
  }
}

/// Entitas 3: PlanCategoryInput (Konfigurasi Kategori pada Suatu Rencana)
class PlanCategoryInput {
  final String id;
  final String planId;
  final String categoryId;
  final String categoryName;
  final CategoryType categoryType;
  final bool isActive;
  final int minimumAmount; // m_i
  final int targetAmount; // r_i
  final PriorityLevel priority;
  final int priorityWeight; // w_i
  final bool isFixedCost;
  final String iconKey;

  const PlanCategoryInput({
    required this.id,
    required this.planId,
    required this.categoryId,
    required this.categoryName,
    required this.categoryType,
    required this.isActive,
    required this.minimumAmount,
    required this.targetAmount,
    required this.priority,
    required this.priorityWeight,
    this.isFixedCost = false,
    this.iconKey = 'category',
  });

  PlanCategoryInput copyWith({
    String? id,
    String? planId,
    String? categoryId,
    String? categoryName,
    CategoryType? categoryType,
    bool? isActive,
    int? minimumAmount,
    int? targetAmount,
    PriorityLevel? priority,
    int? priorityWeight,
    bool? isFixedCost,
    String? iconKey,
  }) {
    final effectiveType = categoryType ?? this.categoryType;
    final effectiveFixed = isFixedCost ?? this.isFixedCost;
    final effectiveTarget = targetAmount ?? this.targetAmount;
    final effectiveMin = effectiveFixed
        ? effectiveTarget
        : (minimumAmount ?? this.minimumAmount);
    final effectivePriority = priority ?? this.priority;

    return PlanCategoryInput(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryType: effectiveType,
      // Kategori wajib selalu aktif
      isActive: effectiveType == CategoryType.mandatory
          ? true
          : (isActive ?? this.isActive),
      minimumAmount: effectiveMin,
      targetAmount: effectiveTarget,
      priority: effectivePriority,
      priorityWeight: priorityWeight ?? effectivePriority.defaultWeight,
      isFixedCost: effectiveFixed,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planId': planId,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryType': categoryType.name,
      'isActive': (categoryType == CategoryType.mandatory || isActive) ? 1 : 0,
      'minimumAmount': minimumAmount,
      'targetAmount': targetAmount,
      'priority': priority.name,
      'priorityWeight': priorityWeight,
      'isFixedCost': isFixedCost ? 1 : 0,
      'iconKey': iconKey,
    };
  }

  factory PlanCategoryInput.fromMap(Map<String, dynamic> map) {
    final type = CategoryType.fromString(map['categoryType'] as String);
    final prio = PriorityLevel.fromString(map['priority'] as String);
    return PlanCategoryInput(
      id: map['id'] as String,
      planId: map['planId'] as String,
      categoryId: map['categoryId'] as String,
      categoryName: map['categoryName'] as String,
      categoryType: type,
      isActive: type == CategoryType.mandatory || ((map['isActive'] as num) == 1),
      minimumAmount: (map['minimumAmount'] as num).toInt(),
      targetAmount: (map['targetAmount'] as num).toInt(),
      priority: prio,
      priorityWeight: (map['priorityWeight'] as num?)?.toInt() ?? prio.defaultWeight,
      isFixedCost: (map['isFixedCost'] as num? ?? 0) == 1,
      iconKey: (map['iconKey'] as String?) ?? 'category',
    );
  }
}

/// Konfigurasi Internal Genetic Algorithm (disembunyikan dari pengguna biasa)
class GAConfig {
  final int populationSize;
  final int maxGenerations;
  final double crossoverRate;
  final double mutationRate;
  final int elitismCount;
  final int earlyStoppingGenerations;
  final int nominalStep;
  final int tournamentSize;
  final String algorithmVersion;

  const GAConfig({
    this.populationSize = 50,
    this.maxGenerations = 200,
    this.crossoverRate = 0.80,
    this.mutationRate = 0.05,
    this.elitismCount = 2,
    this.earlyStoppingGenerations = 30,
    this.nominalStep = 1000,
    this.tournamentSize = 3,
    this.algorithmVersion = 'GA-1.0.0',
  });

  Map<String, dynamic> toMap() {
    return {
      'populationSize': populationSize,
      'maxGenerations': maxGenerations,
      'crossoverRate': crossoverRate,
      'mutationRate': mutationRate,
      'elitismCount': elitismCount,
      'earlyStoppingGenerations': earlyStoppingGenerations,
      'nominalStep': nominalStep,
      'tournamentSize': tournamentSize,
      'algorithmVersion': algorithmVersion,
    };
  }

  factory GAConfig.fromMap(Map<String, dynamic> map) {
    return GAConfig(
      populationSize: (map['populationSize'] as num?)?.toInt() ?? 50,
      maxGenerations: (map['maxGenerations'] as num?)?.toInt() ?? 200,
      crossoverRate: (map['crossoverRate'] as num?)?.toDouble() ?? 0.80,
      mutationRate: (map['mutationRate'] as num?)?.toDouble() ?? 0.05,
      elitismCount: (map['elitismCount'] as num?)?.toInt() ?? 2,
      earlyStoppingGenerations:
          (map['earlyStoppingGenerations'] as num?)?.toInt() ?? 30,
      nominalStep: (map['nominalStep'] as num?)?.toInt() ?? 1000,
      tournamentSize: (map['tournamentSize'] as num?)?.toInt() ?? 3,
      algorithmVersion: (map['algorithmVersion'] as String?) ?? 'GA-1.0.0',
    );
  }
}

/// Entitas 5: AllocationItem (Rincian Hasil Alokasi per Kategori)
class AllocationItem {
  final String categoryId;
  final String categoryName;
  final CategoryType categoryType;
  final bool isActive;
  final int allocatedAmount; // x_i
  final int minimumAmount; // m_i
  final int targetAmount; // r_i
  final PriorityLevel priority;
  final int priorityWeight; // w_i
  final double fulfillmentRatio; // s_i (0.0 - 1.0)
  final TargetStatus status;
  final bool isFixedCost;
  final bool isUserAdjusted;
  final String iconKey;

  const AllocationItem({
    required this.categoryId,
    required this.categoryName,
    required this.categoryType,
    required this.isActive,
    required this.allocatedAmount,
    required this.minimumAmount,
    required this.targetAmount,
    required this.priority,
    required this.priorityWeight,
    required this.fulfillmentRatio,
    required this.status,
    this.isFixedCost = false,
    this.isUserAdjusted = false,
    this.iconKey = 'category',
  });

  /// Rasio alokasi terhadap target keseluruhan (x_i / r_i) untuk visualisasi UI
  double get targetProgressRatio {
    if (!isActive || targetAmount <= 0) {
      return isActive && allocatedAmount >= targetAmount ? 1.0 : 0.0;
    }
    return (allocatedAmount / targetAmount).clamp(0.0, 1.0);
  }

  AllocationItem copyWith({
    int? allocatedAmount,
    double? fulfillmentRatio,
    TargetStatus? status,
    bool? isUserAdjusted,
  }) {
    return AllocationItem(
      categoryId: categoryId,
      categoryName: categoryName,
      categoryType: categoryType,
      isActive: isActive,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      minimumAmount: minimumAmount,
      targetAmount: targetAmount,
      priority: priority,
      priorityWeight: priorityWeight,
      fulfillmentRatio: fulfillmentRatio ?? this.fulfillmentRatio,
      status: status ?? this.status,
      isFixedCost: isFixedCost,
      isUserAdjusted: isUserAdjusted ?? this.isUserAdjusted,
      iconKey: iconKey,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'categoryType': categoryType.name,
      'isActive': isActive ? 1 : 0,
      'allocatedAmount': allocatedAmount,
      'minimumAmount': minimumAmount,
      'targetAmount': targetAmount,
      'priority': priority.name,
      'priorityWeight': priorityWeight,
      'fulfillmentRatio': fulfillmentRatio,
      'status': status.name,
      'isFixedCost': isFixedCost ? 1 : 0,
      'isUserAdjusted': isUserAdjusted ? 1 : 0,
      'iconKey': iconKey,
    };
  }

  factory AllocationItem.fromMap(Map<String, dynamic> map) {
    return AllocationItem(
      categoryId: map['categoryId'] as String,
      categoryName: map['categoryName'] as String,
      categoryType: CategoryType.fromString(map['categoryType'] as String),
      isActive: (map['isActive'] as num) == 1,
      allocatedAmount: (map['allocatedAmount'] as num).toInt(),
      minimumAmount: (map['minimumAmount'] as num).toInt(),
      targetAmount: (map['targetAmount'] as num).toInt(),
      priority: PriorityLevel.fromString(map['priority'] as String),
      priorityWeight: (map['priorityWeight'] as num).toInt(),
      fulfillmentRatio: (map['fulfillmentRatio'] as num).toDouble(),
      status: TargetStatus.fromString(map['status'] as String),
      isFixedCost: (map['isFixedCost'] as num? ?? 0) == 1,
      isUserAdjusted: (map['isUserAdjusted'] as num? ?? 0) == 1,
      iconKey: (map['iconKey'] as String?) ?? 'category',
    );
  }
}

/// Entitas 4: OptimizationResult (Hasil Optimasi GA beserta Snapshot Lengkap)
class OptimizationResult {
  final String id;
  final String planId;
  final String planName;
  final int monthlyBudget;
  final DateTime createdAt;
  final List<PlanCategoryInput> inputSnapshot;
  final List<AllocationItem> allocationSnapshot;
  final double fitnessScore; // Skor rata-rata berbobot Z (0.0 - 1.0)
  final double rawWeightedSum; // Jumlah (w_i * s_i)
  final int totalAllocated;
  final int unallocatedAmount; // Sisa dana belum dialokasikan
  final int generationsExecuted;
  final int executionTimeMs;
  final GAConfig gaParameterSnapshot;
  final String algorithmVersion;
  final bool hasManualAdjustment;
  final String summaryExplanation;

  const OptimizationResult({
    required this.id,
    required this.planId,
    required this.planName,
    required this.monthlyBudget,
    required this.createdAt,
    required this.inputSnapshot,
    required this.allocationSnapshot,
    required this.fitnessScore,
    required this.rawWeightedSum,
    required this.totalAllocated,
    required this.unallocatedAmount,
    required this.generationsExecuted,
    required this.executionTimeMs,
    required this.gaParameterSnapshot,
    required this.algorithmVersion,
    this.hasManualAdjustment = false,
    this.summaryExplanation = '',
  });

  List<AllocationItem> get activeAllocations =>
      allocationSnapshot.where((item) => item.isActive).toList();

  List<AllocationItem> get achievedAllocations => allocationSnapshot
      .where((item) => item.isActive && item.status == TargetStatus.achieved)
      .toList();

  List<AllocationItem> get unachievedAllocations => allocationSnapshot
      .where((item) => item.isActive && item.status == TargetStatus.notAchieved)
      .toList();

  /// Mengambil nominal alokasi tabungan jika kategori tabungan aktif
  int get savingsAllocatedAmount {
    for (final item in allocationSnapshot) {
      if (item.isActive &&
          (item.categoryId == 'opt_tabungan' ||
              item.categoryName.toLowerCase().contains('tabungan'))) {
        return item.allocatedAmount;
      }
    }
    return 0;
  }

  /// Mengambil target tabungan jika kategori tabungan aktif
  int get savingsTargetAmount {
    for (final item in allocationSnapshot) {
      if (item.isActive &&
          (item.categoryId == 'opt_tabungan' ||
              item.categoryName.toLowerCase().contains('tabungan'))) {
        return item.targetAmount;
      }
    }
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planId': planId,
      'planName': planName,
      'monthlyBudget': monthlyBudget,
      'createdAt': createdAt.toIso8601String(),
      'inputSnapshot':
          jsonEncode(inputSnapshot.map((e) => e.toMap()).toList()),
      'allocationSnapshot':
          jsonEncode(allocationSnapshot.map((e) => e.toMap()).toList()),
      'fitnessScore': fitnessScore,
      'rawWeightedSum': rawWeightedSum,
      'totalAllocated': totalAllocated,
      'unallocatedAmount': unallocatedAmount,
      'generationsExecuted': generationsExecuted,
      'executionTimeMs': executionTimeMs,
      'gaParameterSnapshot': jsonEncode(gaParameterSnapshot.toMap()),
      'algorithmVersion': algorithmVersion,
      'hasManualAdjustment': hasManualAdjustment ? 1 : 0,
      'summaryExplanation': summaryExplanation,
    };
  }

  factory OptimizationResult.fromMap(Map<String, dynamic> map) {
    final decodedInputs =
        jsonDecode(map['inputSnapshot'] as String) as List<dynamic>;
    final decodedAllocations =
        jsonDecode(map['allocationSnapshot'] as String) as List<dynamic>;
    final decodedGaConfig =
        jsonDecode(map['gaParameterSnapshot'] as String) as Map<String, dynamic>;

    return OptimizationResult(
      id: map['id'] as String,
      planId: map['planId'] as String,
      planName: (map['planName'] as String?) ?? 'Rencana Anggaran',
      monthlyBudget: (map['monthlyBudget'] as num).toInt(),
      createdAt: DateTime.parse(map['createdAt'] as String),
      inputSnapshot: decodedInputs
          .map((e) => PlanCategoryInput.fromMap(e as Map<String, dynamic>))
          .toList(),
      allocationSnapshot: decodedAllocations
          .map((e) => AllocationItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      fitnessScore: (map['fitnessScore'] as num).toDouble(),
      rawWeightedSum: (map['rawWeightedSum'] as num?)?.toDouble() ?? 0.0,
      totalAllocated: (map['totalAllocated'] as num).toInt(),
      unallocatedAmount: (map['unallocatedAmount'] as num).toInt(),
      generationsExecuted: (map['generationsExecuted'] as num).toInt(),
      executionTimeMs: (map['executionTimeMs'] as num?)?.toInt() ?? 0,
      gaParameterSnapshot: GAConfig.fromMap(decodedGaConfig),
      algorithmVersion: (map['algorithmVersion'] as String?) ?? 'GA-1.0.0',
      hasManualAdjustment: (map['hasManualAdjustment'] as num? ?? 0) == 1,
      summaryExplanation: (map['summaryExplanation'] as String?) ?? '',
    );
  }
}
