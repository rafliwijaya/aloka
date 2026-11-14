import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:aloka/models/budget_models.dart';
import 'package:aloka/optimization/feasibility_checker.dart';
import 'package:aloka/optimization/genetic_algorithm_engine.dart';
import 'package:aloka/services/format_service.dart';

/// Unit Test & Skrip Pengujian Eksperimen Akademis Genetic Algorithm (Aloka)
/// Menguji:
/// 1. Validasi Kelayakan Anggaran (MIN_TOTAL <= B dan penolakan MIN_TOTAL > B).
/// 2. Kepatuhan Seluruh Kendala Matematis Solusi GA (Bagian 7 & 12.B).
/// 3. Skenario Anggaran Beragam (Uang saku rendah, sedang, tinggi, biaya tetap, sisa dana).
/// 4. Eksperimen Multi-Seed (30 percobaan independen) & Eksperimen Parameter GA (Bagian 12.D & 12.E).
void main() {
  BudgetPlan buildSamplePlan(int monthlyBudget, {String name = 'Uji Anggaran'}) {
    final now = DateTime(2026, 11, 12);
    return BudgetPlan(
      id: 'plan_test',
      name: name,
      monthlyBudget: monthlyBudget,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Skenario standar sesuai Bagian 5.C dokumen konteks Aloka
  List<PlanCategoryInput> buildStandardCategories() {
    return [
      PlanCategoryInput(
        id: 'inp_1',
        planId: 'plan_test',
        categoryId: 'mand_makan',
        categoryName: 'Makan',
        categoryType: CategoryType.mandatory,
        isActive: true,
        minimumAmount: 500000,
        targetAmount: 600000,
        priority: PriorityLevel.high,
        priorityWeight: PriorityLevel.high.defaultWeight,
      ),
      PlanCategoryInput(
        id: 'inp_2',
        planId: 'plan_test',
        categoryId: 'mand_transportasi',
        categoryName: 'Transportasi',
        categoryType: CategoryType.mandatory,
        isActive: true,
        minimumAmount: 150000,
        targetAmount: 200000,
        priority: PriorityLevel.high,
        priorityWeight: PriorityLevel.high.defaultWeight,
      ),
      PlanCategoryInput(
        id: 'inp_3',
        planId: 'plan_test',
        categoryId: 'mand_internet',
        categoryName: 'Internet/Pulsa',
        categoryType: CategoryType.mandatory,
        isActive: true,
        minimumAmount: 100000,
        targetAmount: 100000,
        priority: PriorityLevel.high,
        priorityWeight: PriorityLevel.high.defaultWeight,
        isFixedCost: true,
      ),
      PlanCategoryInput(
        id: 'inp_4',
        planId: 'plan_test',
        categoryId: 'opt_kuliah',
        categoryName: 'Kebutuhan Kuliah',
        categoryType: CategoryType.optional,
        isActive: true,
        minimumAmount: 0,
        targetAmount: 150000,
        priority: PriorityLevel.medium,
        priorityWeight: PriorityLevel.medium.defaultWeight,
      ),
      PlanCategoryInput(
        id: 'inp_5',
        planId: 'plan_test',
        categoryId: 'opt_liburan',
        categoryName: 'Liburan',
        categoryType: CategoryType.optional,
        isActive: false, // Nonaktif harus selalu menghasilkan alokasi Rp0
        minimumAmount: 0,
        targetAmount: 200000,
        priority: PriorityLevel.low,
        priorityWeight: PriorityLevel.low.defaultWeight,
      ),
      PlanCategoryInput(
        id: 'inp_6',
        planId: 'plan_test',
        categoryId: 'opt_tabungan',
        categoryName: 'Tabungan',
        categoryType: CategoryType.optional,
        isActive: true,
        minimumAmount: 0,
        targetAmount: 250000,
        priority: PriorityLevel.high,
        priorityWeight: PriorityLevel.high.defaultWeight,
      ),
    ];
  }

  group('1. Pengujian Validasi Input & Kelayakan Anggaran (Bagian 6 & 12.C)', () {
    test('Menolak eksekusi GA jika MIN_TOTAL > Uang Saku (Kondisi Tidak Layak)', () {
      // Total minimum wajib = 500rb + 150rb + 100rb = Rp750.000
      final plan = buildSamplePlan(650000);
      final categories = buildStandardCategories();

      final check = FeasibilityChecker.check(
        monthlyBudget: plan.monthlyBudget,
        categories: categories,
      );

      expect(check.isFeasible, isFalse);
      expect(check.minTotal, equals(750000));
      expect(check.shortfall, equals(100000));

      const engine = GeneticAlgorithmEngine();
      expect(
        () => engine.optimize(plan: plan, categories: categories),
        throwsStateError,
      );
    });

    test('Menerima kondisi ketika MIN_TOTAL == Uang Saku', () {
      final plan = buildSamplePlan(750000);
      final categories = buildStandardCategories();

      final check = FeasibilityChecker.check(
        monthlyBudget: plan.monthlyBudget,
        categories: categories,
      );

      expect(check.isFeasible, isTrue);
      expect(check.shortfall, equals(0));

      const engine = GeneticAlgorithmEngine();
      final result = engine.optimize(plan: plan, categories: categories, seed: 42);
      expect(FeasibilityChecker.validateSolution(result), isEmpty);
      expect(result.totalAllocated, equals(750000));
      expect(result.unallocatedAmount, equals(0));
    });
  });

  group('2. Pengujian Kendala Matematis & Skenario GA (Bagian 7, 12.B, 12.C)', () {
    test('Skenario Standar Rp1.200.000 mematuhi seluruh constraint dan memprioritaskan bobot tinggi', () {
      final plan = buildSamplePlan(1200000);
      final categories = buildStandardCategories();
      const engine = GeneticAlgorithmEngine();

      final result = engine.optimize(
        plan: plan,
        categories: categories,
        seed: 101,
      );

      // Pastikan tidak ada pelanggaran constraint
      final violations = FeasibilityChecker.validateSolution(result);
      expect(violations, isEmpty);

      // Kategori nonaktif (Liburan) wajib bernilai Rp0
      final liburan = result.allocationSnapshot
          .firstWhere((e) => e.categoryId == 'opt_liburan');
      expect(liburan.allocatedAmount, equals(0));
      expect(liburan.status, equals(TargetStatus.inactive));

      // Kategori biaya tetap (Internet) wajib bernilai tetap Rp100.000
      final internet = result.allocationSnapshot
          .firstWhere((e) => e.categoryId == 'mand_internet');
      expect(internet.allocatedAmount, equals(100000));

      // Kategori berprioritas tinggi (Makan, Transportasi, Tabungan) diutamakan dibanding Kuliah (Sedang)
      final tabungan = result.allocationSnapshot
          .firstWhere((e) => e.categoryId == 'opt_tabungan');
      final kuliah = result.allocationSnapshot
          .firstWhere((e) => e.categoryId == 'opt_kuliah');
      expect(tabungan.allocatedAmount, greaterThan(kuliah.allocatedAmount));
    });

    test('Skenario Uang Saku Lebih Besar dari Total Target menyisakan Dana Belum Dialokasikan', () {
      // Total target aktif = 600rb + 200rb + 100rb + 150rb + 250rb = Rp1.300.000
      // Uang saku = Rp1.600.000 -> Harus ada sisa dana Rp300.000
      final plan = buildSamplePlan(1600000);
      final categories = buildStandardCategories();
      const engine = GeneticAlgorithmEngine();

      final result = engine.optimize(
        plan: plan,
        categories: categories,
        seed: 7,
      );

      expect(FeasibilityChecker.validateSolution(result), isEmpty);
      expect(result.fitnessScore, closeTo(1.0, 1e-6));
      expect(result.totalAllocated, equals(1300000));
      expect(result.unallocatedAmount, equals(300000));
    });
  });

  group('3. Eksperimen Akademis: Multi-Seed (30 Run) & Variasi Parameter GA (Bagian 12.D & 12.E)', () {
    test('Eksperimen 30 Seed Independen untuk Evaluasi Stabilitas Algoritma', () {
      final plan = buildSamplePlan(1200000, name: 'Eksperimen 30 Seed');
      final categories = buildStandardCategories();
      const engine = GeneticAlgorithmEngine();

      final fitnessList = <double>[];
      final timeMsList = <int>[];
      final generationsList = <int>[];
      int feasibleCount = 0;

      for (int seed = 1; seed <= 30; seed++) {
        final res = engine.optimize(
          plan: plan,
          categories: categories,
          seed: seed,
        );
        final violations = FeasibilityChecker.validateSolution(res);
        if (violations.isEmpty) {
          feasibleCount++;
        }
        fitnessList.add(res.fitnessScore);
        timeMsList.add(res.executionTimeMs);
        generationsList.add(res.generationsExecuted);
      }

      final bestFitness = fitnessList.reduce(max);
      final avgFitness =
          fitnessList.reduce((a, b) => a + b) / fitnessList.length;
      final variance = fitnessList
              .map((f) => pow(f - avgFitness, 2))
              .reduce((a, b) => a + b) /
          fitnessList.length;
      final stdDevFitness = sqrt(variance);
      final avgTimeMs =
          timeMsList.reduce((a, b) => a + b) / timeMsList.length;
      final avgGenerations =
          generationsList.reduce((a, b) => a + b) / generationsList.length;

      // Cetak tabel ringkasan ke konsol untuk dokumentasi Bab 4 Penelitian
      // ignore: avoid_print
      print('\n============================================================');
      // ignore: avoid_print
      print('HASIL EKSPERIMEN STABILITAS GA (30 SEED INDEPENDEN)');
      // ignore: avoid_print
      print('Uang Saku: ${FormatService.formatRupiah(plan.monthlyBudget)}');
      // ignore: avoid_print
      print('------------------------------------------------------------');
      // ignore: avoid_print
      print('Best Fitness     : ${bestFitness.toStringAsFixed(6)}');
      // ignore: avoid_print
      print('Mean Fitness     : ${avgFitness.toStringAsFixed(6)}');
      // ignore: avoid_print
      print('Std Dev Fitness  : ${stdDevFitness.toStringAsFixed(6)}');
      // ignore: avoid_print
      print('Mean Generations : ${avgGenerations.toStringAsFixed(2)}');
      // ignore: avoid_print
      print('Mean Time (ms)   : ${avgTimeMs.toStringAsFixed(2)} ms');
      // ignore: avoid_print
      print('Feasible Rate    : ${(feasibleCount / 30 * 100).toStringAsFixed(1)}%');
      // ignore: avoid_print
      print('============================================================\n');

      expect(feasibleCount, equals(30));
      expect(bestFitness, greaterThan(0.85));
    });

    test('Eksperimen Variasi Parameter GA (Populasi, Generasi, Crossover, Mutasi)', () {
      final plan = buildSamplePlan(1200000, name: 'Uji Parameter GA');
      final categories = buildStandardCategories();

      const parameterGrid = <GAConfig>[
        GAConfig(populationSize: 30, maxGenerations: 50, crossoverRate: 0.60, mutationRate: 0.01),
        GAConfig(populationSize: 50, maxGenerations: 100, crossoverRate: 0.80, mutationRate: 0.05),
        GAConfig(populationSize: 50, maxGenerations: 200, crossoverRate: 0.80, mutationRate: 0.05),
        GAConfig(populationSize: 100, maxGenerations: 200, crossoverRate: 0.90, mutationRate: 0.10),
      ];

      // ignore: avoid_print
      print('\n========================================================================');
      // ignore: avoid_print
      print('TABEL PENGUJIAN VARIASI PARAMETER GA (RATA-RATA 10 SEED PER KONFIGURASI)');
      // ignore: avoid_print
      print('Pop | Gen | CR   | MR   | Mean Fitness | Best Fitness | Mean Time (ms)');
      // ignore: avoid_print
      print('------------------------------------------------------------------------');

      for (final cfg in parameterGrid) {
        final engine = GeneticAlgorithmEngine(config: cfg);
        final scores = <double>[];
        final times = <int>[];

        for (int s = 1; s <= 10; s++) {
          final result = engine.optimize(
            plan: plan,
            categories: categories,
            seed: s * 17,
          );
          expect(FeasibilityChecker.validateSolution(result), isEmpty);
          scores.add(result.fitnessScore);
          times.add(result.executionTimeMs);
        }

        final meanScore = scores.reduce((a, b) => a + b) / scores.length;
        final bestScore = scores.reduce(max);
        final meanTime = times.reduce((a, b) => a + b) / times.length;

        // ignore: avoid_print
        print(
          '${cfg.populationSize.toString().padRight(3)} | '
          '${cfg.maxGenerations.toString().padRight(3)} | '
          '${cfg.crossoverRate.toStringAsFixed(2)} | '
          '${cfg.mutationRate.toStringAsFixed(2)} | '
          '${meanScore.toStringAsFixed(6).padRight(12)} | '
          '${bestScore.toStringAsFixed(6).padRight(12)} | '
          '${meanTime.toStringAsFixed(2)} ms',
        );
      }
      // ignore: avoid_print
      print('========================================================================\n');
    });
  });
}
