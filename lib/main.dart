import 'package:flutter/material.dart';
import 'screens/budget_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/optimization_result_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'state/aloka_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/aloka_widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AlokaApp());
}

class AlokaApp extends StatefulWidget {
  const AlokaApp({super.key});

  @override
  State<AlokaApp> createState() => _AlokaAppState();
}

class _AlokaAppState extends State<AlokaApp> {
  late final AlokaController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AlokaController()..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aloka',
      debugShowCheckedModeBanner: false,
      theme: AlokaTheme.lightTheme,
      home: AlokaSplashScreen(
        nextPage: AlokaMainShell(controller: _controller),
      ),
    );
  }
}

/// Shell navigasi utama aplikasi Aloka dengan 4 halaman utama:
/// 1. Beranda (Lingkaran Merah)
/// 2. Anggaran
/// 3. Riwayat (Lingkaran Biru)
/// 4. Profil
/// Dilengkapi Floating Bottom Navigation berwarna Charcoal Black (#222222).
class AlokaMainShell extends StatelessWidget {
  final AlokaController controller;

  const AlokaMainShell({
    super.key,
    required this.controller,
  });

  void _handleOpenLatestOptimization(BuildContext context) {
    final latest = controller.latestResult;
    if (latest != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OptimizationResultScreen(
            controller: controller,
            result: latest,
          ),
        ),
      );
      return;
    }

    controller.setSelectedNavIndex(1);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AlokaColors.charcoal,
        content: Text(
          'Belum ada hasil optimasi. Silakan klik "Optimalkan Alokasi" di halaman Anggaran.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isLoading) {
          return const Scaffold(
            backgroundColor: AlokaColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AlokaColors.charcoal,
              ),
            ),
          );
        }

        final pages = <Widget>[
          HomeScreen(
            controller: controller,
            onStartOptimization: () => _handleOpenLatestOptimization(context),
          ),
          BudgetScreen(
            controller: controller,
            onOptimizeSuccess: () {
              final latest = controller.latestResult;
              if (latest != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OptimizationResultScreen(
                      controller: controller,
                      result: latest,
                    ),
                  ),
                );
              }
            },
          ),
          HistoryScreen(controller: controller),
          ProfileScreen(controller: controller),
        ];

        return Scaffold(
          backgroundColor: AlokaColors.background,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Positioned.fill(
                  child: IndexedStack(
                    index: controller.selectedNavIndex,
                    children: pages,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AlokaFloatingBottomNav(
                    currentIndex: controller.selectedNavIndex,
                    onTap: controller.setSelectedNavIndex,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
