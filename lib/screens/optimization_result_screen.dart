import 'package:flutter/material.dart';
import '../models/budget_models.dart';
import '../services/format_service.dart';
import '../state/aloka_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/aloka_widgets.dart';

/// Halaman Hasil Optimasi & Simulasi (Mengacu pada layar tengah di referensi-aloka.png)
/// Menampilkan pill-shaped filter tabs, 2 kartu statistik berindikator progress bar
/// (Total Dialokasikan & Sisa Dana), bar distribusi proporsi kategori, perbandingan simulasi,
/// serta rincian alokasi setiap kategori dan fitur penyesuaian manual.
class OptimizationResultScreen extends StatefulWidget {
  final AlokaController controller;
  final OptimizationResult result;

  const OptimizationResultScreen({
    super.key,
    required this.controller,
    required this.result,
  });

  @override
  State<OptimizationResultScreen> createState() =>
      _OptimizationResultScreenState();
}

class _OptimizationResultScreenState extends State<OptimizationResultScreen> {
  late OptimizationResult _currentResult;
  int _selectedFilterIndex = 0; // 0: Semua, 1: Wajib, 2: Opsional, 3: Belum Tercapai
  bool _showSummaryDetail = false;

  @override
  void initState() {
    super.initState();
    _currentResult = widget.result;
  }

  String get _compactSummaryText {
    final active = _currentResult.activeAllocations;
    final achieved = _currentResult.achievedAllocations;
    if (achieved.length == active.length) {
      if (_currentResult.unallocatedAmount > 0) {
        return 'Semua ${achieved.length} target tercapai • Sisa ${FormatService.formatRupiah(_currentResult.unallocatedAmount)}';
      }
      return 'Semua ${achieved.length} target kategori tercapai 100%.';
    }
    return '${achieved.length}/${active.length} target tercapai • Prioritas tinggi diutamakan';
  }

  List<AllocationItem> get _filteredAllocations {
    final all = _currentResult.allocationSnapshot;
    switch (_selectedFilterIndex) {
      case 1:
        return all
            .where((item) => item.categoryType == CategoryType.mandatory)
            .toList();
      case 2:
        return all
            .where((item) => item.categoryType == CategoryType.optional)
            .toList();
      case 3:
        return all
            .where(
              (item) =>
                  item.isActive && item.status == TargetStatus.notAchieved,
            )
            .toList();
      case 0:
      default:
        return all;
    }
  }

  Future<void> _showManualAdjustDialog(
    BuildContext context,
    AllocationItem item,
  ) async {
    if (!item.isActive) return;

    final amountCtrl =
        TextEditingController(text: item.allocatedAmount.toString());
    String? errorMsg;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AlokaColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sesuaikan ${item.categoryName}',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Disimpan sebagai salinan baru tanpa mengubah hasil asli GA.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Min ${FormatService.formatRupiah(item.minimumAmount)} • Target ${FormatService.formatRupiah(item.targetAmount)}',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Nominal Alokasi Baru (Rp)',
                      errorText: errorMsg,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final parsed =
                            FormatService.parseRupiahInput(amountCtrl.text);
                        if (parsed == null || parsed < item.minimumAmount) {
                          setModalState(() {
                            errorMsg =
                                'Nominal tidak boleh lebih kecil dari minimum (${FormatService.formatRupiah(item.minimumAmount)}).';
                          });
                          return;
                        }

                        final otherTotal =
                            _currentResult.totalAllocated - item.allocatedAmount;
                        if (otherTotal + parsed > _currentResult.monthlyBudget) {
                          final maxAllowed =
                              _currentResult.monthlyBudget - otherTotal;
                          setModalState(() {
                            errorMsg =
                                'Total alokasi melebihi uang saku. Maksimal nominal untuk kategori ini: ${FormatService.formatRupiah(maxAllowed)}.';
                          });
                          return;
                        }

                        final updatedResult =
                            await widget.controller.saveManualAdjustedResult(
                          originalResult: _currentResult,
                          adjustedAmountsByCategoryId: {
                            item.categoryId: parsed,
                          },
                        );

                        if (mounted) {
                          setState(() => _currentResult = updatedResult);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Simpan Penyesuaian Pengguna'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final budget = _currentResult.monthlyBudget;
    final allocated = _currentResult.totalAllocated;
    final unallocated = _currentResult.unallocatedAmount;
    final allocatedRatio =
        budget > 0 ? (allocated / budget).clamp(0.0, 1.0) : 0.0;
    final unallocatedRatio =
        budget > 0 ? (unallocated / budget).clamp(0.0, 1.0) : 0.0;
    final previous = widget.controller.previousResultForComparison;

    return Scaffold(
      backgroundColor: AlokaColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header Bar bergaya layar tengah referensi (< | Hasil Optimasi | Simulasi)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AlokaColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: AlokaColors.charcoal,
                        size: 26,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        'Hasil Optimasi',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (_currentResult.hasManualAdjustment)
                        Text(
                          'Penyesuaian Pengguna',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AlokaColors.terracotta,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                    ],
                  ),
                  InkWell(
                    onTap: () async {
                      final rerun =
                          await widget.controller.runGeneticOptimization();
                      if (mounted) {
                        setState(() => _currentResult = rerun);
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AlokaColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.refresh_rounded,
                        color: AlokaColors.charcoal,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. Empat Pill Filter Sejajar Penuh (tanpa terpotong tepi kanan)
              Row(
                children: [
                  Expanded(
                    child: _CategoryFilterPill(
                      label: 'Semua',
                      isSelected: _selectedFilterIndex == 0,
                      selectedColor: AlokaColors.mustardGold,
                      onTap: () => setState(() => _selectedFilterIndex = 0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _CategoryFilterPill(
                      label: 'Wajib',
                      isSelected: _selectedFilterIndex == 1,
                      selectedColor: AlokaColors.pastelLime,
                      onTap: () => setState(() => _selectedFilterIndex = 1),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _CategoryFilterPill(
                      label: 'Opsional',
                      isSelected: _selectedFilterIndex == 2,
                      selectedColor: AlokaColors.dustyBlush,
                      onTap: () => setState(() => _selectedFilterIndex = 2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _CategoryFilterPill(
                      label: 'Belum',
                      isSelected: _selectedFilterIndex == 3,
                      selectedColor: AlokaColors.surfaceSand,
                      onTap: () => setState(() => _selectedFilterIndex = 3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 3. Judul Statistik & Badge Skor (tanpa ikon dropdown palsu)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Statistik Alokasi',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AlokaColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Bulanan • Skor ${FormatService.formatPercentage(_currentResult.fitnessScore)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AlokaColors.charcoal,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Dua Kartu Statistik Sejajar Tinggi (Total Dialokasikan & Sisa Dana)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _DualStatProgressCard(
                        icon: Icons.check_circle_outline_rounded,
                        iconBg: AlokaColors.pastelLime.withValues(alpha: 0.45),
                        label: 'Total Dialokasikan',
                        amountText: FormatService.formatRupiah(allocated),
                        ratio: allocatedRatio,
                        barColor: AlokaColors.pastelLime,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DualStatProgressCard(
                        icon: Icons.account_balance_wallet_outlined,
                        iconBg: AlokaColors.dustyBlush,
                        label: 'Sisa Dana',
                        amountText: FormatService.formatRupiah(unallocated),
                        ratio: unallocatedRatio,
                        barColor: AlokaColors.terracotta,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Kartu Distribusi Proporsi Alokasi (semua kategori terlihat tanpa kepotong)
              _AllocationDistributionCard(result: _currentResult),
              const SizedBox(height: 14),

              // 6. Ringkasan Singkat (Ketuk untuk detail lengkap)
              InkWell(
                onTap: () =>
                    setState(() => _showSummaryDetail = !_showSummaryDetail),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AlokaColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AlokaColors.charcoal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ringkasan Pemenuhan Target',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          Icon(
                            _showSummaryDetail
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                            color: AlokaColors.charcoal,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _compactSummaryText,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AlokaColors.charcoal,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (_showSummaryDetail) ...[
                        const Divider(height: 18),
                        Text(
                          _currentResult.summaryExplanation,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AlokaColors.textSecondary,
                                height: 1.45,
                              ),
                        ),
                        if (previous != null &&
                            previous.id != _currentResult.id) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Banding sebelumnya: Skor ${FormatService.formatPercentage(previous.fitnessScore)} → ${FormatService.formatPercentage(_currentResult.fitnessScore)}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AlokaColors.charcoal,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 7. Daftar Rincian Kategori
              Text(
                'Rincian Alokasi Kategori',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),

              if (_filteredAllocations.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AlokaColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Tidak ada kategori pada filter ini.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                ..._filteredAllocations.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AllocationItemResultTile(
                      item: item,
                      onTapAdjust: () => _showManualAdjustDialog(context, item),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _CategoryFilterPill({
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : AlokaColors.surfaceSand,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DualStatProgressCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final String amountText;
  final double ratio;
  final Color barColor;

  const _DualStatProgressCard({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.amountText,
    required this.ratio,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final pctText = FormatService.formatPercentage(ratio);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AlokaColors.surfaceWhite,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AlokaColors.charcoal),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amountText,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0%', style: Theme.of(context).textTheme.bodySmall),
              Text(
                pctText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AlokaColors.charcoal,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text('100%', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 5),
          AlokaHorizontalProgressBar(
            ratio: ratio,
            activeColor: barColor,
            height: 12,
          ),
        ],
      ),
    );
  }
}

class _AllocationDistributionCard extends StatelessWidget {
  final OptimizationResult result;

  const _AllocationDistributionCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final activeItems = result.activeAllocations;
    final budget = result.monthlyBudget > 0 ? result.monthlyBudget : 1;

    const segmentPalette = <Color>[
      AlokaColors.mustardGold,
      AlokaColors.pastelLime,
      AlokaColors.terracotta,
      AlokaColors.dustyBlush,
      AlokaColors.charcoal,
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AlokaColors.surfaceWhite,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Distribusi Alokasi Kategori',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Icon(
                Icons.pie_chart_outline_rounded,
                size: 18,
                color: AlokaColors.charcoal,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Segmented Horizontal Bar Chart
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 11,
              child: Row(
                children: [
                  ...List.generate(activeItems.length, (idx) {
                    final item = activeItems[idx];
                    final flex =
                        ((item.allocatedAmount / budget) * 1000).round();
                    if (flex <= 0) return const SizedBox.shrink();
                    return Expanded(
                      flex: flex,
                      child: Container(
                        margin: const EdgeInsets.only(right: 2),
                        color: segmentPalette[idx % segmentPalette.length],
                      ),
                    );
                  }),
                  if (result.unallocatedAmount > 0)
                    Expanded(
                      flex:
                          ((result.unallocatedAmount / budget) * 1000).round(),
                      child: Container(color: AlokaColors.surfaceSand),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Wrap chip porsi kategori agar seluruh kategori tampil utuh
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(activeItems.length, (idx) {
              final item = activeItems[idx];
              final share = (item.allocatedAmount / budget).clamp(0.0, 1.0);
              final color = segmentPalette[idx % segmentPalette.length];

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AlokaColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AlokaCategoryIcons.resolve(item.iconKey),
                        size: 13,
                        color: AlokaColors.charcoal,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.categoryName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AlokaColors.charcoal,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      FormatService.formatPercentage(share),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _AllocationItemResultTile extends StatelessWidget {
  final AllocationItem item;
  final VoidCallback onTapAdjust;

  const _AllocationItemResultTile({
    required this.item,
    required this.onTapAdjust,
  });

  @override
  Widget build(BuildContext context) {
    final pct = FormatService.formatPercentage(item.targetProgressRatio);
    Color badgeColor;
    if (!item.isActive) {
      badgeColor = AlokaColors.surfaceSand;
    } else if (item.status == TargetStatus.achieved) {
      badgeColor = AlokaColors.pastelLime;
    } else {
      badgeColor = AlokaColors.dustyBlush;
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AlokaColors.surfaceWhite,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.isActive
                      ? AlokaColors.mustardGold.withValues(alpha: 0.45)
                      : AlokaColors.surfaceSand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  AlokaCategoryIcons.resolve(item.iconKey),
                  color: AlokaColors.charcoal,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.categoryName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        AlokaPillBadge(
                          text: item.status.label,
                          backgroundColor: badgeColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      FormatService.formatRupiah(item.allocatedAmount),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AlokaColors.background,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  pct,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AlokaColors.charcoal,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.5,
                      ),
                ),
              ),
              if (item.isActive && !item.isFixedCost) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onTapAdjust,
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AlokaColors.background,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: AlokaColors.charcoal,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Min ${FormatService.formatRupiah(item.minimumAmount)} • Target ${FormatService.formatRupiah(item.targetAmount)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              if (item.isUserAdjusted)
                const AlokaPillBadge(
                  text: 'Penyesuaian',
                  backgroundColor: AlokaColors.terracotta,
                  textColor: AlokaColors.surfaceWhite,
                )
              else
                AlokaPillBadge.forPriority(item.priority),
            ],
          ),
        ],
      ),
    );
  }
}
