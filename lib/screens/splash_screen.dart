import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================================
// KONSTANTA WARNA, ASET, DURASI, INTERVAL, DAN KURVA ANIMASI SPLASH ALOKA
// ============================================================================

const Color kSplashYellow = Color(0xFFF1AB20);
const Color kSplashBlack = Color(0xFF0D0D0D);

const String kAssetWalletIcon = 'assets/images/ikon.png';
const String kAssetLetterA = 'assets/images/huruf_a.png';
const String kAssetWordLoka = 'assets/images/loka.png';
const String kAssetFlap = 'assets/images/flap.png';

/// Set `true` hanya jika file `assets/images/flap.png` tersedia di proyek.
/// Jika `false`, animasi otomatis memakai efek squash-and-stretch halus pada dompet.
const bool kHasFlapAsset = false;

const int kSplashTotalMs = 3600;
const Duration kSplashTotalDuration = Duration(milliseconds: kSplashTotalMs);
const Duration kPageFadeTransitionDuration = Duration(milliseconds: 520);

// --- Fase 1 (0,0 - 0,9 dtk): Kemunculan awal ikon dompet dari bawah ---
const Interval kPhase1AppearInterval = Interval(
  0.0 / 3.6,
  0.9 / 3.6,
  curve: Curves.easeOutBack,
);
const Interval kPhase1FadeInterval = Interval(
  0.0 / 3.6,
  0.65 / 3.6,
  curve: Curves.easeOutCubic,
);

// --- Fase 2 (0,8 - 1,6 dtk): Dompet naik ke atas & mengecil ke ~70% + squash/stretch ---
const Interval kPhase2MoveUpInterval = Interval(
  0.8 / 3.6,
  1.6 / 3.6,
  curve: Curves.easeInOutCubic,
);
const Interval kPhase2DeformInterval = Interval(
  0.8 / 3.6,
  1.6 / 3.6,
  curve: Curves.easeInOutSine,
);

// --- Fase 3A (1,3 - 2,15 dtk): Huruf 'A' meluncur turun dari dalam dompet + overshoot ---
const Interval kPhase3ADropInterval = Interval(
  1.3 / 3.6,
  2.05 / 3.6,
  curve: Curves.easeOutCubic,
);
const Interval kPhase3AOvershootSettleInterval = Interval(
  1.95 / 3.6,
  2.28 / 3.6,
  curve: Curves.easeInOutQuad,
);
const Interval kPhase3AFadeInterval = Interval(
  1.3 / 3.6,
  1.58 / 3.6,
  curve: Curves.easeOutCubic,
);

// --- Fase 3B (1,55 - 2,3 dtk): Tulisan 'loka' wipe kiri ke kanan + geser 20px + fade ---
const Interval kPhase3BLokaWipeInterval = Interval(
  1.55 / 3.6,
  2.3 / 3.6,
  curve: Curves.easeOutCubic,
);
const Interval kPhase3BLokaFadeInterval = Interval(
  1.55 / 3.6,
  2.15 / 3.6,
  curve: Curves.easeOutQuad,
);

// --- Fase 4 (2,2 - 2,8 dtk): Hold hidup (bobbing ±2px & 1x sapuan kilau) ---
const Interval kPhase4HoldInterval = Interval(
  2.2 / 3.6,
  2.8 / 3.6,
  curve: Curves.easeInOutSine,
);
const Interval kPhase4ShimmerInterval = Interval(
  2.22 / 3.6,
  2.76 / 3.6,
  curve: Curves.easeInOutCubic,
);

// --- Fase 5 (2,8 - 3,6 dtk): Lingkaran kuning #F1AB20 melebar memenuhi layar ---
const Interval kPhase5CircleExpandInterval = Interval(
  2.8 / 3.6,
  3.6 / 3.6,
  curve: Curves.easeInOutCubic,
);

// --- Kalibrasi proporsi bounding-box piksel aset asli agar 'A' + 'loka' menyatu ---
// huruf_a.png (1920x1917): area terlihat x=[0.0406..0.9682], y=[0.1403..0.8894]
// loka.png    (1920x715) : area terlihat x=[0.2021..0.7833], y=[0.2895..0.8070]
const double _kAImgAspect = 1920.0 / 1917.0;
const double _kAVisLeftFrac = 78.0 / 1920.0;
const double _kAVisWidthFrac = 1781.0 / 1920.0;
const double _kAVisHeightFrac = 1436.0 / 1917.0;
const double _kAVisBottomFrac = 1705.0 / 1917.0;

const double _kLokaImgAspect = 1920.0 / 715.0;
const double _kLokaVisLeftFrac = 388.0 / 1920.0;
const double _kLokaVisRightFrac = 1504.0 / 1920.0;
const double _kLokaVisWidthFrac = 1116.0 / 1920.0;
const double _kLokaVisHeightFrac = 370.0 / 715.0;
const double _kLokaVisBottomFrac = 577.0 / 715.0;

/// Rasio tinggi visual 'loka' terhadap 'A' berdasarkan aloka-title.png (370 / 432)
const double _kLokaToAHeightRatio = 370.0 / 432.0;

/// Jarak kerning optik alami antara ujung kanan bawah 'A' dan batang vertikal 'l'
const double _kOpticalKerningRatio = 0.042;

/// Splash Screen animasi kustom untuk aplikasi Aloka.
/// Menggunakan satu [AnimationController] (3600 ms) dengan multi-interval yang saling
/// bertumpuk (overlapping action & follow-through) tanpa paket eksternal.
class AlokaSplashScreen extends StatefulWidget {
  /// Callback opsional ketika animasi selesai (3600 ms).
  /// Jika [nextPage] diberikan dan [onFinished] bernilai null,
  /// widget otomatis bernavigasi ke [nextPage] menggunakan [PageRouteBuilder] fade.
  final VoidCallback? onFinished;

  /// Halaman tujuan (misal `AlokaMainShell`) untuk transisi otomatis dengan fade.
  final Widget? nextPage;

  /// Warna latar belakang splash (default mengikuti tema atau putih).
  final Color? backgroundColor;

  const AlokaSplashScreen({
    super.key,
    this.onFinished,
    this.nextPage,
    this.backgroundColor,
  });

  /// Helper untuk berpindah ke halaman berikutnya dengan transisi fade halus.
  static PageRouteBuilder<T> buildFadeRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: kPageFadeTransitionDuration,
      reverseTransitionDuration: kPageFadeTransitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: fade,
          child: child,
        );
      },
    );
  }

  @override
  State<AlokaSplashScreen> createState() => _AlokaSplashScreenState();
}

class _AlokaSplashScreenState extends State<AlokaSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _phase1Scale;
  late final Animation<double> _phase1Fade;
  late final Animation<double> _phase2Progress;
  late final Animation<double> _phase2Deform;
  late final Animation<double> _phase3ADrop;
  late final Animation<double> _phase3ASettle;
  late final Animation<double> _phase3AFade;
  late final Animation<double> _phase3BLokaWipe;
  late final Animation<double> _phase3BLokaFade;
  late final Animation<double> _phase4Hold;
  late final Animation<double> _phase4Shimmer;
  late final Animation<double> _phase5Circle;

  bool _hasCompletedNavigation = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: kSplashTotalDuration,
    );

    _phase1Scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase1AppearInterval),
    );
    _phase1Fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase1FadeInterval),
    );

    _phase2Progress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase2MoveUpInterval),
    );
    _phase2Deform = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase2DeformInterval),
    );

    _phase3ADrop = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase3ADropInterval),
    );
    _phase3ASettle = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase3AOvershootSettleInterval),
    );
    _phase3AFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase3AFadeInterval),
    );

    _phase3BLokaWipe = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase3BLokaWipeInterval),
    );
    _phase3BLokaFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase3BLokaFadeInterval),
    );

    _phase4Hold = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase4HoldInterval),
    );
    _phase4Shimmer = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase4ShimmerInterval),
    );

    _phase5Circle = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: kPhase5CircleExpandInterval),
    );

    _controller.addStatusListener(_onAnimationStatusChanged);
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage(kAssetWalletIcon), context);
    precacheImage(const AssetImage(kAssetLetterA), context);
    precacheImage(const AssetImage(kAssetWordLoka), context);
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_hasCompletedNavigation) {
      _hasCompletedNavigation = true;
      if (widget.onFinished != null) {
        widget.onFinished!();
      } else if (widget.nextPage != null && mounted) {
        Navigator.of(context).pushReplacement(
          AlokaSplashScreen.buildFadeRoute(widget.nextPage!),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onAnimationStatusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screenSize = media.size;
    final sw = screenSize.width;
    final sh = screenSize.height;
    final shortest = media.size.shortestSide;

    // Ukuran responsif berbasis MediaQuery
    final baseIconSize = (shortest * 0.42).clamp(140.0, 210.0);
    final moveUpDistance = (sh * 0.085).clamp(48.0, 82.0);

    // Tinggi visual huruf 'A' pada teks akhir "Aloka"
    final visAHeight = (shortest * 0.118).clamp(38.0, 56.0);
    final boxHA = visAHeight / _kAVisHeightFrac;
    final boxWA = boxHA * _kAImgAspect;
    final visAWidth = boxWA * _kAVisWidthFrac;

    // Ukuran kotak gambar 'loka.png' agar baseline & proporsinya presisi dengan 'A'
    final visLokaHeight = visAHeight * _kLokaToAHeightRatio;
    final boxHLoka = visLokaHeight / _kLokaVisHeightFrac;
    final boxWLoka = boxHLoka * _kLokaImgAspect;
    final visLokaWidth = boxWLoka * _kLokaVisWidthFrac;

    final kerning = visAHeight * _kOpticalKerningRatio;
    final totalWordVisWidth = visAWidth + kerning + visLokaWidth;

    // Titik pusat layar dan posisi akhir logo + teks
    final centerX = sw * 0.5;
    final centerY = sh * 0.48;
    final walletFinalCenterY = centerY - moveUpDistance;

    // Baseline teks "Aloka" berada tepat di bawah dompet yang sudah naik
    final wordBaselineY =
        walletFinalCenterY + (baseIconSize * 0.70 * 0.42) + visAHeight + 14.0;

    // Koordinat akhir widget huruf_a.png (dikompensasi terhadap margin transparan gambar)
    final visALeft = centerX - (totalWordVisWidth * 0.5);
    final aEndLeft = visALeft - (_kAVisLeftFrac * boxWA);
    final aEndTop = wordBaselineY - (_kAVisBottomFrac * boxHA);
    final aEndCenterX = aEndLeft + (boxWA * 0.5);
    final aEndCenterY = aEndTop + (boxHA * 0.5);

    // Koordinat awal huruf_a.png: berhimpit dengan huruf 'A' di dalam dompet
    final aStartCenterX = centerX - (baseIconSize * 0.025);
    final aStartCenterY = walletFinalCenterY + (baseIconSize * 0.055);
    final aStartScale = (baseIconSize * 0.70 * 0.53) / boxWA;

    // Koordinat akhir widget loka.png (menyatu tepat di kanan huruf 'A' tanpa celah/tumpang tindih)
    final visLokaLeft = visALeft + visAWidth + kerning;
    final lokaEndLeft = visLokaLeft - (_kLokaVisLeftFrac * boxWLoka);
    final lokaEndTop = wordBaselineY - (_kLokaVisBottomFrac * boxHLoka);

    // Titik pusat lingkaran ekspansi akhir (di tengah kesatuan logo & teks)
    final circleOrigin = Offset(
      centerX,
      (walletFinalCenterY + wordBaselineY) * 0.5,
    );
    final maxCircleRadius = math.sqrt(sw * sw + sh * sh) * 0.62;

    final bgColor = widget.backgroundColor ?? AlokaColors.background;

    return Scaffold(
      backgroundColor: bgColor,
      body: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // 1. Transformasi Dompet (Fase 1, Fase 2, dan Fase 4)
            final p1Fade = _phase1Fade.value.clamp(0.0, 1.0);
            final p1Scale = _phase1Scale.value;
            final p1Progress =
                CurvedAnimation(parent: _controller, curve: kPhase1FadeInterval)
                    .value;
            final initialSlideY = 40.0 * (1.0 - p1Progress);

            final p2 = _phase2Progress.value;
            final walletScale = p1Scale * (1.0 - (0.30 * p2));

            // Squash & stretch halus saat dompet berakselerasi naik lalu berhenti
            final deformWave = math.sin(_phase2Deform.value * math.pi);
            final squashX = 1.0 - (0.045 * deformWave);
            final stretchY = 1.0 + (0.055 * deformWave);

            // Gerakan hidup naik-turun ±2 px saat fase hold (2,2 - 2,8 dtk)
            final holdWave = math.sin(_phase4Hold.value * 2.0 * math.pi);
            final bobbingY = 2.0 * holdWave;

            final walletCenterY =
                centerY + initialSlideY - (moveUpDistance * p2) + bobbingY;

            // 2. Transformasi Huruf 'A' (Fase 3A: meluncur turun + overshoot kecil)
            final dropT = _phase3ADrop.value;
            final settleT = _phase3ASettle.value;
            // Overshoot lembut maksimum +7 px saat mendarat lalu kembali ke 0
            final overshootY =
                7.0 * math.sin(settleT * math.pi) * (dropT > 0.65 ? 1.0 : 0.0);

            final currentACenterX =
                aStartCenterX + (aEndCenterX - aStartCenterX) * dropT;
            final currentACenterY =
                aStartCenterY + (aEndCenterY - aStartCenterY) * dropT + overshootY;
            final currentAScale = aStartScale + (1.0 - aStartScale) * dropT;
            final aOpacity = _phase3AFade.value.clamp(0.0, 1.0);

            // 3. Transformasi Tulisan 'loka' (Fase 3B: wipe kiri-ke-kanan + geser 20 px + fade)
            final lokaWipeT = _phase3BLokaWipe.value.clamp(0.0, 1.0);
            final lokaFadeT = _phase3BLokaFade.value.clamp(0.0, 1.0);
            final lokaSlideX = -20.0 * (1.0 - lokaWipeT);
            // Petakan widthFactor ke rentang piksel huruf 'loka' agar wipe langsung terlihat
            final effectiveWipeFactor = lokaWipeT <= 0.001
                ? 0.0
                : (_kLokaVisLeftFrac +
                        (_kLokaVisRightFrac - _kLokaVisLeftFrac) * lokaWipeT)
                    .clamp(0.0, 1.0);

            // 4. Shimmer (sapuan kilau 1x pada ikon dompet di Fase 4)
            final shimmerT = _phase4Shimmer.value;
            final isShimmerActive = shimmerT > 0.0 && shimmerT < 1.0;

            // 5. Lingkaran Ekspansi Kuning #F1AB20 (Fase 5: 2,8 - 3,6 dtk)
            final circleT = _phase5Circle.value.clamp(0.0, 1.0);
            final currentCircleRadius = maxCircleRadius * circleT;

            return Stack(
              fit: StackFit.expand,
              children: [
                // --- ELEMEN 1: Tulisan "loka" (Wipe kiri-ke-kanan + slide 20 px + fade) ---
                if (lokaFadeT > 0.001)
                  Positioned(
                    left: lokaEndLeft + lokaSlideX,
                    top: lokaEndTop,
                    width: boxWLoka,
                    height: boxHLoka,
                    child: Opacity(
                      opacity: lokaFadeT,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: effectiveWipeFactor,
                          child: SizedBox(
                            width: boxWLoka,
                            height: boxHLoka,
                            child: Image.asset(
                              kAssetWordLoka,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // --- ELEMEN 2: Huruf "A" yang meluncur turun dari dompet ke posisi awal teks ---
                if (aOpacity > 0.001)
                  Positioned(
                    left: currentACenterX - (boxWA * 0.5),
                    top: currentACenterY - (boxHA * 0.5),
                    width: boxWA,
                    height: boxHA,
                    child: Opacity(
                      opacity: aOpacity,
                      child: Transform.scale(
                        scale: currentAScale,
                        child: Image.asset(
                          kAssetLetterA,
                          fit: BoxFit.fill,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),

                // --- ELEMEN 3: Ikon Dompet di atas (muncul, naik, squash/stretch, bobbing, kilau) ---
                if (p1Fade > 0.001)
                  Positioned(
                    left: centerX - (baseIconSize * 0.5),
                    top: walletCenterY - (baseIconSize * 0.5),
                    width: baseIconSize,
                    height: baseIconSize,
                    child: Opacity(
                      opacity: p1Fade,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(
                          walletScale * squashX,
                          walletScale * stretchY,
                          1.0,
                        ),
                        child: _buildWalletWithOptionalShimmer(
                          isShimmerActive: isShimmerActive,
                          shimmerProgress: shimmerT,
                          deformWave: deformWave,
                        ),
                      ),
                    ),
                  ),

                // --- ELEMEN 4: Lingkaran Kuning (#F1AB20) melebar memenuhi layar (2,8 - 3,6 dtk) ---
                if (circleT > 0.001)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ExpandingCirclePainter(
                          center: circleOrigin,
                          radius: currentCircleRadius,
                          color: kSplashYellow,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWalletWithOptionalShimmer({
    required bool isShimmerActive,
    required double shimmerProgress,
    required double deformWave,
  }) {
    Widget walletImage = Image.asset(
      kAssetWalletIcon,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (kHasFlapAsset) {
      final flapAngle = (8.0 * math.pi / 180.0) * deformWave;
      walletImage = Stack(
        fit: StackFit.expand,
        children: [
          walletImage,
          Transform.rotate(
            angle: -flapAngle,
            alignment: Alignment.topLeft,
            child: Image.asset(
              kAssetFlap,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      );
    }

    if (!isShimmerActive) {
      return walletImage;
    }

    // Satu kali sapuan kilau diagonal (ShaderMask dengan LinearGradient yang bergeser)
    final sweepPos = -0.8 + (shimmerProgress * 2.6);
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment(sweepPos - 0.45, -0.6),
          end: Alignment(sweepPos + 0.45, 0.6),
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.48),
            Colors.white.withValues(alpha: 0.0),
          ],
          stops: const [0.25, 0.50, 0.75],
        ).createShader(bounds);
      },
      child: walletImage,
    );
  }
}

/// CustomPainter untuk menggambar lingkaran kuning (#F1AB20) yang melebar
/// dari titik tengah logo hingga menutup seluruh layar pada akhir splash.
class _ExpandingCirclePainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color color;

  const _ExpandingCirclePainter({
    required this.center,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _ExpandingCirclePainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.center != center ||
        oldDelegate.color != color;
  }
}
