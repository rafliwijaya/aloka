import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aloka/theme/app_theme.dart';
import 'package:aloka/widgets/aloka_widgets.dart';

void main() {
  testWidgets('AlokaFloatingBottomNav renders navigation items and responds to tap',
      (WidgetTester tester) async {
    int selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AlokaTheme.lightTheme,
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              bottomNavigationBar: AlokaFloatingBottomNav(
                currentIndex: selectedIndex,
                onTap: (index) {
                  setState(() {
                    selectedIndex = index;
                  });
                },
              ),
            );
          },
        ),
      ),
    );

    // Tab aktif pertama (Beranda) menampilkan label teks
    expect(find.text('Beranda'), findsOneWidget);

    // Tab lainnya menampilkan icon
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsOneWidget);
    expect(find.byIcon(Icons.pie_chart_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);

    // Mengetuk tab kedua (Anggaran)
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);
    expect(find.text('Anggaran'), findsOneWidget);
  });

  testWidgets('AlokaQuickActionButton renders icon and label, and responds to tap',
      (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AlokaQuickActionButton(
                icon: Icons.tune,
                label: 'Atur',
                onTap: () {
                  tapped = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Atur'), findsOneWidget);
    expect(find.byIcon(Icons.tune), findsOneWidget);

    await tester.tap(find.text('Atur'));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
