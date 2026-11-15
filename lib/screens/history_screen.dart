import 'package:flutter/material.dart';
import '../models/budget_models.dart';
import '../services/format_service.dart';
import '../state/aloka_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/aloka_widgets.dart';
import 'optimization_result_screen.dart';

/// Halaman 3: RIWAYAT (Mengacu pada lingkaran biru di referensi-aloka.png & desain.txt)
/// Menampilkan kartu sheet dengan ilustrasi E-wallet-pana.png di bagian atas,
/// judul besar rencana/riwayat terpilih, lencana nominal Dusty Blush Pink (#EBD5D0),
/// 5 tombol aksi persegi membulat, serta daftar riwayat optimasi dan pembagian kategorinya.
class HistoryScreen extends StatefulWidget {
  final AlokaController controller;

  const HistoryScreen({
    super.key,
    required this.controller,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedHistoryIndex = 0;
  bool _showCategoryBreakdown = false;

  OptimizationResult? get _selectedResult {
    final list = widget.controller.history;
    if (list.isEmpty) return null;
    final safeIdx = _selectedHistoryIndex.clamp(0, list.length - 1);
    return list[safeIdx];
  }

  Future<void> _confirmDeleteResult(
    BuildContext context,
    OptimizationResult item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AlokaColors.surfaceWhite,
        title: const Text('Hapus Riwayat?'),
        content: Text(
          'Hapus "${item.planName}" (${FormatService.formatShortDate(item.createdAt)}) dari perangkat?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AlokaColors.terracotta,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.controller.deleteHistoryItem(item.id);
      if (mounted) {
        setState(() => _selectedHistoryIndex = 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyList = widget.controller.history;
    final current = _selectedResult;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 118),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        decoration: BoxDecoration(
          color: AlokaColors.background,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AlokaColors.borderSubtle, width: 1.2),
        ),
        child: Column(
          children: [
            // Handle bar atas
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: AlokaColors.charcoal,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),

            // 1. Ilustrasi Utama
            SizedBox(
              height: 170,
              child: Image.asset(
                'assets/images/E-Wallet-pana.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          color: AlokaColors.mustardGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AlokaColors.terracotta,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 58,
                          color: AlokaColors.surfaceWhite,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // 2. Judul Rencana Terpilih
            Text(
              current != null ? current.planName : 'Riwayat Optimasi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),

            // 3. Lencana Nominal Dusty Blush Pink (#EBD5D0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: AlokaColors.dustyBlush,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                current != null
                    ? FormatService.formatRupiah(current.monthlyBudget)
                    : FormatService.formatRupiah(
                        widget.controller.activePlan?.monthlyBudget ?? 0,
                      ),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 18),

            // 4. Deretan 5 Tombol Aksi Ringkas (tanpa terpotong '...')
            Row(
              children: [
                AlokaQuickActionButton(
                  icon: Icons.percent_rounded,
                  label: 'Hasil',
                  onTap: () {
                    if (current == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OptimizationResultScreen(
                          controller: widget.controller,
                          result: current,
                        ),
                      ),
                    );
                  },
                ),
                AlokaQuickActionButton(
                  icon: Icons.category_outlined,
                  label: _showCategoryBreakdown ? 'Riwayat' : 'Kategori',
                  onTap: () {
                    setState(() {
                      _showCategoryBreakdown = !_showCategoryBreakdown;
                    });
                  },
                ),
                AlokaQuickActionButton(
                  icon: Icons.analytics_outlined,
                  label: 'Detail',
                  onTap: () {
                    if (current == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OptimizationResultScreen(
                          controller: widget.controller,
                          result: current,
                        ),
                      ),
                    );
                  },
                ),
                AlokaQuickActionButton(
                  icon: Icons.replay_rounded,
                  label: 'Simulasi',
                  onTap: () async {
                    if (current == null) return;
                    await widget.controller.loadSnapshotIntoActivePlan(current);
                    widget.controller.setSelectedNavIndex(1);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Snapshot dimuat ke halaman Anggaran.'),
                        ),
                      );
                    }
                  },
                ),
                AlokaQuickActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Hapus',
                  iconColor: AlokaColors.terracotta,
                  onTap: () {
                    if (current == null) return;
                    _confirmDeleteResult(context, current);
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 5. Daftar Kartu Riwayat atau Pembagian Kategori
            if (historyList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AlokaColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Text(
                      'Belum Ada Riwayat',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buka Anggaran lalu jalankan Optimalkan Alokasi.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            else if (_showCategoryBreakdown && current != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Pembagian Kategori (${current.planName})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              ...current.allocationSnapshot.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BlueCircleStyleRecordTile(
                    icon: AlokaCategoryIcons.resolve(item.iconKey),
                    title: item.categoryName,
                    amountText: FormatService.formatRupiah(
                      item.allocatedAmount,
                      showPlusSign: item.isActive && item.allocatedAmount > 0,
                    ),
                    isPositiveHighlight:
                        item.status == TargetStatus.achieved && item.isActive,
                    dateText: item.status.label,
                    timeText:
                        '${FormatService.formatPercentage(item.targetProgressRatio)} • Target ${FormatService.formatRupiah(item.targetAmount)}',
                    isSelected: false,
                    onTap: () {},
                  ),
                ),
              ),
            ] else ...[
              ...List.generate(historyList.length, (idx) {
                final item = historyList[idx];
                final isSelected = idx == _selectedHistoryIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BlueCircleStyleRecordTile(
                    icon: Icons.account_balance_wallet_rounded,
                    title: item.hasManualAdjustment
                        ? '${item.planName} (Ubah)'
                        : item.planName,
                    amountText: FormatService.formatRupiah(item.totalAllocated),
                    isPositiveHighlight: item.unallocatedAmount > 0,
                    dateText: FormatService.formatShortDate(item.createdAt),
                    timeText:
                        'Skor ${FormatService.formatPercentage(item.fitnessScore)} • ${FormatService.formatShortTime(item.createdAt)}',
                    isSelected: isSelected,
                    onTap: () {
                      setState(() => _selectedHistoryIndex = idx);
                    },
                    onDoubleTapOrOpen: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OptimizationResultScreen(
                            controller: widget.controller,
                            result: item,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// Kartu item riwayat
class _BlueCircleStyleRecordTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String amountText;
  final bool isPositiveHighlight;
  final String dateText;
  final String timeText;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTapOrOpen;

  const _BlueCircleStyleRecordTile({
    required this.icon,
    required this.title,
    required this.amountText,
    required this.isPositiveHighlight,
    required this.dateText,
    required this.timeText,
    required this.isSelected,
    required this.onTap,
    this.onDoubleTapOrOpen,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onDoubleTapOrOpen,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AlokaColors.surfaceWhite,
          borderRadius: BorderRadius.circular(22),
          border: isSelected
              ? Border.all(color: AlokaColors.mustardGold, width: 1.8)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AlokaColors.dustyBlush,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: AlokaColors.charcoal,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AlokaColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      amountText,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isPositiveHighlight
                                ? const Color(0xFF4E8C22)
                                : AlokaColors.charcoal,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AlokaColors.charcoal,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  timeText,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
