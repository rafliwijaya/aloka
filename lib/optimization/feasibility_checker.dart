import '../models/budget_models.dart';
import '../services/format_service.dart';

/// Hasil pemeriksaan validasi input dan kelayakan anggaran (MIN_TOTAL <= B)
class FeasibilityReport {
  final bool isFeasible;
  final int monthlyBudget;
  final int minTotal;
  final int mandatoryMinTotal;
  final int optionalMinTotal;
  final int targetTotal;
  final int shortfall; // Bernilai > 0 jika minTotal > monthlyBudget
  final List<String> errors;
  final List<PlanCategoryInput> contributingMinCategories;

  const FeasibilityReport({
    required this.isFeasible,
    required this.monthlyBudget,
    required this.minTotal,
    required this.mandatoryMinTotal,
    required this.optionalMinTotal,
    required this.targetTotal,
    required this.shortfall,
    required this.errors,
    required this.contributingMinCategories,
  });

  String get summaryMessage {
    if (isFeasible) {
      final remainingAfterMin = monthlyBudget - minTotal;
      return 'Anggaran layak dioptimalkan. Total kebutuhan minimum ${FormatService.formatRupiah(minTotal)} '
          'terpenuhi dari uang saku ${FormatService.formatRupiah(monthlyBudget)} '
          '(tersisa ${FormatService.formatRupiah(remainingAfterMin)} untuk pemenuhan target).';
    }
    if (shortfall > 0) {
      return 'Total minimum kebutuhan (${FormatService.formatRupiah(minTotal)}) '
          'melampaui uang saku (${FormatService.formatRupiah(monthlyBudget)}) '
          'sebesar ${FormatService.formatRupiah(shortfall)}. '
          'Silakan sesuaikan uang saku, batas minimum, atau kategori opsional.';
    }
    return errors.isNotEmpty
        ? errors.first
        : 'Konfigurasi anggaran belum memenuhi aturan validasi.';
  }
}

/// Modul pemeriksaan validasi input dan kelayakan solusi sebelum maupun sesudah GA berjalan.
/// Dipisahkan dari UI agar dapat diuji secara independen (unit testing).
class FeasibilityChecker {
  FeasibilityChecker._();

  /// Memvalidasi seluruh aturan input dan memeriksa apakah MIN_TOTAL <= B.
  static FeasibilityReport check({
    required int monthlyBudget,
    required List<PlanCategoryInput> categories,
  }) {
    final errors = <String>[];

    if (monthlyBudget <= 0) {
      errors.add('Total uang saku bulanan harus lebih besar dari Rp0.');
    }

    int mandatoryMinTotal = 0;
    int optionalMinTotal = 0;
    int targetTotal = 0;
    final contributingMinCategories = <PlanCategoryInput>[];

    final activeCategories = categories.where((c) => c.isActive).toList();
    if (activeCategories.isEmpty) {
      errors.add('Minimal harus ada kategori wajib yang aktif.');
    }

    for (final cat in categories) {
      // Kategori wajib tidak boleh dinonaktifkan
      if (cat.categoryType == CategoryType.mandatory && !cat.isActive) {
        errors.add('Kategori wajib "${cat.categoryName}" tidak boleh dinonaktifkan.');
      }

      if (cat.minimumAmount < 0 || cat.targetAmount < 0) {
        errors.add(
          'Nominal minimum dan target pada "${cat.categoryName}" tidak boleh negatif.',
        );
      }

      if (cat.isActive) {
        // Target setiap kategori aktif harus >= minimum kategori
        if (cat.targetAmount < cat.minimumAmount) {
          errors.add(
            'Target "${cat.categoryName}" (${FormatService.formatRupiah(cat.targetAmount)}) '
            'tidak boleh lebih kecil daripada batas minimumnya (${FormatService.formatRupiah(cat.minimumAmount)}).',
          );
        }

        // Untuk biaya tetap, minimum dan target harus konsisten
        if (cat.isFixedCost && cat.minimumAmount != cat.targetAmount) {
          errors.add(
            'Kategori biaya tetap "${cat.categoryName}" harus memiliki nilai minimum sama dengan target.',
          );
        }

        if (cat.categoryType == CategoryType.mandatory) {
          mandatoryMinTotal += cat.minimumAmount;
        } else {
          optionalMinTotal += cat.minimumAmount;
        }

        targetTotal += cat.targetAmount;

        if (cat.minimumAmount > 0) {
          contributingMinCategories.add(cat);
        }
      }
    }

    final minTotal = mandatoryMinTotal + optionalMinTotal;
    final shortfall = minTotal > monthlyBudget ? (minTotal - monthlyBudget) : 0;

    if (shortfall > 0) {
      errors.add(
        'Anggaran tidak mencukupi untuk memenuhi seluruh batas minimum kategori aktif '
        '(kurang ${FormatService.formatRupiah(shortfall)}).',
      );
    }

    return FeasibilityReport(
      isFeasible: errors.isEmpty && shortfall == 0 && monthlyBudget > 0,
      monthlyBudget: monthlyBudget,
      minTotal: minTotal,
      mandatoryMinTotal: mandatoryMinTotal,
      optionalMinTotal: optionalMinTotal,
      targetTotal: targetTotal,
      shortfall: shortfall,
      errors: errors,
      contributingMinCategories: contributingMinCategories,
    );
  }

  /// Memvalidasi apakah hasil optimasi GA memenuhi seluruh kendala matematis penelitian (Bagian 12.B).
  static List<String> validateSolution(OptimizationResult result) {
    final violations = <String>[];
    int sumAllocated = 0;

    for (final item in result.allocationSnapshot) {
      if (item.allocatedAmount < 0) {
        violations.add('Alokasi negatif pada kategori ${item.categoryName}.');
      }

      if (!item.isActive) {
        if (item.allocatedAmount != 0) {
          violations.add(
            'Kategori nonaktif ${item.categoryName} memperoleh alokasi ${item.allocatedAmount}.',
          );
        }
      } else {
        if (item.allocatedAmount < item.minimumAmount) {
          violations.add(
            'Alokasi ${item.categoryName} (${item.allocatedAmount}) di bawah minimum (${item.minimumAmount}).',
          );
        }
        if (item.allocatedAmount > item.targetAmount) {
          violations.add(
            'Alokasi ${item.categoryName} (${item.allocatedAmount}) melebihi target (${item.targetAmount}).',
          );
        }
      }

      sumAllocated += item.allocatedAmount;
    }

    if (sumAllocated > result.monthlyBudget) {
      violations.add(
        'Total alokasi ($sumAllocated) melebihi uang saku (${result.monthlyBudget}).',
      );
    }

    final expectedUnallocated = result.monthlyBudget - sumAllocated;
    if (result.unallocatedAmount != expectedUnallocated) {
      violations.add(
        'Perhitungan sisa dana tidak konsisten (${result.unallocatedAmount} vs $expectedUnallocated).',
      );
    }

    return violations;
  }
}
