import 'package:flutter/material.dart';
import '../models/budget_models.dart';
import '../optimization/feasibility_checker.dart';
import '../services/format_service.dart';
import '../state/aloka_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/aloka_widgets.dart';

/// Halaman 2: ANGGARAN (Atur Uang Saku, Kategori Wajib & Opsional,
/// Tambah Kategori Kustom, Validasi Kelayakan MIN_TOTAL <= B, dan Tombol Optimalkan dengan GA)
class BudgetScreen extends StatefulWidget {
  final AlokaController controller;
  final VoidCallback onOptimizeSuccess;

  const BudgetScreen({
    super.key,
    required this.controller,
    required this.onOptimizeSuccess,
  });

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  int _selectedFilterTab = 0; // 0: Semua, 1: Wajib, 2: Opsional

  Future<void> _showEditBudgetDialog(BuildContext context) async {
    final plan = widget.controller.activePlan;
    if (plan == null) return;

    final nameCtrl = TextEditingController(text: plan.name);
    final budgetCtrl = TextEditingController(text: plan.monthlyBudget.toString());
    final noteCtrl = TextEditingController(text: plan.note);
    String? errorText;

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
                    'Atur Rencana Anggaran Bulanan',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Rencana Bulanan',
                      hintText: 'Contoh: Anggaran November',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: budgetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Total Uang Saku Bulanan (Rp)',
                      hintText: 'Contoh: 1200000',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (Opsional)',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final parsed = FormatService.parseRupiahInput(budgetCtrl.text);
                        if (parsed == null || parsed <= 0) {
                          setModalState(() {
                            errorText = 'Masukkan nominal uang saku bulat lebih dari Rp0.';
                          });
                          return;
                        }
                        await widget.controller.updateActivePlanDetails(
                          name: nameCtrl.text,
                          monthlyBudget: parsed,
                          note: noteCtrl.text,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Simpan Uang Saku'),
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

  Future<void> _showEditCategorySheet(
    BuildContext context,
    PlanCategoryInput input,
  ) async {
    final minCtrl = TextEditingController(text: input.minimumAmount.toString());
    final targetCtrl = TextEditingController(text: input.targetAmount.toString());
    PriorityLevel selectedPriority = input.priority;
    bool isFixedCost = input.isFixedCost;
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Atur ${input.categoryName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(ctx).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AlokaPillBadge(
                        text: input.categoryType.label,
                        backgroundColor: input.categoryType == CategoryType.mandatory
                            ? AlokaColors.mustardGold
                            : AlokaColors.dustyBlush,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Biaya Tetap (Min = Target)',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      'Nominal pasti seperti paket internet.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    value: isFixedCost,
                    activeThumbColor: AlokaColors.charcoal,
                    onChanged: (val) {
                      setModalState(() {
                        isFixedCost = val;
                        if (isFixedCost) {
                          minCtrl.text = targetCtrl.text;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (!isFixedCost) ...[
                    TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: input.categoryType == CategoryType.mandatory
                            ? 'Minimum Alokasi Wajib (Rp)'
                            : 'Minimum Alokasi Opsional (Default Rp0)',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: targetCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (val) {
                      if (isFixedCost) {
                        minCtrl.text = val;
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Target Alokasi (Rp)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tingkat Prioritas Pemenuhan Target',
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: PriorityLevel.values.map((prio) {
                      final selected = selectedPriority == prio;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(prio.label),
                            selected: selected,
                            selectedColor: AlokaColors.mustardGold,
                            backgroundColor: AlokaColors.surfaceWhite,
                            onSelected: (_) {
                              setModalState(() => selectedPriority = prio);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: AlokaColors.terracotta,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final targetVal = FormatService.parseRupiahInput(targetCtrl.text);
                        final minVal = isFixedCost
                            ? targetVal
                            : FormatService.parseRupiahInput(minCtrl.text);

                        if (minVal == null || targetVal == null || minVal < 0 || targetVal < 0) {
                          setModalState(() {
                            errorMsg = 'Nominal minimum dan target harus berupa angka bulat Rupiah tidak negatif.';
                          });
                          return;
                        }
                        if (targetVal < minVal) {
                          setModalState(() {
                            errorMsg = 'Target alokasi tidak boleh lebih kecil daripada batas minimum (${FormatService.formatRupiah(minVal)}).';
                          });
                          return;
                        }

                        await widget.controller.updateCategoryInput(
                          input.copyWith(
                            minimumAmount: minVal,
                            targetAmount: targetVal,
                            priority: selectedPriority,
                            priorityWeight: selectedPriority.defaultWeight,
                            isFixedCost: isFixedCost,
                          ),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Simpan Konfigurasi Kategori'),
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

  Future<void> _showAddCustomCategorySheet(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '0');
    final targetCtrl = TextEditingController(text: '150000');
    CategoryType selectedType = CategoryType.optional;
    PriorityLevel selectedPriority = PriorityLevel.medium;
    bool isFixedCost = false;
    String selectedIconKey = 'medical';
    String? errorMsg;

    const iconChoices = <Map<String, String>>[
      {'key': 'medical', 'label': 'Kesehatan'},
      {'key': 'home', 'label': 'Kos/Hunian'},
      {'key': 'groups', 'label': 'Organisasi'},
      {'key': 'spa', 'label': 'Perawatan'},
      {'key': 'laptop', 'label': 'Perangkat'},
    ];

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tambah Kategori Kustom',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Kategori',
                        hintText: 'Contoh: Kos / Obat / Organisasi',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Jenis Kategori',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Wajib'),
                            selected: selectedType == CategoryType.mandatory,
                            selectedColor: AlokaColors.mustardGold,
                            onSelected: (_) {
                              setModalState(() => selectedType = CategoryType.mandatory);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Opsional'),
                            selected: selectedType == CategoryType.optional,
                            selectedColor: AlokaColors.mustardGold,
                            onSelected: (_) {
                              setModalState(() => selectedType = CategoryType.optional);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Pilih Ikon',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: iconChoices.map((item) {
                        final isPicked = selectedIconKey == item['key'];
                        return ChoiceChip(
                          avatar: Icon(
                            AlokaCategoryIcons.resolve(item['key']!),
                            size: 16,
                            color: AlokaColors.charcoal,
                          ),
                          label: Text(item['label']!),
                          selected: isPicked,
                          selectedColor: AlokaColors.pastelLime,
                          onSelected: (_) {
                            setModalState(() => selectedIconKey = item['key']!);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Minimum Alokasi (Rp)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Target Alokasi (Rp)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Prioritas',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: PriorityLevel.values.map((prio) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(prio.label),
                              selected: selectedPriority == prio,
                              selectedColor: AlokaColors.mustardGold,
                              onSelected: (_) {
                                setModalState(() => selectedPriority = prio);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMsg!,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: AlokaColors.terracotta,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final minVal = FormatService.parseRupiahInput(minCtrl.text);
                          final targetVal = FormatService.parseRupiahInput(targetCtrl.text);
                          if (nameCtrl.text.trim().isEmpty) {
                            setModalState(() => errorMsg = 'Nama kategori wajib diisi.');
                            return;
                          }
                          if (minVal == null || targetVal == null || targetVal < minVal) {
                            setModalState(() {
                              errorMsg = 'Pastikan nominal valid dan Target >= Minimum.';
                            });
                            return;
                          }
                          try {
                            await widget.controller.addCustomCategory(
                              name: nameCtrl.text,
                              type: selectedType,
                              minimumAmount: minVal,
                              targetAmount: targetVal,
                              priority: selectedPriority,
                              isFixedCost: isFixedCost,
                              iconKey: selectedIconKey,
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setModalState(() => errorMsg = e.toString());
                          }
                        },
                        child: const Text('Tambahkan Kategori'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.controller.activePlan;
    final feasibility = widget.controller.feasibilityReport;

    List<PlanCategoryInput> displayedCategories;
    if (_selectedFilterTab == 1) {
      displayedCategories = widget.controller.mandatoryInputs;
    } else if (_selectedFilterTab == 2) {
      displayedCategories = widget.controller.optionalInputs;
    } else {
      displayedCategories = widget.controller.categoryInputs;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 118),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Halaman Anggaran
          Row(
            children: [
              Expanded(
                child: Text(
                  'Rencana & Kategori',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _showAddCustomCategorySheet(context),
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text('Kustom'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AlokaColors.charcoal,
                  side: const BorderSide(color: AlokaColors.charcoal),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Kartu Uang Saku & Ringkasan Kelayakan
          _FeasibilitySummaryCard(
            planName: plan?.name ?? 'Anggaran Bulanan',
            monthlyBudget: plan?.monthlyBudget ?? 0,
            feasibility: feasibility,
            onEditBudget: () => _showEditBudgetDialog(context),
          ),
          const SizedBox(height: 16),

          // 3 Tab Filter Sejajar Penuh tanpa terpotong
          Row(
            children: [
              Expanded(
                child: _FilterPillTab(
                  label: 'Semua (${widget.controller.categoryInputs.length})',
                  isSelected: _selectedFilterTab == 0,
                  activeColor: AlokaColors.mustardGold,
                  onTap: () => setState(() => _selectedFilterTab = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterPillTab(
                  label: 'Wajib (${widget.controller.mandatoryInputs.length})',
                  isSelected: _selectedFilterTab == 1,
                  activeColor: AlokaColors.pastelLime,
                  onTap: () => setState(() => _selectedFilterTab = 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterPillTab(
                  label: 'Opsional (${widget.controller.optionalInputs.length})',
                  isSelected: _selectedFilterTab == 2,
                  activeColor: AlokaColors.dustyBlush,
                  onTap: () => setState(() => _selectedFilterTab = 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Daftar Kartu Kategori
          ...displayedCategories.map(
            (input) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryConfigTile(
                input: input,
                onTapEdit: () => _showEditCategorySheet(context, input),
                onToggleActive: (val) =>
                    widget.controller.toggleOptionalCategory(input.id, val),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tombol Utama Optimasi GA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: feasibility.isFeasible && !widget.controller.isOptimizing
                  ? () async {
                      try {
                        await widget.controller.runGeneticOptimization();
                        widget.onOptimizeSuccess();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString())),
                          );
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AlokaColors.charcoal,
                disabledBackgroundColor: AlokaColors.borderSubtle,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              icon: widget.controller.isOptimizing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AlokaColors.surfaceWhite,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, color: AlokaColors.mustardGold),
              label: Text(
                widget.controller.isOptimizing
                    ? 'Mengoptimalkan Alokasi...'
                    : 'Optimalkan Alokasi',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeasibilitySummaryCard extends StatefulWidget {
  final String planName;
  final int monthlyBudget;
  final FeasibilityReport feasibility;
  final VoidCallback onEditBudget;

  const _FeasibilitySummaryCard({
    required this.planName,
    required this.monthlyBudget,
    required this.feasibility,
    required this.onEditBudget,
  });

  @override
  State<_FeasibilitySummaryCard> createState() => _FeasibilitySummaryCardState();
}

class _FeasibilitySummaryCardState extends State<_FeasibilitySummaryCard> {
  bool _showDetail = false;

  String get _compactStatus {
    final f = widget.feasibility;
    if (f.isFeasible) {
      final remaining = widget.monthlyBudget - f.minTotal;
      return 'Layak · Sisa target ${FormatService.formatRupiah(remaining)}';
    }
    if (f.shortfall > 0) {
      return 'Kurang ${FormatService.formatRupiah(f.shortfall)} dari minimum';
    }
    return 'Konfigurasi anggaran belum valid';
  }

  @override
  Widget build(BuildContext context) {
    final isFeasible = widget.feasibility.isFeasible;
    final bannerColor = isFeasible
        ? AlokaColors.pastelLime.withValues(alpha: 0.45)
        : AlokaColors.terracotta.withValues(alpha: 0.16);

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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        FormatService.formatRupiah(widget.monthlyBudget),
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: widget.onEditBudget,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Ubah Saldo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AlokaColors.mustardGold,
                  foregroundColor: AlokaColors.charcoal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _MiniMetricBox(
                    label: 'Minimum Aktif',
                    value: FormatService.formatRupiah(widget.feasibility.minTotal),
                    bgColor: AlokaColors.surfaceSand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MiniMetricBox(
                    label: 'Target Aktif',
                    value: FormatService.formatRupiah(widget.feasibility.targetTotal),
                    bgColor: AlokaColors.dustyBlush.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _showDetail = !_showDetail),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bannerColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isFeasible
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        color: isFeasible
                            ? AlokaColors.charcoal
                            : AlokaColors.terracotta,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _compactStatus,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AlokaColors.charcoal,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Icon(
                        _showDetail
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AlokaColors.charcoal,
                      ),
                    ],
                  ),
                  if (_showDetail) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.feasibility.summaryMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AlokaColors.charcoal,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color bgColor;

  const _MiniMetricBox({
    required this.label,
    required this.value,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPillTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _FilterPillTab({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AlokaColors.surfaceSand,
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

class _CategoryConfigTile extends StatelessWidget {
  final PlanCategoryInput input;
  final VoidCallback onTapEdit;
  final ValueChanged<bool> onToggleActive;

  const _CategoryConfigTile({
    required this.input,
    required this.onTapEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final isMandatory = input.categoryType == CategoryType.mandatory;
    final isActive = input.isActive;

    return Opacity(
      opacity: isActive ? 1.0 : 0.6,
      child: Material(
        color: AlokaColors.surfaceWhite,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTapEdit,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isMandatory
                            ? AlokaColors.mustardGold.withValues(alpha: 0.35)
                            : AlokaColors.dustyBlush.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        AlokaCategoryIcons.resolve(input.iconKey),
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
                                input.categoryName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              AlokaPillBadge(
                                text: isMandatory ? 'Wajib' : 'Opsional',
                                backgroundColor: isMandatory
                                    ? AlokaColors.mustardGold.withValues(alpha: 0.3)
                                    : AlokaColors.surfaceSand,
                              ),
                              if (input.isFixedCost)
                                const AlokaPillBadge(
                                  text: 'Tetap',
                                  backgroundColor: AlokaColors.pastelLime,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isActive
                                ? 'Min ${FormatService.formatRupiah(input.minimumAmount)} • Target ${FormatService.formatRupiah(input.targetAmount)}'
                                : 'Nonaktif (Alokasi Rp0)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (!isMandatory)
                      Switch(
                        value: isActive,
                        activeThumbColor: AlokaColors.charcoal,
                        onChanged: onToggleActive,
                      )
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AlokaColors.textMuted,
                        size: 20,
                      ),
                  ],
                ),
                if (isActive) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AlokaPillBadge.forPriority(input.priority),
                      Text(
                        'Atur Nilai',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AlokaColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
