import 'package:flutter/material.dart';
import '../models/budget_models.dart';
import '../services/format_service.dart';
import '../state/aloka_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/aloka_widgets.dart';

/// Halaman 1: BERANDA (mengacu pada lingkaran merah di referensi-aloka.png & desain.txt)
/// Menampilkan sapaan "Halo, [username]", pill-shaped summary chips,
/// kartu utama Mustard Gold (#EBB85E) uang saku, tombol aksi cepat persegi membulat,
/// dan kartu status optimasi Pastel Lime Green (#BCE47A).
class HomeScreen extends StatelessWidget {
  final AlokaController controller;
  final VoidCallback onStartOptimization;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.onStartOptimization,
  });

  @override
  Widget build(BuildContext context) {
    final plan = controller.activePlan;
    final budget = plan?.monthlyBudget ?? 0;
    final latest = controller.latestResult;
    final feasibility = controller.feasibilityReport;

    final totalAllocated = latest?.totalAllocated ?? feasibility.minTotal;
    final unallocated = latest?.unallocatedAmount ?? (budget - feasibility.minTotal).clamp(0, budget);
    final savingsTarget = controller.currentSavingsTarget;
    final savingsAllocated = latest?.savingsAllocatedAmount ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Atas dengan "Halo, [username]" di pojok kanan atas
          AlokaTopBar(
            username: controller.userProfile.username,
            fullname: controller.userProfile.fullname,
            onMenuTap: () => controller.setSelectedNavIndex(1),
            onProfileTap: () => controller.setSelectedNavIndex(3),
          ),
          const SizedBox(height: 18),

          // 2. Deretan Pill-Shaped Summary Chips (seperti kapsul mata uang di atas kartu kuning)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SummaryPillChip(
                  isDark: true,
                  icon: Icons.verified_user_outlined,
                  iconBg: AlokaColors.terracotta,
                  title: 'Wajib Min.',
                  value: FormatService.formatRupiah(feasibility.mandatoryMinTotal),
                ),
                const SizedBox(width: 10),
                _SummaryPillChip(
                  isDark: false,
                  icon: Icons.savings_outlined,
                  iconBg: AlokaColors.mustardGold,
                  title: 'Target Tabungan',
                  value: FormatService.formatRupiah(savingsTarget),
                ),
                const SizedBox(width: 10),
                _SummaryPillChip(
                  isDark: false,
                  icon: Icons.tune_rounded,
                  iconBg: AlokaColors.pastelLime,
                  title: 'Opsional Aktif',
                  value: '${controller.activeOptionalCount} Kategori',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Kartu Utama Uang Saku Bulanan (#EBB85E Mustard Gold)
          _MustardHeroBalanceCard(
            planName: plan?.name ?? 'Rencana Bulanan',
            monthlyBudget: budget,
            totalAllocated: totalAllocated,
            unallocatedAmount: unallocated,
            hasResult: latest != null,
          ),
          const SizedBox(height: 12),

          // Indikator garis halaman tipis di bawah kartu utama sesuai gambar referensi
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 4,
                decoration: BoxDecoration(
                  color: AlokaColors.charcoal,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 14,
                height: 4,
                decoration: BoxDecoration(
                  color: AlokaColors.borderSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 14,
                height: 4,
                decoration: BoxDecoration(
                  color: AlokaColors.borderSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 4. Deretan 4 Tombol Aksi Persegi Membulat (Quick Actions)
          Row(
            children: [
              AlokaQuickActionButton(
                icon: Icons.auto_awesome_outlined,
                label: 'Optimasi GA',
                onTap: onStartOptimization,
              ),
              AlokaQuickActionButton(
                icon: Icons.edit_note_rounded,
                label: 'Atur Anggaran',
                onTap: () => controller.setSelectedNavIndex(1),
              ),
              AlokaQuickActionButton(
                icon: Icons.history_rounded,
                label: 'Riwayat',
                onTap: () => controller.setSelectedNavIndex(2),
              ),
              AlokaQuickActionButton(
                icon: Icons.add_box_outlined,
                label: 'Kategori',
                onTap: () => controller.setSelectedNavIndex(1),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // 5. Seksi Status Alokasi ("Status Alokasi" + "Lihat Semua")
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Status Alokasi & Tabungan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              GestureDetector(
                onTap: () => controller.setSelectedNavIndex(1),
                child: Text(
                  'Atur Rencana',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AlokaColors.mustardGold,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 6. Kartu Status Pastel Lime Green (#BCE47A) mengacu pada kartu "Wallet status" di lingkaran merah
          _LimeAllocationStatusCard(
            latestResult: latest,
            feasibility: feasibility,
            savingsAllocated: savingsAllocated,
            savingsTarget: savingsTarget,
            onTapOptimize: onStartOptimization,
          ),
          const SizedBox(height: 18),

          // 7. Ringkasan Kebutuhan Wajib & Hasil Optimasi Terakhir
          _MandatorySummarySection(
            mandatoryInputs: controller.mandatoryInputs,
            latestResult: latest,
            onEditBudget: () => controller.setSelectedNavIndex(1),
          ),
        ],
      ),
    );
  }
}

class _SummaryPillChip extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final Color iconBg;
  final String title;
  final String value;

  const _SummaryPillChip({
    required this.isDark,
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? AlokaColors.charcoal : AlokaColors.surfaceWhite;
    final textColor = isDark ? AlokaColors.surfaceWhite : AlokaColors.charcoal;
    final subColor = isDark
        ? AlokaColors.surfaceWhite.withValues(alpha: 0.7)
        : AlokaColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 15,
              color: AlokaColors.charcoal,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: subColor,
                      fontSize: 10,
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MustardHeroBalanceCard extends StatelessWidget {
  final String planName;
  final int monthlyBudget;
  final int totalAllocated;
  final int unallocatedAmount;
  final bool hasResult;

  const _MustardHeroBalanceCard({
    required this.planName,
    required this.monthlyBudget,
    required this.totalAllocated,
    required this.unallocatedAmount,
    required this.hasResult,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AlokaColors.mustardGold,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          // Ornamen geometris vektor datar bergaya retro-modern di kanan bawah
          Positioned(
            right: -6,
            bottom: -10,
            child: Icon(
              Icons.auto_graph_rounded,
              size: 110,
              color: AlokaColors.terracotta.withValues(alpha: 0.22),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: AlokaColors.surfaceWhite,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 14,
                          color: AlokaColors.charcoal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Uang Saku Bulanan ($planName)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AlokaColors.charcoal,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.ac_unit_rounded,
                    color: AlokaColors.charcoal,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                FormatService.formatRupiah(monthlyBudget),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 15,
                    color: AlokaColors.charcoal,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasResult
                        ? 'Dialokasikan: ${FormatService.formatRupiah(totalAllocated)}'
                        : 'Total Minimum Wajib: ${FormatService.formatRupiah(totalAllocated)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AlokaColors.surfaceWhite.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Sisa Dana: ${FormatService.formatRupiah(unallocatedAmount)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AlokaColors.charcoal,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LimeAllocationStatusCard extends StatelessWidget {
  final OptimizationResult? latestResult;
  final dynamic feasibility;
  final int savingsAllocated;
  final int savingsTarget;
  final VoidCallback onTapOptimize;

  const _LimeAllocationStatusCard({
    required this.latestResult,
    required this.feasibility,
    required this.savingsAllocated,
    required this.savingsTarget,
    required this.onTapOptimize,
  });

  @override
  Widget build(BuildContext context) {
    final hasResult = latestResult != null;
    final fitnessPct = hasResult
        ? FormatService.formatPercentage(latestResult!.fitnessScore)
        : 'Siap Uji';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AlokaColors.pastelLime.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AlokaColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  hasResult
                      ? 'Tabungan: ${FormatService.formatRupiah(savingsAllocated)} / ${FormatService.formatRupiah(savingsTarget)}'
                      : 'Target Tabungan: ${FormatService.formatRupiah(savingsTarget)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AlokaColors.charcoal,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              InkWell(
                onTap: onTapOptimize,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AlokaColors.surfaceWhite,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.north_east_rounded,
                    size: 18,
                    color: AlokaColors.charcoal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasResult
                          ? FormatService.formatRupiah(latestResult!.totalAllocated)
                          : FormatService.formatRupiah(feasibility.minTotal as int),
                      style: Theme.of(context).textTheme.displayMedium?.copyWith(
                            fontSize: 24,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasResult
                          ? 'Skor Pemenuhan Target: $fitnessPct • ${latestResult!.achievedAllocations.length}/${latestResult!.activeAllocations.length} Tercapai'
                          : 'Belum dioptimasi • Tekan tombol panah untuk mulai GA',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AlokaColors.charcoal,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Lencana kapsul bertumpuk bergaya referensi ("€ $ CS") -> ("W O T")
              const Row(
                children: [
                  _MiniBadgePill(
                    label: 'W',
                    color: AlokaColors.terracotta,
                    textColor: AlokaColors.surfaceWhite,
                  ),
                  SizedBox(width: 4),
                  _MiniBadgePill(
                    label: 'O',
                    color: AlokaColors.mustardGold,
                    textColor: AlokaColors.charcoal,
                  ),
                  SizedBox(width: 4),
                  _MiniBadgePill(
                    label: 'GA',
                    color: AlokaColors.charcoal,
                    textColor: AlokaColors.surfaceWhite,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBadgePill extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _MiniBadgePill({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MandatorySummarySection extends StatelessWidget {
  final List<PlanCategoryInput> mandatoryInputs;
  final OptimizationResult? latestResult;
  final VoidCallback onEditBudget;

  const _MandatorySummarySection({
    required this.mandatoryInputs,
    required this.latestResult,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AlokaColors.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ringkasan Kebutuhan Wajib',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: onEditBudget,
                child: const Text('Ubah Nominal'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...mandatoryInputs.map((item) {
            final allocatedItem = latestResult?.allocationSnapshot
                .where((a) => a.categoryId == item.categoryId)
                .firstOrNull;
            final currentVal = allocatedItem?.allocatedAmount ?? item.minimumAmount;
            final ratio = item.targetAmount > 0
                ? (currentVal / item.targetAmount).clamp(0.0, 1.0)
                : 1.0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AlokaColors.dustyBlush.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              AlokaCategoryIcons.resolve(item.iconKey),
                              size: 18,
                              color: AlokaColors.charcoal,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.categoryName,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                'Min: ${FormatService.formatRupiah(item.minimumAmount)} • Target: ${FormatService.formatRupiah(item.targetAmount)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        FormatService.formatRupiah(currentVal),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AlokaHorizontalProgressBar(
                    ratio: ratio,
                    height: 8,
                    activeColor: ratio >= 1.0
                        ? AlokaColors.pastelLime
                        : AlokaColors.mustardGold,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
