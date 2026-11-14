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
    final geneCount = categories.length;

    // 2. Inisialisasi Populasi
    List<_Individual> population = List.generate(
      config.populationSize,
      (index) {
        final genes = _initializeChromosome(
          budget: budget,
          categories: categories,
          random: random,
          strategyIndex: index % 3,
        );
        return _evaluateChromosome(genes, categories);
      },
    );

    // Urutkan populasi dari fitness tertinggi ke terendah
    population.sort((a, b) => b.fitness.compareTo(a.fitness));

    _Individual bestOverall = population.first;
    int stagnantGenerations = 0;
    int generationsExecuted = 0;

    // 3. Siklus Evolusi Generasi
    for (int gen = 1; gen <= config.maxGenerations; gen++) {
      generationsExecuted = gen;

      // Catat metrik konvergensi per generasi
      final avgFitness = population.fold<double>(
            0.0,
            (sum, ind) => sum + ind.fitness,
          ) /
          population.length;

      convergenceLog?.add(
        GenerationMetric(
          generation: gen,
          bestFitness: population.first.fitness,
          averageFitness: avgFitness,
          bestRawWeightedSum: population.first.rawWeightedSum,
        ),
      );

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

        // Mutation
        if (random.nextDouble() <= config.mutationRate && geneCount > 0) {
          childGenes = _mutateChromosome(
            genes: childGenes,
            budget: budget,
            categories: categories,
            random: random,
          );
          childGenes = _repairChromosome(
            genes: childGenes,
            budget: budget,
            categories: categories,
            random: random,
          );
        }

        final childInd = _evaluateChromosome(childGenes, categories);
        nextGeneration.add(childInd);
      }

      nextGeneration.sort((a, b) => b.fitness.compareTo(a.fitness));
      population = nextGeneration;

      // Periksa peningkatan solusi terbaik
      if (population.first.fitness > bestOverall.fitness + 1e-9) {
        bestOverall = population.first;
        stagnantGenerations = 0;
      } else {
        stagnantGenerations++;
      }

      // Early stopping jika konvergen penuh (Z == 1.0) atau stagnan selama N generasi
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

  /// Inisialisasi satu kromosom yang memenuhi batas minimum, kategori nonaktif = 0,
  /// dan menyebarkan sisa anggaran secara bervariasi tanpa melebihi target maupun B.
  List<int> _initializeChromosome({
    required int budget,
    required List<PlanCategoryInput> categories,
    required Random random,
    required int strategyIndex,
  }) {
    final genes = List<int>.filled(categories.length, 0);
    int remainingBudget = budget;

    // Penuhi seluruh minimum kategori aktif terlebih dahulu
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

    // Variasi strategi penyebaran dana awal agar populasi beragam
    if (strategyIndex == 0) {
      // Strategi A: Distribusi acak berbobot prioritas
      final weightedOrder = List<int>.from(expandableIndices)
        ..sort((a, b) {
          final cmp = categories[b]
              .priorityWeight
              .compareTo(categories[a].priorityWeight);
          return cmp != 0 ? cmp : (random.nextBool() ? 1 : -1);
        });
      for (final idx in weightedOrder) {
        if (remainingBudget <= 0) break;
        final room = categories[idx].targetAmount - genes[idx];
        if (room <= 0) continue;
        final maxAlloc = min(room, remainingBudget);
        final chosen = _randomSteppedAmount(maxAlloc, random, biasHigh: true);
        genes[idx] += chosen;
        remainingBudget -= chosen;
      }
    } else if (strategyIndex == 1) {
      // Strategi B: Penyebaran acak merata per langkah
      final activePool = List<int>.from(expandableIndices);
      int safetyCounter = 0;
      while (remainingBudget > 0 &&
          activePool.isNotEmpty &&
          safetyCounter < 500) {
        safetyCounter++;
        final pickIdx = activePool[random.nextInt(activePool.length)];
        final room = categories[pickIdx].targetAmount - genes[pickIdx];
        if (room <= 0) {
          activePool.remove(pickIdx);
          continue;
        }
        final delta = min(
          min(room, remainingBudget),
          _effectiveStep(room, remainingBudget) * (1 + random.nextInt(5)),
        );
        genes[pickIdx] += delta;
        remainingBudget -= delta;
        if (genes[pickIdx] >= categories[pickIdx].targetAmount) {
          activePool.remove(pickIdx);
        }
      }
    }

    // Pastikan sisa anggaran yang masih bisa dialokasikan ke kategori di bawah target
    // terdistribusi secara acak agar kandidat awal kompetitif
    final shuffled = List<int>.from(expandableIndices)..shuffle(random);
    for (final idx in shuffled) {
      if (remainingBudget <= 0) break;
      final room = categories[idx].targetAmount - genes[idx];
      if (room <= 0) continue;
      final addAmount = min(room, remainingBudget);
      genes[idx] += addAmount;
      remainingBudget -= addAmount;
    }

    return genes;
  }

  /// Menghitung tingkat pemenuhan target s_i dan nilai fitness Z.
  /// Menggunakan skor rata-rata berbobot Z = sum(w_i * s_i) / sum(w_i).
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

  /// Tournament Selection
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

  /// Uniform Crossover: mempertukarkan gen dari dua induk secara acak
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

  /// Mutation: memindahkan sebagian nominal dari kategori donor (di atas minimum)
  /// ke kategori penerima (di bawah target) atau mengisi dari sisa anggaran.
  List<int> _mutateChromosome({
    required List<int> genes,
    required int budget,
    required List<PlanCategoryInput> categories,
    required Random random,
  }) {
    final mutated = List<int>.from(genes);
    final currentTotal = mutated.fold<int>(0, (sum, val) => sum + val);
    final unallocated = budget - currentTotal;

    final receivers = <int>[];
    final donors = <int>[];

    for (int i = 0; i < categories.length; i++) {
      final cat = categories[i];
      if (!cat.isActive) continue;
      if (mutated[i] < cat.targetAmount) {
        receivers.add(i);
      }
      if (mutated[i] > cat.minimumAmount) {
        donors.add(i);
      }
    }

    if (receivers.isEmpty) return mutated;

    // Jika masih ada dana belum dialokasikan, tambahkan ke penerima
    if (unallocated > 0 && random.nextBool()) {
      final recIdx = receivers[random.nextInt(receivers.length)];
      final room = categories[recIdx].targetAmount - mutated[recIdx];
      final maxAdd = min(room, unallocated);
      if (maxAdd > 0) {
        final delta = _randomSteppedAmount(maxAdd, random, biasHigh: false);
        mutated[recIdx] += delta;
        return mutated;
      }
    }

    // Pindahkan sebagian dana dari donor ke penerima
    if (donors.isNotEmpty) {
      final donorIdx = donors[random.nextInt(donors.length)];
      final possibleReceivers =
          receivers.where((idx) => idx != donorIdx).toList();
      if (possibleReceivers.isNotEmpty) {
        final recIdx =
            possibleReceivers[random.nextInt(possibleReceivers.length)];
        final donorSurplus =
            mutated[donorIdx] - categories[donorIdx].minimumAmount;
        final receiverRoom = categories[recIdx].targetAmount - mutated[recIdx];
        final maxTransfer = min(donorSurplus, receiverRoom);
        if (maxTransfer > 0) {
          final transferAmount =
              _randomSteppedAmount(maxTransfer, random, biasHigh: false);
          mutated[donorIdx] -= transferAmount;
          mutated[recIdx] += transferAmount;
        }
      }
    }

    return mutated;
  }

  /// Repair kromosom agar selalu mematuhi seluruh constraint:
  /// 1. Kategori nonaktif = 0
  /// 2. m_i <= x_i <= r_i untuk setiap kategori aktif
  /// 3. Jika sum(x_i) > B, kurangi alokasi di atas minimum mulai dari prioritas terendah
  /// 4. Jika sum(x_i) < B dan masih ada kategori aktif di bawah target, salurkan sisa dana
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

    int totalAllocated = repaired.fold<int>(0, (sum, val) => sum + val);

    // Langkah 3: Jika melebihi anggaran B, kurangi dari kategori berprioritas paling rendah
    if (totalAllocated > budget) {
      int excess = totalAllocated - budget;

      // Urutkan indeks kategori aktif dari bobot prioritas terendah ke tertinggi
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
    } else if (totalAllocated < budget) {
      // Langkah 4: Jika masih ada sisa anggaran dan ada kategori aktif yang belum mencapai target,
      // salurkan sisa anggaran agar tidak membiarkan dana menganggur saat target belum tercapai.
      int remaining = budget - totalAllocated;
      final needyIndices = <int>[];
      for (int i = 0; i < categories.length; i++) {
        if (categories[i].isActive &&
            repaired[i] < categories[i].targetAmount) {
          needyIndices.add(i);
        }
      }

      if (needyIndices.isNotEmpty) {
        needyIndices.shuffle(random);
        // Gunakan probabilitas agar sebagian kromosom mengutamakan prioritas tinggi
        // dan sebagian tetap mengeksplorasi kombinasi acak
        if (random.nextDouble() < 0.7) {
          needyIndices.sort(
            (a, b) => categories[b]
                .priorityWeight
                .compareTo(categories[a].priorityWeight),
          );
        }
        for (final idx in needyIndices) {
          if (remaining <= 0) break;
          final room = categories[idx].targetAmount - repaired[idx];
          if (room <= 0) continue;
          final add = min(room, remaining);
          repaired[idx] += add;
          remaining -= add;
        }
      }
    }

    return repaired;
  }

  /// Menentukan ukuran langkah efektif tanpa membulatkan input pengguna secara diam-diam.
  int _effectiveStep(int room, int remainingBudget) {
    final step = config.nominalStep;
    if (step <= 1) return 1;
    if (room % step == 0 && remainingBudget % step == 0) {
      return step;
    }
    return 1;
  }

  /// Mengambil nominal acak dalam batas [1, maxAmount] menggunakan kelipatan nominalStep
  /// (dengan fallback eksak apabila maxAmount bukan kelipatan nominalStep).
  int _randomSteppedAmount(int maxAmount, Random random, {required bool biasHigh}) {
    if (maxAmount <= 0) return 0;
    final step = config.nominalStep;
    if (maxAmount <= step || maxAmount % step != 0) {
      return biasHigh ? maxAmount : (1 + random.nextInt(maxAmount));
    }
    final totalSteps = maxAmount ~/ step;
    if (totalSteps <= 1) return maxAmount;
    final chosenSteps = biasHigh
        ? ((totalSteps + 1) ~/ 2) + random.nextInt(totalSteps - ((totalSteps + 1) ~/ 2) + 1)
        : 1 + random.nextInt(totalSteps);
    return (chosenSteps * step).clamp(step, maxAmount);
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
