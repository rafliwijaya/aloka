import 'dart:math';
import '../models/budget_models.dart';
import '../services/format_service.dart';
import 'feasibility_checker.dart';

/// Catatan metrik per generasi untuk pengujian konvergensi penelitian
class GenerationMetric {
  final int generation;
  final double bestFitness;
  final double averageFitness;
  final double bestRawWeightedSum;

  const GenerationMetric({
    required this.generation,
    required this.bestFitness,
    required this.averageFitness,
    required this.bestRawWeightedSum,
  });
}

/// Representasi individu (kromosom) dalam populasi GA
class _Individual {
  final List<int> genes;
  final double fitness;
  final double rawWeightedSum;

  const _Individual({
    required this.genes,
    required this.fitness,
    required this.rawWeightedSum,
  });
}

/// Mesin utama Algoritma Genetika (GA) untuk optimasi alokasi uang saku mahasiswa.
/// Decoupled dari UI sehingga dapat dijalankan di unit test maupun eksperimen multi-seed.
class GeneticAlgorithmEngine {
  final GAConfig config;

  const GeneticAlgorithmEngine({
    this.config = const GAConfig(),
  });

  /// Menjalankan optimasi GA untuk satu rencana anggaran dan daftar konfigurasi kategori.
  /// Mengembalikan [OptimizationResult] lengkap dengan snapshot input, parameter, dan hasil.
  OptimizationResult optimize({
    required BudgetPlan plan,
    required List<PlanCategoryInput> categories,
    int? seed,
    List<GenerationMetric>? convergenceLog,
  }) {
    final stopwatch = Stopwatch()..start();

    // 1. Pemeriksaan kelayakan sebelum GA dijalankan (MIN_TOTAL <= B)
    final feasibility = FeasibilityChecker.check(
      monthlyBudget: plan.monthlyBudget,
      categories: categories,
    );

    if (!feasibility.isFeasible) {
      throw StateError(feasibility.summaryMessage);
    }

    final random = seed != null ? Random(seed) : Random();
    final budget = plan.monthlyBudget;

    // 2. Inisialisasi Populasi (acak layak tanpa melebihi target maupun B)
    List<_Individual> population = List.generate(
      config.populationSize,
      (_) {
        final genes = _initializeChromosome(
          budget: budget,
          categories: categories,
          random: random,
        );
        return _evaluateChromosome(genes, categories);
      },
    );

    // Urutkan populasi dari fitness tertinggi ke terendah
    population.sort((a, b) => b.fitness.compareTo(a.fitness));

    _Individual bestOverall = population.first;
    int stagnantGenerations = 0;
    int generationsExecuted = 0;

    final gen0Avg = population.fold<double>(
          0.0,
          (sum, ind) => sum + ind.fitness,
        ) /
        population.length;
    convergenceLog?.add(
      GenerationMetric(
        generation: 0,
        bestFitness: population.first.fitness,
        averageFitness: gen0Avg,
        bestRawWeightedSum: population.first.rawWeightedSum,
      ),
    );

    // 3. Siklus Evolusi Generasi (Elitism -> Seleksi Turnamen -> Crossover Uniform -> Mutasi per Gen -> Repair)
    for (int gen = 1; gen <= config.maxGenerations; gen++) {
      if (bestOverall.fitness >= 0.999999) {
        break;
      }

      generationsExecuted = gen;

      // Buat generasi baru dengan Elitism
      final nextGeneration = <_Individual>[];
      final eliteCount = config.elitismCount.clamp(1, config.populationSize);
      for (int e = 0; e < eliteCount; e++) {
        nextGeneration.add(population[e]);
      }

      // Reproduksi (Selection -> Crossover -> Mutation -> Repair)
      while (nextGeneration.length < config.populationSize) {
        final parentA = _tournamentSelection(population, random);
        final parentB = _tournamentSelection(population, random);

        List<int> childGenes;
        if (random.nextDouble() <= config.crossoverRate) {
          childGenes = _uniformCrossover(parentA.genes, parentB.genes, random);
        } else {
          childGenes = List<int>.from(parentA.genes);
        }

        // Repair setelah crossover agar kendala anggaran tetap sah
        childGenes = _repairChromosome(
          genes: childGenes,
          budget: budget,
          categories: categories,
          random: random,
        );

        // Mutasi terarah per gen aktif dengan peluang P_m
        childGenes = _mutateChromosome(
          genes: childGenes,
          budget: budget,
          categories: categories,
          random: random,
        );

        // Repair setelah mutasi untuk menjamin seluruh kendala terpenuhi
        childGenes = _repairChromosome(
          genes: childGenes,
          budget: budget,
          categories: categories,
          random: random,
        );

        final childInd = _evaluateChromosome(childGenes, categories);
        nextGeneration.add(childInd);
      }

      nextGeneration.sort((a, b) => b.fitness.compareTo(a.fitness));
      population = nextGeneration;

      // Periksa peningkatan solusi terbaik dengan ambang epsilon = 10^-6
      if (population.first.fitness > bestOverall.fitness + 1e-6) {
        bestOverall = population.first;
        stagnantGenerations = 0;
      } else {
        if (population.first.fitness > bestOverall.fitness) {
          bestOverall = population.first;
        }
        stagnantGenerations++;
      }

      final avgFitness = population.fold<double>(
            0.0,
            (sum, ind) => sum + ind.fitness,
          ) /
          population.length;

      convergenceLog?.add(
        GenerationMetric(
          generation: gen,
          bestFitness: bestOverall.fitness,
          averageFitness: avgFitness,
          bestRawWeightedSum: bestOverall.rawWeightedSum,
        ),
      );

      // Early stopping jika target tercapai penuh (F == 1.0) atau stagnan selama N generasi
      if (bestOverall.fitness >= 0.999999 ||
          stagnantGenerations >= config.earlyStoppingGenerations) {
        break;
      }
    }

    stopwatch.stop();

    // 4. Bangun entitas hasil optimasi beserta penjelasan ringkas
    return _buildOptimizationResult(
      plan: plan,
      categories: categories,
      bestIndividual: bestOverall,
      generationsExecuted: generationsExecuted,
      executionTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Inisialisasi satu kromosom secara acak layak:
  /// 1. Kategori nonaktif = 0, kategori aktif dimulai dari minimumAmount (m_i).
  /// 2. Sisa dana (B - sum(m_i)) dibagikan secara acak dalam kelipatan nominalStep (u)
  ///    kepada kategori aktif yang diurutkan acak tanpa melebihi target (r_i) maupun B.
  List<int> _initializeChromosome({
    required int budget,
    required List<PlanCategoryInput> categories,
    required Random random,
  }) {
    final genes = List<int>.filled(categories.length, 0);
    int remainingBudget = budget;

    final expandableIndices = <int>[];
    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      if (!cat.isActive) {
        genes[i] = 0;
        continue;
      }
      genes[i] = cat.minimumAmount;
      remainingBudget -= cat.minimumAmount;
      if (cat.targetAmount > cat.minimumAmount) {
        expandableIndices.add(i);
      }
    }

    if (remainingBudget <= 0 || expandableIndices.isEmpty) {
      return genes;
    }

    final shuffled = List<int>.from(expandableIndices)..shuffle(random);
    for (final idx in shuffled) {
      if (remainingBudget <= 0) break;
      final room = categories[idx].targetAmount - genes[idx];
      if (room <= 0) continue;
      final maxAlloc = min(room, remainingBudget);
      final chosen = _randomSteppedAmount(
        maxAlloc,
        random,
        allowZero: true,
        exactTargetRoom: room <= remainingBudget ? room : null,
      );
      genes[idx] += chosen;
      remainingBudget -= chosen;
    }

    return genes;
  }

  /// Menghitung tingkat pemenuhan target s_i dan nilai fitness F.
  /// Menggunakan skor rata-rata berbobot F = sum(w_i * s_i) / sum(w_i).
  _Individual _evaluateChromosome(
    List<int> genes,
    List<PlanCategoryInput> categories,
  ) {
    double weightedSum = 0.0;
    int totalWeight = 0;

    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      if (!cat.isActive) continue;

      final x = genes[i];
      final m = cat.minimumAmount;
      final r = cat.targetAmount;
      final w = cat.priorityWeight;

      double s;
      if (r > m) {
        s = ((x - m) / (r - m)).clamp(0.0, 1.0);
      } else {
        // Jika r_i == m_i dan memenuhi batas minimumnya, s_i = 1
        s = x >= m ? 1.0 : 0.0;
      }

      weightedSum += w * s;
      totalWeight += w;
    }

    final fitness = totalWeight > 0 ? (weightedSum / totalWeight) : 0.0;

    return _Individual(
      genes: genes,
      fitness: fitness,
      rawWeightedSum: weightedSum,
    );
  }

  /// Tournament Selection berukuran k
  _Individual _tournamentSelection(
    List<_Individual> population,
    Random random,
  ) {
    final k = config.tournamentSize.clamp(2, population.length);
    _Individual? best;
    for (int i = 0; i < k; i++) {
      final candidate = population[random.nextInt(population.length)];
      if (best == null || candidate.fitness > best.fitness) {
        best = candidate;
      }
    }
    return best!;
  }

  /// Uniform Crossover: setiap gen anak diambil dari induk pertama atau kedua dengan peluang sama
  List<int> _uniformCrossover(
    List<int> parentA,
    List<int> parentB,
    Random random,
  ) {
    final child = List<int>.filled(parentA.length, 0);
    for (int i = 0; i < parentA.length; i++) {
      child[i] = random.nextBool() ? parentA[i] : parentB[i];
    }
    return child;
  }

  /// Mutasi terarah per gen aktif dengan peluang P_m:
  /// - Jika masih ada sisa dana U >= u (atau > 0), tambahkan sebagian ke penerima di bawah target.
  /// - Jika tidak, pindahkan nominal dari kategori donor (di atas minimum) ke penerima (di bawah target).
  List<int> _mutateChromosome({
    required List<int> genes,
    required int budget,
    required List<PlanCategoryInput> categories,
    required Random random,
  }) {
    final mutated = List<int>.from(genes);
    final step = config.nominalStep;

    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      if (!cat.isActive || cat.targetAmount <= cat.minimumAmount) continue;
      if (random.nextDouble() > config.mutationRate) continue;

      final currentTotal = mutated.fold<int>(0, (sum, val) => sum + val);
      final unallocated = budget - currentTotal;

      final receivers = <int>[];
      final donors = <int>[];
      for (int j = 0; j < categories.length; j++) {
        final c = categories[j];
        if (!c.isActive) continue;
        if (mutated[j] < c.targetAmount) receivers.add(j);
        if (mutated[j] > c.minimumAmount) donors.add(j);
      }

      if (receivers.isEmpty) break;

      if (unallocated >= step || (unallocated > 0 && unallocated < step)) {
        final recIdx = mutated[i] < cat.targetAmount
            ? i
            : receivers[random.nextInt(receivers.length)];
        final room = categories[recIdx].targetAmount - mutated[recIdx];
        final maxAdd = min(room, unallocated);
        if (maxAdd > 0) {
          final delta = _randomSteppedAmount(
            maxAdd,
            random,
            allowZero: false,
            exactTargetRoom: room <= unallocated ? room : null,
          );
          mutated[recIdx] += delta;
          continue;
        }
      }

      if (donors.isNotEmpty) {
        int? donorIdx;
        int? recIdx;

        if (mutated[i] < cat.targetAmount) {
          final otherDonors = donors.where((d) => d != i).toList();
          if (otherDonors.isNotEmpty) {
            donorIdx = otherDonors[random.nextInt(otherDonors.length)];
            recIdx = i;
          }
        }
        if (donorIdx == null && mutated[i] > cat.minimumAmount) {
          final otherReceivers = receivers.where((r) => r != i).toList();
          if (otherReceivers.isNotEmpty) {
            donorIdx = i;
            recIdx = otherReceivers[random.nextInt(otherReceivers.length)];
          }
        }
        if (donorIdx == null) {
          donorIdx = donors[random.nextInt(donors.length)];
          final otherReceivers = receivers.where((r) => r != donorIdx).toList();
          if (otherReceivers.isNotEmpty) {
            recIdx = otherReceivers[random.nextInt(otherReceivers.length)];
          }
        }

        if (recIdx != null) {
          final donorSurplus =
              mutated[donorIdx] - categories[donorIdx].minimumAmount;
          final receiverRoom = categories[recIdx].targetAmount - mutated[recIdx];
          final maxTransfer = min(donorSurplus, receiverRoom);
          if (maxTransfer > 0) {
            final transferAmount = _randomSteppedAmount(
              maxTransfer,
              random,
              allowZero: false,
              exactTargetRoom: receiverRoom <= donorSurplus ? receiverRoom : null,
            );
            mutated[donorIdx] -= transferAmount;
            mutated[recIdx] += transferAmount;
          }
        }
      }
    }

    return mutated;
  }

  /// Repair kromosom agar selalu mematuhi seluruh kendala:
  /// 1. Kategori nonaktif = 0
  /// 2. m_i <= x_i <= r_i untuk setiap kategori aktif
  /// 3. Jika sum(x_i) > B, kurangi alokasi di atas minimum mulai dari prioritas terendah
  List<int> _repairChromosome({
    required List<int> genes,
    required int budget,
    required List<PlanCategoryInput> categories,
    required Random random,
  }) {
    final repaired = List<int>.from(genes);

    // Langkah 1 & 2: Paksa nonaktif = 0 dan batasi [m_i, r_i]
    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      if (!cat.isActive) {
        repaired[i] = 0;
      } else {
        repaired[i] = repaired[i].clamp(cat.minimumAmount, cat.targetAmount);
      }
    }

    final totalAllocated = repaired.fold<int>(0, (sum, val) => sum + val);

    // Langkah 3: Jika melebihi anggaran B, kurangi dari kategori berprioritas paling rendah
    if (totalAllocated > budget) {
      int excess = totalAllocated - budget;

      final activeIndices = <int>[];
      for (int i = 0; i < categories.length; i++) {
        if (categories[i].isActive &&
            repaired[i] > categories[i].minimumAmount) {
          activeIndices.add(i);
        }
      }
      activeIndices.shuffle(random);
      activeIndices.sort(
        (a, b) =>
            categories[a].priorityWeight.compareTo(categories[b].priorityWeight),
      );

      for (final idx in activeIndices) {
        if (excess <= 0) break;
        final reducible = repaired[idx] - categories[idx].minimumAmount;
        if (reducible <= 0) continue;
        final cut = min(reducible, excess);
        repaired[idx] -= cut;
        excess -= cut;
      }
    }

    return repaired;
  }

  /// Mengambil nominal acak dalam batas [0 atau 1, maxAmount] mengikuti kelipatan nominalStep (u).
  int _randomSteppedAmount(
    int maxAmount,
    Random random, {
    required bool allowZero,
    int? exactTargetRoom,
  }) {
    if (maxAmount <= 0) return 0;
    final step = config.nominalStep;
    if (step <= 1 || maxAmount < step) {
      return allowZero ? random.nextInt(maxAmount + 1) : (1 + random.nextInt(maxAmount));
    }

    final totalSteps = maxAmount ~/ step;
    final hasExactRemainder =
        exactTargetRoom != null && exactTargetRoom == maxAmount && maxAmount % step != 0;

    if (allowZero) {
      final maxChoice = totalSteps + (hasExactRemainder ? 1 : 0);
      final picked = random.nextInt(maxChoice + 1);
      if (hasExactRemainder && picked == maxChoice) {
        return maxAmount;
      }
      return picked * step;
    }

    if (totalSteps <= 0) return maxAmount;
    final maxChoice = totalSteps + (hasExactRemainder ? 1 : 0);
    final picked = 1 + random.nextInt(maxChoice);
    if (hasExactRemainder && picked == maxChoice) {
      return maxAmount;
    }
    return (picked * step).clamp(1, maxAmount);
  }

  OptimizationResult _buildOptimizationResult({
    required BudgetPlan plan,
    required List<PlanCategoryInput> categories,
    required _Individual bestIndividual,
    required int generationsExecuted,
    required int executionTimeMs,
  }) {
    final items = <AllocationItem>[];
    int totalAllocated = 0;

    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      final allocated = cat.isActive ? bestIndividual.genes[i] : 0;
      totalAllocated += allocated;

      double ratio = 0.0;
      TargetStatus status;

      if (!cat.isActive) {
        ratio = 0.0;
        status = TargetStatus.inactive;
      } else {
        if (cat.targetAmount > cat.minimumAmount) {
          ratio = ((allocated - cat.minimumAmount) /
                  (cat.targetAmount - cat.minimumAmount))
              .clamp(0.0, 1.0);
        } else {
          ratio = allocated >= cat.minimumAmount ? 1.0 : 0.0;
        }
        status = allocated >= cat.targetAmount
            ? TargetStatus.achieved
            : TargetStatus.notAchieved;
      }

      items.add(
        AllocationItem(
          categoryId: cat.categoryId,
          categoryName: cat.categoryName,
          categoryType: cat.categoryType,
          isActive: cat.isActive,
          allocatedAmount: allocated,
          minimumAmount: cat.minimumAmount,
          targetAmount: cat.targetAmount,
          priority: cat.priority,
          priorityWeight: cat.priorityWeight,
          fulfillmentRatio: ratio,
          status: status,
          isFixedCost: cat.isFixedCost,
          isUserAdjusted: false,
          iconKey: cat.iconKey,
        ),
      );
    }

    final unallocated = plan.monthlyBudget - totalAllocated;
    final explanation = _generateExplanation(
      monthlyBudget: plan.monthlyBudget,
      items: items,
      unallocated: unallocated,
    );

    return OptimizationResult(
      id: 'opt_${DateTime.now().millisecondsSinceEpoch}',
      planId: plan.id,
      planName: plan.name,
      monthlyBudget: plan.monthlyBudget,
      createdAt: DateTime.now(),
      inputSnapshot: List<PlanCategoryInput>.from(categories),
      allocationSnapshot: items,
      fitnessScore: bestIndividual.fitness,
      rawWeightedSum: bestIndividual.rawWeightedSum,
      totalAllocated: totalAllocated,
      unallocatedAmount: unallocated,
      generationsExecuted: generationsExecuted,
      executionTimeMs: executionTimeMs,
      gaParameterSnapshot: config,
      algorithmVersion: config.algorithmVersion,
      hasManualAdjustment: false,
      summaryExplanation: explanation,
    );
  }

  String _generateExplanation({
    required int monthlyBudget,
    required List<AllocationItem> items,
    required int unallocated,
  }) {
    final active = items.where((e) => e.isActive).toList();
    final achieved =
        active.where((e) => e.status == TargetStatus.achieved).toList();
    final unachieved =
        active.where((e) => e.status == TargetStatus.notAchieved).toList();

    if (unachieved.isEmpty) {
      if (unallocated > 0) {
        return 'Seluruh target kategori aktif (${achieved.length} kategori) berhasil terpenuhi 100%. '
            'Masih terdapat sisa dana belum dialokasikan sebesar ${FormatService.formatRupiah(unallocated)}.';
      }
      return 'Seluruh target kategori aktif (${achieved.length} kategori) berhasil terpenuhi 100% sesuai anggaran.';
    }

    final unachievedNames =
        unachieved.map((e) => '${e.categoryName} (${e.priority.label})').join(', ');
    return 'Seluruh kebutuhan minimum wajib telah dijamin. '
        'Karena total target melebihi uang saku (${FormatService.formatRupiah(monthlyBudget)}), '
        'Algoritma Genetika memprioritaskan kategori berprioritas lebih tinggi sehingga '
        '${achieved.length} kategori mencapai target penuh, sementara $unachievedNames disesuaikan dengan sisa anggaran.';
  }

  /// Membuat salinan hasil optimasi baru ketika pengguna menyesuaikan nominal secara manual (Bagian 13).
  /// Tidak menimpa hasil optimasi asli di riwayat.
  OptimizationResult createManualAdjustmentCopy({
    required OptimizationResult original,
    required Map<String, int> updatedAmountsByCategoryId,
  }) {
    final updatedItems = <AllocationItem>[];
    int totalAllocated = 0;
    double weightedSum = 0.0;
    int totalWeight = 0;

    for (final item in original.allocationSnapshot) {
      if (!item.isActive) {
        updatedItems.add(item);
        continue;
      }

      final newAmount =
          updatedAmountsByCategoryId[item.categoryId] ?? item.allocatedAmount;
      final isChanged = newAmount != item.allocatedAmount || item.isUserAdjusted;
      totalAllocated += newAmount;

      double s;
      if (item.targetAmount > item.minimumAmount) {
        s = ((newAmount - item.minimumAmount) /
                (item.targetAmount - item.minimumAmount))
            .clamp(0.0, 1.0);
      } else {
        s = newAmount >= item.minimumAmount ? 1.0 : 0.0;
      }

      weightedSum += item.priorityWeight * s;
      totalWeight += item.priorityWeight;

      final status = newAmount >= item.targetAmount
          ? TargetStatus.achieved
          : TargetStatus.notAchieved;

      updatedItems.add(
        item.copyWith(
          allocatedAmount: newAmount,
          fulfillmentRatio: s,
          status: status,
          isUserAdjusted: isChanged,
        ),
      );
    }

    final fitness = totalWeight > 0 ? (weightedSum / totalWeight) : 0.0;
    final unallocated = original.monthlyBudget - totalAllocated;

    return OptimizationResult(
      id: 'opt_manual_${DateTime.now().millisecondsSinceEpoch}',
      planId: original.planId,
      planName: '${original.planName} (Penyesuaian Pengguna)',
      monthlyBudget: original.monthlyBudget,
      createdAt: DateTime.now(),
      inputSnapshot: original.inputSnapshot,
      allocationSnapshot: updatedItems,
      fitnessScore: fitness,
      rawWeightedSum: weightedSum,
      totalAllocated: totalAllocated,
      unallocatedAmount: unallocated,
      generationsExecuted: original.generationsExecuted,
      executionTimeMs: original.executionTimeMs,
      gaParameterSnapshot: original.gaParameterSnapshot,
      algorithmVersion: original.algorithmVersion,
      hasManualAdjustment: true,
      summaryExplanation:
          'Nominal alokasi ini memuat penyesuaian manual oleh pengguna dari rekomendasi awal Algoritma Genetika.',
    );
  }
}
