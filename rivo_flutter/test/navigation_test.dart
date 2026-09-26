import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(
        const MethodChannel('com.llfbandit.app_links/messages'),
        (_) async => null,
      )
      ..setMockStreamHandler(
        const EventChannel('com.llfbandit.app_links/events'),
        MockStreamHandler.inline(onListen: (arguments, events) {}),
      );
    await Supabase.initialize(
      url: 'http://127.0.0.1:1',
      publishableKey: 'test-publishable-key',
    );
  });

  testWidgets('home tabs keep a visible screen while backend is unavailable',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    final navigation = find.byType(RivoBottomNav);
    expect(navigation, findsOneWidget);
    expect(tester.getTopLeft(navigation).dy, greaterThan(600));
    expect(tester.getBottomRight(navigation).dy, 800);
    expect(find.text('Room'), findsOneWidget);
    expect(find.text('Moment'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    const labels = ['Room', 'Moment', 'Message', 'Me'];
    final labelCenters =
        labels.map((label) => tester.getCenter(find.text(label)).dx).toList();
    expect(labelCenters, orderedEquals([...labelCenters]..sort()));

    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)));
    await tester.pump();
    expect(
        find.text('Retry').evaluate().isNotEmpty ||
            find.text('No active rooms yet.').evaluate().isNotEmpty,
        isTrue);

    await tester.tap(find.text('Moment'));
    await tester.pump();
    expect(find.text('Moments'), findsOneWidget);
    expect(find.byType(MomentsScreen), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.text('Retry').evaluate().isNotEmpty ||
          find.text('No Moments yet.').evaluate().isNotEmpty,
      isTrue,
    );

    await tester.tap(find.text('Message'));
    await tester.pump();
    expect(find.text('Messages'), findsOneWidget);
    expect(find.byType(MessagesScreen), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.text('Retry').evaluate().isNotEmpty ||
          find.text('No conversations yet.').evaluate().isNotEmpty,
      isTrue,
    );

    await tester.tap(find.text('Me'));
    await tester.pump();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(RivoBottomNav), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
          find.text('Retry').evaluate().isNotEmpty,
      isTrue,
    );
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
