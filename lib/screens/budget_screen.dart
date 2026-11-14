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
                      Text(
                        'Atur ${input.categoryName}',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                      AlokaPillBadge(
                        text: input.categoryType.label,
                        backgroundColor: input.categoryType == CategoryType.mandatory
                            ? AlokaColors.mustardGold
                            : AlokaColors.dustyBlush,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Minimum adalah batas bawah yang wajib dipenuhi, sedangkan Target adalah nominal ideal yang ingin dicapai.',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Biaya Tetap (Minimum = Target)',
                      style: Theme.of(ctx).textTheme.titleSmall,
                    ),
                    subtitle: Text(
                      'Aktifkan untuk pengeluaran bernominal pasti seperti paket internet.',
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
                            label: const Text('Wajib (Selalu Aktif)'),
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
                            label: const Text('Opsional (Toggle)'),
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Halaman Anggaran
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rencana & Kategori',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              OutlinedButton.icon(
                onPressed: () => _showAddCustomCategorySheet(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Kategori Kustom'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AlokaColors.charcoal,
                  side: const BorderSide(color: AlokaColors.charcoal),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Kartu Uang Saku & Ringkasan Validasi Kelayakan (MIN_TOTAL <= B)
          _FeasibilitySummaryCard(
            planName: plan?.name ?? 'Anggaran Bulanan',
            monthlyBudget: plan?.monthlyBudget ?? 0,
            feasibility: feasibility,
            onEditBudget: () => _showEditBudgetDialog(context),
          ),
          const SizedBox(height: 18),

          // Pill-Shaped Tabs untuk filter Kategori (Semua / Kebutuhan Wajib / Opsional)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPillTab(
                  label: 'Semua (${widget.controller.categoryInputs.length})',
                  isSelected: _selectedFilterTab == 0,
                  activeColor: AlokaColors.mustardGold,
                  onTap: () => setState(() => _selectedFilterTab = 0),
                ),
                const SizedBox(width: 8),
                _FilterPillTab(
                  label: 'Kebutuhan Wajib (${widget.controller.mandatoryInputs.length})',
                  isSelected: _selectedFilterTab == 1,
                  activeColor: AlokaColors.pastelLime,
                  onTap: () => setState(() => _selectedFilterTab = 1),
                ),
                const SizedBox(width: 8),
                _FilterPillTab(
                  label: 'Opsional (${widget.controller.optionalInputs.length})',
                  isSelected: _selectedFilterTab == 2,
                  activeColor: AlokaColors.dustyBlush,
                  onTap: () => setState(() => _selectedFilterTab = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Daftar Kartu Kategori
          ...displayedCategories.map(
            (input) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryConfigTile(
                input: input,
                onTapEdit: () => _showEditCategorySheet(context, input),
                onToggleActive: (val) =>
                    widget.controller.toggleOptionalCategory(input.id, val),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tombol Utama: Optimalkan Alokasi dengan Genetic Algorithm
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
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
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
                    ? 'Mencari Kombinasi Alokasi Terbaik...'
                    : 'Optimalkan Alokasi (Algoritma Genetika)',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeasibilitySummaryCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isFeasible = feasibility.isFeasible;
    final bannerColor = isFeasible
        ? AlokaColors.pastelLime.withValues(alpha: 0.45)
        : AlokaColors.terracotta.withValues(alpha: 0.16);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AlokaColors.surfaceWhite,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    planName,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FormatService.formatRupiah(monthlyBudget),
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: onEditBudget,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Ubah Uang Saku'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AlokaColors.mustardGold,
                  foregroundColor: AlokaColors.charcoal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniMetricBox(
                  label: 'Total Minimum (Wajib+Aktif)',
                  value: FormatService.formatRupiah(feasibility.minTotal),
                  bgColor: AlokaColors.surfaceSand,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetricBox(
                  label: 'Total Target Aktif',
                  value: FormatService.formatRupiah(feasibility.targetTotal),
                  bgColor: AlokaColors.dustyBlush.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bannerColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isFeasible
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: isFeasible ? AlokaColors.charcoal : AlokaColors.terracotta,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    feasibility.summaryMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AlokaColors.charcoal,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AlokaColors.surfaceSand,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AlokaColors.surfaceWhite,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isMandatory
                        ? AlokaColors.mustardGold.withValues(alpha: 0.35)
                        : AlokaColors.dustyBlush.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    AlokaCategoryIcons.resolve(input.iconKey),
                    color: AlokaColors.charcoal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              input.categoryName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AlokaPillBadge(
                            text: isMandatory ? 'Wajib' : 'Opsional',
                            backgroundColor: isMandatory
                                ? AlokaColors.mustardGold.withValues(alpha: 0.3)
                                : AlokaColors.surfaceSand,
                          ),
                          if (input.isFixedCost) ...[
                            const SizedBox(width: 4),
                            const AlokaPillBadge(
                              text: 'Biaya Tetap',
                              backgroundColor: AlokaColors.pastelLime,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isActive
                            ? 'Min: ${FormatService.formatRupiah(input.minimumAmount)} • Target: ${FormatService.formatRupiah(input.targetAmount)}'
                            : 'Nonaktif (Alokasi Rp0)',
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
                  ),
                IconButton(
                  onPressed: onTapEdit,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  tooltip: 'Atur Minimum, Target & Prioritas',
                ),
              ],
            ),
            if (isActive) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AlokaPillBadge.forPriority(input.priority),
                  GestureDetector(
                    onTap: onTapEdit,
                    child: Text(
                      'Ubah Minimum & Target >',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AlokaColors.charcoal,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
