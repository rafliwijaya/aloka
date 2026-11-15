import 'package:flutter/material.dart';
import '../models/budget_models.dart';
import '../theme/app_theme.dart';

/// Pemetaan ikon garis tipis (thin-line icons) untuk setiap kategori
class AlokaCategoryIcons {
  AlokaCategoryIcons._();

  static IconData resolve(String iconKey) {
    switch (iconKey) {
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'directions_bus':
        return Icons.directions_bus_outlined;
      case 'wifi':
        return Icons.wifi_outlined;
      case 'school':
        return Icons.school_outlined;
      case 'savings':
        return Icons.savings_outlined;
      case 'beach_access':
        return Icons.beach_access_outlined;
      case 'movie':
        return Icons.movie_outlined;
      case 'medical':
        return Icons.medical_services_outlined;
      case 'home':
        return Icons.home_work_outlined;
      case 'groups':
        return Icons.groups_outlined;
      case 'spa':
        return Icons.spa_outlined;
      case 'laptop':
        return Icons.laptop_mac_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}

/// Bilah navigasi melayang (Floating Bottom Navigation) berwarna gelap (#222222)
/// dengan tab aktif berbentuk kapsul (pill-shaped) berwarna Mustard Gold (#EBB85E)
/// sesuai referensi gambar dan desain.txt.
class AlokaFloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AlokaFloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const items = <_NavItemSpec>[
      _NavItemSpec(label: 'Beranda', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
      _NavItemSpec(label: 'Anggaran', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded),
      _NavItemSpec(label: 'Riwayat', icon: Icons.pie_chart_outline_rounded, activeIcon: Icons.pie_chart_rounded),
      _NavItemSpec(label: 'Profil', icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AlokaColors.surfaceWhite,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: AlokaColors.charcoal.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;

              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 16 : 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AlokaColors.charcoal : Colors.transparent,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSelected ? 4 : 0),
                        decoration: isSelected
                            ? BoxDecoration(
                                color: AlokaColors.mustardGold,
                                borderRadius: BorderRadius.circular(8),
                              )
                            : null,
                        child: Icon(
                          isSelected ? item.activeIcon : item.icon,
                          size: isSelected ? 16 : 22,
                          color: AlokaColors.charcoal,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AlokaColors.surfaceWhite,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemSpec {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItemSpec({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

/// Header halaman dengan tombol ikon kiri, sapaan/judul tengah, dan teks "Halo, [username]" di kanan atas
class AlokaTopBar extends StatelessWidget {
  final String username;
  final String? fullname;
  final VoidCallback? onProfileTap;
  final VoidCallback? onMenuTap;

  const AlokaTopBar({
    super.key,
    required this.username,
    this.fullname,
    this.onProfileTap,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Tombol kiri persegi membulat putih
        InkWell(
          onTap: onMenuTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AlokaColors.surfaceWhite,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notes_rounded,
              color: AlokaColors.charcoal,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Nama pengguna di tengah
        Expanded(
          child: Column(
            children: [
              Text(
                fullname != null && fullname!.isNotEmpty ? fullname! : 'Aloka',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 1),
              Text(
                '@$username',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Pojok kanan atas: "Halo, [username]" beserta ikon profil
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 132),
          child: InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: AlokaColors.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'Halo, $username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 17,
                    color: AlokaColors.charcoal,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tombol aksi persegi membulat (Rounded Square Action Tile)
class AlokaQuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  const AlokaQuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.backgroundColor = AlokaColors.surfaceWhite,
    this.iconColor = AlokaColors.charcoal,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 3),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AlokaColors.background,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AlokaColors.charcoal,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress bar horizontal minimalis dengan sudut membulat penuh
class AlokaHorizontalProgressBar extends StatelessWidget {
  final double ratio; // 0.0 - 1.0
  final Color activeColor;
  final Color trackColor;
  final double height;

  const AlokaHorizontalProgressBar({
    super.key,
    required this.ratio,
    this.activeColor = AlokaColors.pastelLime,
    this.trackColor = AlokaColors.surfaceSand,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = ratio.clamp(0.0, 1.0);
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(height),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: clamped),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, animatedRatio, _) {
            return FractionallySizedBox(
              widthFactor: animatedRatio.clamp(0.0, 1.0),
              heightFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Lencana status atau prioritas berbentuk kapsul (Pill Badge)
class AlokaPillBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const AlokaPillBadge({
    super.key,
    required this.text,
    required this.backgroundColor,
    this.textColor = AlokaColors.charcoal,
  });

  factory AlokaPillBadge.forPriority(PriorityLevel priority) {
    switch (priority) {
      case PriorityLevel.high:
        return AlokaPillBadge(
          text: 'Prioritas ${priority.label}',
          backgroundColor: AlokaColors.mustardGold.withValues(alpha: 0.35),
        );
      case PriorityLevel.medium:
        return AlokaPillBadge(
          text: 'Prioritas ${priority.label}',
          backgroundColor: AlokaColors.pastelLime.withValues(alpha: 0.45),
        );
      case PriorityLevel.low:
        return AlokaPillBadge(
          text: 'Prioritas ${priority.label}',
          backgroundColor: AlokaColors.dustyBlush,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
