import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:aloka/models/budget_models.dart';
import 'package:aloka/optimization/feasibility_checker.dart';
import 'package:aloka/optimization/genetic_algorithm_engine.dart';

BudgetPlan _plan(int budget, String name) {
  final now = DateTime(2026, 11, 14);
  return BudgetPlan(
    id: 'exp_$name',
    name: name,
    monthlyBudget: budget,
    createdAt: now,
    updatedAt: now,
  );
}

List<PlanCategoryInput> _baseCategories({
  required Set<String> activeIds,
  Map<String, PriorityLevel>? priorityOverrides,
  bool includeCustom = false,
}) {
  PriorityLevel prio(String id, PriorityLevel fallback) =>
      priorityOverrides?[id] ?? fallback;

  final list = <PlanCategoryInput>[
    PlanCategoryInput(
      id: 'mkn',
      planId: 'exp',
      categoryId: 'mand_makan',
      categoryName: 'Makan',
      categoryType: CategoryType.mandatory,
      isActive: true,
      minimumAmount: 500000,
      targetAmount: 600000,
      priority: prio('mand_makan', PriorityLevel.high),
      priorityWeight: prio('mand_makan', PriorityLevel.high).defaultWeight,
    ),
    PlanCategoryInput(
      id: 'trp',
      planId: 'exp',
      categoryId: 'mand_transportasi',
      categoryName: 'Transportasi',
      categoryType: CategoryType.mandatory,
      isActive: true,
      minimumAmount: 150000,
      targetAmount: 200000,
      priority: prio('mand_transportasi', PriorityLevel.high),
      priorityWeight:
          prio('mand_transportasi', PriorityLevel.high).defaultWeight,
    ),
    PlanCategoryInput(
      id: 'int',
      planId: 'exp',
      categoryId: 'mand_internet',
      categoryName: 'Internet/Pulsa',
      categoryType: CategoryType.mandatory,
      isActive: true,
      minimumAmount: 100000,
      targetAmount: 100000,
      priority: prio('mand_internet', PriorityLevel.high),
      priorityWeight: prio('mand_internet', PriorityLevel.high).defaultWeight,
      isFixedCost: true,
    ),
    PlanCategoryInput(
      id: 'kul',
      planId: 'exp',
      categoryId: 'opt_kuliah',
      categoryName: 'Kebutuhan Kuliah',
      categoryType: CategoryType.optional,
      isActive: activeIds.contains('opt_kuliah'),
      minimumAmount: 0,
      targetAmount: 150000,
      priority: prio('opt_kuliah', PriorityLevel.medium),
      priorityWeight: prio('opt_kuliah', PriorityLevel.medium).defaultWeight,
    ),
    PlanCategoryInput(
      id: 'lib',
      planId: 'exp',
      categoryId: 'opt_liburan',
      categoryName: 'Liburan',
      categoryType: CategoryType.optional,
      isActive: activeIds.contains('opt_liburan'),
      minimumAmount: 0,
      targetAmount: 200000,
      priority: prio('opt_liburan', PriorityLevel.low),
      priorityWeight: prio('opt_liburan', PriorityLevel.low).defaultWeight,
    ),
    PlanCategoryInput(
      id: 'tab',
      planId: 'exp',
      categoryId: 'opt_tabungan',
      categoryName: 'Tabungan',
      categoryType: CategoryType.optional,
      isActive: activeIds.contains('opt_tabungan'),
      minimumAmount: 0,
      targetAmount: 250000,
      priority: prio('opt_tabungan', PriorityLevel.high),
      priorityWeight: prio('opt_tabungan', PriorityLevel.high).defaultWeight,
    ),
  ];

  if (includeCustom) {
    list.addAll([
      PlanCategoryInput(
        id: 'kst_w',
        planId: 'exp',
        categoryId: 'cust_wajib',
        categoryName: 'Kustom Wajib',
        categoryType: CategoryType.mandatory,
        isActive: true,
        minimumAmount: 50000,
        targetAmount: 100000,
        priority: PriorityLevel.medium,
        priorityWeight: PriorityLevel.medium.defaultWeight,
      ),
      PlanCategoryInput(
        id: 'kst_o',
        planId: 'exp',
        categoryId: 'cust_opsional',
        categoryName: 'Kustom Opsional',
        categoryType: CategoryType.optional,
        isActive: true,
        minimumAmount: 0,
        targetAmount: 100000,
        priority: PriorityLevel.low,
        priorityWeight: PriorityLevel.low.defaultWeight,
      ),
    ]);
  }

  return list;
}

class ScenarioDef {
  final String code;
  final int budget;
  final List<PlanCategoryInput> categories;
  const ScenarioDef(this.code, this.budget, this.categories);
}

int lastImprovingGen(List<GenerationMetric> log) {
  if (log.isEmpty) return 0;
  double best = log.first.bestFitness;
  int lastGen = 0;
  for (final m in log.skip(1)) {
    if (m.bestFitness > best + 1e-6) {
      best = m.bestFitness;
      lastGen = m.generation;
    }
  }
  return lastGen;
}

Map<String, dynamic> proportionalBaseline(
  int budget,
  List<PlanCategoryInput> cats,
) {
  final active = cats.where((c) => c.isActive).toList();
  final minSum = active.fold<int>(0, (s, c) => s + c.minimumAmount);
  final gapSum = active.fold<int>(0, (s, c) => s + (c.targetAmount - c.minimumAmount));
  final lambda = gapSum <= 0 ? 1.0 : min(1.0, (budget - minSum) / gapSum);

  double weightedSum = 0.0;
  int totalWeight = 0;
  int highCount = 0;
  int highAchieved = 0;
  int totalAlloc = 0;

  for (final c in cats) {
    if (!c.isActive) continue;
    final raw = c.minimumAmount + lambda * (c.targetAmount - c.minimumAmount);
    // Round down to nearest step 1000 above minimumAmount (or exact if at target)
    int alloc;
    if (raw >= c.targetAmount - 1e-9) {
      alloc = c.targetAmount;
    } else {
      final extra = ((raw - c.minimumAmount) / 1000).floor() * 1000;
      alloc = c.minimumAmount + max(0, extra);
    }
    totalAlloc += alloc;
    final s = c.targetAmount > c.minimumAmount
        ? ((alloc - c.minimumAmount) / (c.targetAmount - c.minimumAmount))
            .clamp(0.0, 1.0)
        : 1.0;
    weightedSum += c.priorityWeight * s;
    totalWeight += c.priorityWeight;
    if (c.priority == PriorityLevel.high) {
      highCount++;
      if (alloc >= c.targetAmount) highAchieved++;
    }
  }

  return {
    'F0': totalWeight > 0 ? weightedSum / totalWeight : 0.0,
    'highAchieved': highAchieved,
    'highTotal': highCount,
    'unallocated': budget - totalAlloc,
  };
}

void main() {
  const allOpt = {'opt_kuliah', 'opt_liburan', 'opt_tabungan'};
  final scenarios = <ScenarioDef>[
    ScenarioDef('S1', 800000, _baseCategories(activeIds: {})),
    ScenarioDef(
      'S2',
      1000000,
      _baseCategories(activeIds: {'opt_kuliah', 'opt_tabungan'}),
    ),
    ScenarioDef('S3', 1200000, _baseCategories(activeIds: allOpt)),
    ScenarioDef('S4', 1500000, _baseCategories(activeIds: allOpt)),
    ScenarioDef('S5', 2000000, _baseCategories(activeIds: allOpt)),
    ScenarioDef('S6', 750000, _baseCategories(activeIds: {})),
    ScenarioDef('S7', 700000, _baseCategories(activeIds: {})),
    ScenarioDef(
      'S8',
      1200000,
      _baseCategories(activeIds: allOpt, includeCustom: true),
    ),
    ScenarioDef(
      'S9a',
      1200000,
      _baseCategories(
        activeIds: allOpt,
        priorityOverrides: {
          'mand_makan': PriorityLevel.medium,
          'mand_transportasi': PriorityLevel.medium,
          'mand_internet': PriorityLevel.medium,
          'opt_kuliah': PriorityLevel.medium,
          'opt_liburan': PriorityLevel.medium,
          'opt_tabungan': PriorityLevel.medium,
        },
      ),
    ),
    ScenarioDef(
      'S9b',
      1200000,
      _baseCategories(
        activeIds: allOpt,
        priorityOverrides: {'opt_tabungan': PriorityLevel.low},
      ),
    ),
    ScenarioDef(
      'S9c',
      1200000,
      _baseCategories(
        activeIds: allOpt,
        priorityOverrides: {
          'mand_makan': PriorityLevel.medium,
          'mand_transportasi': PriorityLevel.medium,
          'mand_internet': PriorityLevel.medium,
          'opt_tabungan': PriorityLevel.high,
        },
      ),
    ),
  ];

  const baseEngine = GeneticAlgorithmEngine();
  final scenarioResults = <String, dynamic>{};

  for (final sc in scenarios) {
    final check = FeasibilityChecker.check(
      monthlyBudget: sc.budget,
      categories: sc.categories,
    );
    if (!check.isFeasible) {
      scenarioResults[sc.code] = {
        'feasible': false,
        'budget': sc.budget,
        'minTotal': check.minTotal,
        'shortfall': check.shortfall,
      };
      continue;
    }

    final fitnesses = <double>[];
    final convGens = <int>[];
    final timesMs = <int>[];
    int feasibleRuns = 0;
    Map<String, dynamic>? seed1Info;
    List<Map<String, dynamic>>? seed1Log;

    for (int seed = 1; seed <= 30; seed++) {
      final log = <GenerationMetric>[];
      final res = baseEngine.optimize(
        plan: _plan(sc.budget, sc.code),
        categories: sc.categories,
        seed: seed,
        convergenceLog: log,
      );
      final violations = FeasibilityChecker.validateSolution(res);
      if (violations.isEmpty) feasibleRuns++;
      fitnesses.add(res.fitnessScore);
      convGens.add(lastImprovingGen(log));
      timesMs.add(res.executionTimeMs);

      if (seed == 1) {
        final highActive = res.allocationSnapshot
            .where((a) => a.isActive && a.priority == PriorityLevel.high)
            .toList();
        final highAchieved =
            highActive.where((a) => a.status == TargetStatus.achieved).length;
        seed1Info = {
          'allocations': res.allocationSnapshot
              .map((a) => {'name': a.categoryName, 'amount': a.allocatedAmount})
              .toList(),
          'unallocated': res.unallocatedAmount,
          'fitness': res.fitnessScore,
          'highAchieved': highAchieved,
          'highTotal': highActive.length,
        };
        seed1Log = log
            .map((m) => {
                  'gen': m.generation,
                  'best': m.bestFitness,
                  'avg': m.averageFitness,
                })
            .toList();
      }
    }

    final bestF = fitnesses.reduce(max);
    final meanF = fitnesses.reduce((a, b) => a + b) / fitnesses.length;
    final sdF = sqrt(
      fitnesses.map((f) => pow(f - meanF, 2)).reduce((a, b) => a + b) /
          fitnesses.length,
    );
    final meanGen = convGens.reduce((a, b) => a + b) / convGens.length;
    final meanTime = timesMs.reduce((a, b) => a + b) / timesMs.length;

    scenarioResults[sc.code] = {
      'feasible': true,
      'budget': sc.budget,
      'feasiblePct': feasibleRuns / 30 * 100,
      'bestF': bestF,
      'meanF': meanF,
      'sdF': sdF,
      'meanGen': meanGen,
      'meanTimeMs': meanTime,
      'seed1': seed1Info,
      'seed1Log': seed1Log,
      'baseline': proportionalBaseline(sc.budget, sc.categories),
      'categories': sc.categories
          .map((c) => {
                'name': c.categoryName,
                'active': c.isActive,
                'min': c.minimumAmount,
                'target': c.targetAmount,
                'weight': c.priorityWeight,
              })
          .toList(),
    };
  }

  // Parameter experiments C0-C8 + Best Combo on S2, S3, S8
  final paramConfigs = <String, GAConfig>{
    'C0': const GAConfig(populationSize: 50, maxGenerations: 200, crossoverRate: 0.80, mutationRate: 0.05),
    'C1': const GAConfig(populationSize: 30, maxGenerations: 200, crossoverRate: 0.80, mutationRate: 0.05),
    'C2': const GAConfig(populationSize: 100, maxGenerations: 200, crossoverRate: 0.80, mutationRate: 0.05),
    'C3': const GAConfig(populationSize: 50, maxGenerations: 50, crossoverRate: 0.80, mutationRate: 0.05),
    'C4': const GAConfig(populationSize: 50, maxGenerations: 100, crossoverRate: 0.80, mutationRate: 0.05),
    'C5': const GAConfig(populationSize: 50, maxGenerations: 200, crossoverRate: 0.60, mutationRate: 0.05),
    'C6': const GAConfig(populationSize: 50, maxGenerations: 200, crossoverRate: 0.90, mutationRate: 0.05),
    'C7': const GAConfig(populationSize: 50, maxGenerations: 200, crossoverRate: 0.80, mutationRate: 0.01),
    'C8': const GAConfig(populationSize: 50, maxGenerations: 200, crossoverRate: 0.80, mutationRate: 0.10),
    'BestCombo': const GAConfig(populationSize: 100, maxGenerations: 50, crossoverRate: 0.90, mutationRate: 0.10),
  };

  final paramScenarios = scenarios.where((s) => {'S2', 'S3', 'S8'}.contains(s.code)).toList();
  final paramResults = <String, dynamic>{};

  for (final entry in paramConfigs.entries) {
    final engine = GeneticAlgorithmEngine(config: entry.value);
    final perScenario = <String, dynamic>{};

    for (final sc in paramScenarios) {
      final fList = <double>[];
      final gList = <int>[];
      final tList = <int>[];
      for (int seed = 1; seed <= 30; seed++) {
        final log = <GenerationMetric>[];
        final res = engine.optimize(
          plan: _plan(sc.budget, sc.code),
          categories: sc.categories,
          seed: seed,
          convergenceLog: log,
        );
        fList.add(res.fitnessScore);
        gList.add(lastImprovingGen(log));
        tList.add(res.executionTimeMs);
      }
      final meanF = fList.reduce((a, b) => a + b) / fList.length;
      final sdF = sqrt(
        fList.map((f) => pow(f - meanF, 2)).reduce((a, b) => a + b) / fList.length,
      );
      perScenario[sc.code] = {
        'meanF': meanF,
        'sdF': sdF,
        'meanGen': gList.reduce((a, b) => a + b) / gList.length,
        'meanTimeMs': tList.reduce((a, b) => a + b) / tList.length,
        'fitnessPerSeed': fList,
        'genPerSeed': gList,
        'timePerSeed': tList,
      };
    }
    paramResults[entry.key] = perScenario;
  }

  final out = {
    'scenarios': scenarioResults,
    'parameters': paramResults,
  };
  File('build/experiment_results.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  stdout.writeln('Saved build/experiment_results.json');
}
