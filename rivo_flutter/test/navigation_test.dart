import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rivo/screens/home_screen.dart';
import 'package:rivo/screens/profile_screen.dart';
import 'package:rivo/widgets/common.dart';
import 'package:rivo/screens/feature_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://127.0.0.1:1',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets('home tabs keep a visible screen while backend is unavailable',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();

    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Moment'));
    await tester.pump();
    expect(find.text('Moments'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Message'));
    await tester.pump();
    expect(find.text('Messages'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Me'));
    await tester.pump();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('bottom navigation reports the selected tab', (tester) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: RivoBottomNav(
            currentIndex: selectedIndex,
            onTap: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Moment'));

    expect(selectedIndex, 1);
  });

  testWidgets('Add Coins clearly disables purchases without a payment provider',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddCoinsScreen()));

    expect(find.text('Coin purchases are unavailable'), findsOneWidget);
    expect(find.textContaining('No coins have been added.'), findsOneWidget);
    expect(find.text('Pay'), findsNothing);
  });
}
