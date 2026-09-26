import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rivo/screens/home_screen.dart';
import 'package:rivo/screens/profile_screen.dart';
import 'package:rivo/widgets/common.dart';
import 'package:rivo/screens/feature_screens.dart';
import 'package:rivo/widgets/gift_effect_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
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
          find.text('Retry').evaluate().isNotEmpty ||
          find.text('Profile ID: —').evaluate().isNotEmpty,
      isTrue,
    );

    for (final tab in [
      'Room',
      'Moment',
      'Message',
      'Me',
      'Room',
      'Message',
      'Moment',
      'Me',
      'Room',
    ]) {
      await tester.tap(find.text(tab).last);
      await tester.pump();
      final exception = tester.takeException();
      final reason = exception is FlutterError
          ? exception.toStringDeep()
          : 'while switching to $tab: $exception';
      expect(exception, isNull, reason: reason);
      expect(find.byType(RivoBottomNav), findsOneWidget);
    }

    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.push<void>(
      MaterialPageRoute<void>(builder: (_) => const CreateRoomScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Room name'), findsOneWidget);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('Room name'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create Room form has phone-photo UI and required room name',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateRoomScreen()));

    expect(find.text('Create Room'), findsNWidgets(2));
    expect(find.text('Room photo'), findsOneWidget);
    expect(find.text('Room name'), findsOneWidget);
    expect(find.text('Room bio (optional)'), findsOneWidget);
    expect(find.textContaining('URL'), findsNothing);
  });

  testWidgets('Moment composer and Edit Profile have no image URL inputs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreateMomentScreen()));
    expect(find.text("What's happening?"), findsOneWidget);
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.textContaining('URL'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditProfileScreen(profile: {'public_id': 100000}),
      ),
    );
    expect(find.text('Profile ID'), findsOneWidget);
    expect(find.text('100000'), findsOneWidget);
    expect(find.textContaining('URL'), findsNothing);
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

  testWidgets('gift effects ignore initial history and play queued gifts in order',
      (tester) async {
    const catalog = [
      {
        'id': 'rose-id',
        'name': 'Rose',
        'effect_mode': 'rose_burst',
        'effect_duration_ms': 1600,
      },
    ];
    final history = [
      {
        'id': 'old',
        'gift_id': 'rose-id',
        'sender_id': 'old-sender',
        'receiver_id': 'receiver',
      },
    ];

    Widget buildOverlay(List<Map<String, dynamic>> events) => MaterialApp(
          home: Scaffold(
            body: GiftEffectOverlay(
              events: events,
              initialEventsLoaded: true,
              giftCatalog: Future.value(catalog),
              child: const Text('Room'),
            ),
          ),
        );

    await tester.pumpWidget(buildOverlay(history));
    expect(find.text('old-sender sent Rose to receiver'), findsNothing);

    await tester.pumpWidget(buildOverlay([
      ...history,
      {
        'id': 'first',
        'gift_id': 'rose-id',
        'sender_id': 'first-sender',
        'receiver_id': 'receiver',
        'quantity': 2,
      },
      {
        'id': 'second',
        'gift_id': 'rose-id',
        'sender_id': 'second-sender',
        'receiver_id': 'receiver',
      },
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('first-sender sent Rose to receiver'), findsOneWidget);
    expect(find.text('Quantity 2'), findsOneWidget);
    expect(find.text('second-sender sent Rose to receiver'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1700));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('second-sender sent Rose to receiver'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
