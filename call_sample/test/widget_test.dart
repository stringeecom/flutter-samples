import 'package:call_sample/main.dart';
import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:call_sample/stringee_wrapper/stringee_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PlatformCallLog platformLog;

  setUpAll(() async {
    platformLog = await installPlatformChannelMocks();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    platformLog.notifications.clear();
    final manager = StringeeCallManager();
    for (final call in manager.calls.toList()) {
      manager.clear(call, dismissCallWidget: false);
    }
  });

  testWidgets('shows disconnected call setup UI', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Call sample'), findsOneWidget);
    expect(find.text('Stringee Call Sample'), findsOneWidget);
    expect(find.text('Not connected...'), findsOneWidget);
    expect(find.text('Connect to Stringee'), findsOneWidget);
    expect(find.text('Enter a Stringee access token'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Logout'), findsNothing);
  });

  testWidgets('connect form reflects progress, errors and token expiry',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Access token'),
      'sample-token',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
    await tester.pump();
    expect(find.text('Connecting...'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    StringeeWrapper().stringeeListener!.onConnectError(401, 'Invalid token');
    await tester.pump();
    expect(find.text('Connect fail: Invalid token'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

    await StringeeWrapper().stringeeListener!.onRequestNewToken();
    await tester.pump();
    expect(find.text('Token expired. Enter a new token'), findsOneWidget);

    StringeeWrapper().stringeeListener!.onDisConnected();
    await tester.pump();
    expect(find.text('Disconnected'), findsOneWidget);
  });

  testWidgets('connected screen exposes all four call choices', (tester) async {
    SharedPreferences.setMockInitialValues({'isPushRegistered': true});
    await tester.pumpWidget(const MyApp());
    await StringeeWrapper().stringeeListener!.onConnected('user-1000');
    await tester.pump();

    expect(find.text('Connected as user-1000'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Start a new call'), findsOneWidget);
    expect(find.text('StringeeCall'), findsOneWidget);
    expect(find.text('StringeeCall2'), findsOneWidget);
    expect(find.text('Voice'), findsNWidgets(2));
    expect(find.text('Video'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), 'callee-1001');
    await tester.pump();
    for (final label in <String>['Voice', 'Video']) {
      for (var index = 0; index < 2; index++) {
        final target = find.text(label).at(index);
        await tester.ensureVisible(target);
        await tester.pump();
        await tester.tap(target);
        await tester.pump();
      }
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  });

  testWidgets('call presentation is single-instance and dismissible',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    final listener = StringeeWrapper().stringeeListener!;

    listener.onPresentCallWidget(const Material(child: Text('Call dialog')));
    await tester.pumpAndSettle();
    expect(find.text('Call dialog'), findsOneWidget);
    listener.onPresentCallWidget(const Material(child: Text('Duplicate')));
    await tester.pump();
    expect(find.text('Duplicate'), findsNothing);

    listener.onDismissCallWidget('Call ended');
    await tester.pumpAndSettle();
    expect(find.text('Call dialog'), findsNothing);
  });

  testWidgets('logout clears the connected session and token', (tester) async {
    SharedPreferences.setMockInitialValues({
      'isPushRegistered': true,
      stringeeAccessTokenKey: 'saved-token',
    });
    await tester.pumpWidget(const MyApp());
    await StringeeWrapper().stringeeListener!.onConnected('user-1000');
    await tester.pump();

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    expect(find.text('Logged out'), findsOneWidget);
    expect(find.text('Connect to Stringee'), findsOneWidget);
    expect(find.text('Logout'), findsNothing);
    expect(
      (await SharedPreferences.getInstance()).getString(stringeeAccessTokenKey),
      isNull,
    );
  });

  testWidgets('app lifecycle mirrors an incoming call as notification',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    final fake = FakeStringeeCall(
      callId: 'incoming-lifecycle',
      from: '1000',
      isVideoCall: true,
    );
    final model = StringeeCallModel(fake);
    StringeeCallManager().calls.add(model);

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();
    expect(
      platformLog.notifications.any((call) => call.method == 'show'),
      isTrue,
    );

    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.hidden,
    );
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.inactive,
    );
    tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pump();
    expect(
      platformLog.notifications.any((call) => call.method == 'cancel'),
      isTrue,
    );

    StringeeCallManager().clear(model, dismissCallWidget: false);
    await tester.pump();
    await fake.close();
  });
}
