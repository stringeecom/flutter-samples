import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:call_sample/stringee_wrapper/push_manager/android_push_manager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PlatformCallLog platformLog;

  setUpAll(() async {
    platformLog = await installPlatformChannelMocks();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    AndroidPushManager().callPermissionRequester = null;
    AndroidPushManager().isAnswerFromPush = false;
    AndroidPushManager().isRejectFromPush = false;
    final manager = StringeeCallManager();
    for (final call in manager.calls.toList()) {
      manager.clear(call, dismissCallWidget: false);
    }
    await AndroidPushManager().release();
    platformLog.notifications.clear();
  });

  group('parseAndroidStringeePushData', () {
    test('parses a JSON encoded Stringee payload', () {
      final result = parseAndroidStringeePushData({
        'stringeePushNotification': '1.0',
        'data':
            '{"callStatus":"started","callId":"call-1","from":{"number":"1001"}}',
      });

      expect(result?['callStatus'], 'started');
      expect(result?['callId'], 'call-1');
      expect((result?['from'] as Map)['number'], '1001');
    });

    test('accepts an already decoded payload map', () {
      final result = parseAndroidStringeePushData({
        'stringeePushNotification': '1.0',
        'data': <String, dynamic>{
          'callStatus': 'started',
          'callId': 'call-2',
        },
      });

      expect(result, {
        'callStatus': 'started',
        'callId': 'call-2',
      });
    });

    test('ignores non-Stringee and malformed payloads', () {
      expect(
        parseAndroidStringeePushData({'data': '{}'}),
        isNull,
      );
      expect(
        parseAndroidStringeePushData({
          'stringeePushNotification': '1.0',
          'data': '{malformed',
        }),
        isNull,
      );
    });
  });

  group('Android Stringee call status', () {
    test('recognizes every terminal server status', () {
      expect(isTerminalAndroidStringeePush({'callStatus': 'ended'}), isTrue);
      expect(isTerminalAndroidStringeePush({'callStatus': 'busy'}), isTrue);
      expect(
        isTerminalAndroidStringeePush({'callStatus': 'agentEnded'}),
        isTrue,
      );
      expect(
        isTerminalAndroidStringeePush({
          'callStatus': 'answered',
          'original': false,
        }),
        isTrue,
      );
    });

    test('keeps the original device notification on local answer', () {
      expect(
        isTerminalAndroidStringeePush({
          'callStatus': 'answered',
          'original': true,
        }),
        isFalse,
      );
      expect(
        isTerminalAndroidStringeePush({
          'callStatus': 'answered',
          'original': 'true',
        }),
        isFalse,
      );
      expect(
        isTerminalAndroidStringeePush({'callStatus': 'started'}),
        isFalse,
      );
    });

    test('normalizes video flag representations', () {
      for (final value in <dynamic>[true, 1, '1', 'true']) {
        expect(isAndroidVideoCallPush({'isVideoCall': value}), isTrue);
      }
      expect(isAndroidVideoCallPush({'isVideoCall': false}), isFalse);
      expect(isAndroidVideoCallPush(const {}), isFalse);
    });

    test('matches notification actions to the intended call', () {
      expect(doesAndroidCallIdMatch('call-1', 'call-1'), isTrue);
      expect(doesAndroidCallIdMatch('call-1', 'call-2'), isFalse);
      expect(doesAndroidCallIdMatch('', 'call-2'), isTrue);
    });

    test('expires stale notification actions after two minutes', () {
      final now = DateTime(2026, 8, 13, 10);

      expect(
        isPendingAndroidCallActionExpired(
          createdAtMillis:
              now.subtract(const Duration(seconds: 119)).millisecondsSinceEpoch,
          now: now,
        ),
        isFalse,
      );
      expect(
        isPendingAndroidCallActionExpired(
          createdAtMillis:
              now.subtract(const Duration(seconds: 121)).millisecondsSinceEpoch,
          now: now,
        ),
        isTrue,
      );
      expect(
        isPendingAndroidCallActionExpired(
          createdAtMillis: 0,
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('AndroidPushManager integration', () {
    test('exposes stable notification configuration', () {
      final manager = AndroidPushManager();
      expect(manager.notificationId, 280196);
      expect(manager.inCallNotificationId, 14101997);
      expect(manager.channelId, 'stringee_incoming_call_v2');
      expect(manager.channelName, 'Incoming calls');
      expect(manager.inCallChannelId, 'stringee_in_call_v1');
      expect(manager.actionAnswer, 'action_answer');
      expect(manager.actionReject, 'action_reject');
      expect(manager.actionClickNotification, 'action_open_call');
      expect(manager.androidSettings.defaultIcon, 'ic_noti');
    });

    test('started push without saved token cleans stale state', () async {
      final manager = AndroidPushManager();
      await manager.handleStringeePush({
        'callStatus': 'started',
        'callId': 'call-no-token',
        'from': {'alias': 'Alice', 'number': '1000'},
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('stringee_incoming_notification_call_id'), isNull);
      expect(platformLog.notifications.any((call) => call.method == 'show'),
          isFalse);
    });

    test('started remote message shows voice/video caller notification',
        () async {
      SharedPreferences.setMockInitialValues({
        androidStringeeAccessTokenKey: 'access-token',
      });
      final manager = AndroidPushManager();
      await manager.handleRemoteMessage(
        RemoteMessage(
          data: {
            'stringeePushNotification': '1.0',
            'data':
                '{"callStatus":"started","callId":"call-video","isVideoCall":true,"from":{"alias":"Alice","number":"1000"}}',
          },
        ),
      );
      await manager.showIncomingCallNotification(
        '',
        '1001',
        callId: 'call-voice',
      );

      final shows = platformLog.notifications
          .where((call) => call.method == 'show')
          .toList();
      expect(shows, hasLength(2));
      expect((shows.first.arguments as Map)['title'], 'Incoming video call');
      expect((shows.first.arguments as Map)['body'], 'Alice');
      expect((shows.last.arguments as Map)['body'], '1001');
    });

    test('terminal pushes and matching cancel clear notification only',
        () async {
      SharedPreferences.setMockInitialValues({
        'stringee_incoming_notification_call_id': 'call-1',
      });
      final manager = AndroidPushManager();

      await manager.cancelIncomingCallNotification(callId: 'another');
      expect(platformLog.notifications, isEmpty);
      await manager.handleStringeePush({
        'callStatus': 'ended',
        'callId': 'call-1',
      });

      expect(
        platformLog.notifications.any((call) => call.method == 'cancel'),
        isTrue,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('stringee_incoming_notification_call_id'), isNull);
    });

    test('foreground service state ignores mismatched call cleanup', () async {
      final manager = AndroidPushManager();
      final fake = FakeStringeeCall(callId: 'service-call', to: 'Bob');
      final model = StringeeCallModel(
        fake,
        isIncomingCall: false,
        from: 'Alice',
        to: 'Bob',
      );

      await manager.startInCallService(model);
      await manager.markCallConnected(model);
      await manager.stopInCallService(callId: 'different');
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('stringee_foreground_service_call_id'),
          'service-call');
      await manager.stopInCallService(callId: 'service-call');
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('stringee_foreground_service_call_id'), isNull);
      await manager.requestFullScreenIntentPermissionIfNeeded();
      model.dispose();
      await fake.close();
    });

    test('background answer is reconciled with matching incoming call',
        () async {
      final manager = AndroidPushManager();
      await manager.handleBackgroundNotificationResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'action_answer',
          payload: 'call-answer',
        ),
      );
      final fake = FakeStringeeCall(callId: 'call-answer');
      final model = StringeeCallModel(fake);

      expect(await manager.reconcileIncomingCall(model), isTrue);
      expect(manager.isAnswerFromPush, isTrue);
      expect(fake.invocations, isEmpty);
      model.dispose();
      await fake.close();
    });

    test('background reject is applied and suppresses incoming UI', () async {
      final manager = AndroidPushManager();
      await manager.handleBackgroundNotificationResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'action_reject',
          payload: 'call-reject',
        ),
      );
      final fake = FakeStringeeCall(callId: 'call-reject');
      final model = StringeeCallModel(fake);
      StringeeCallManager().calls.add(model);

      expect(await manager.reconcileIncomingCall(model), isFalse);
      expect(fake.invocations, contains('reject'));
      expect(StringeeCallManager().calls, isNot(contains(model)));
      await fake.close();
    });

    test('stale and mismatched pending actions do not affect a new call',
        () async {
      SharedPreferences.setMockInitialValues({
        'stringee_pending_notification_action': 'action_reject',
        'stringee_pending_notification_action_call_id': 'old-call',
        'stringee_pending_notification_action_created_at': DateTime.now()
            .subtract(const Duration(minutes: 3))
            .millisecondsSinceEpoch,
      });
      final manager = AndroidPushManager();
      final fake = FakeStringeeCall(callId: 'new-call');
      final model = StringeeCallModel(fake);

      expect(await manager.reconcileIncomingCall(model), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('stringee_pending_notification_action'), isNull);
      model.dispose();
      await fake.close();
    });

    test('notification stream applies answer permission outcomes', () async {
      final manager = AndroidPushManager();
      final fake = FakeStringeeCall(callId: 'stream-call');
      final model = StringeeCallModel(fake);
      StringeeCallManager().calls.add(model);
      await manager.listenNotificationSelect();
      await manager.listenNotificationSelect();

      manager.callPermissionRequester = () async => true;
      manager.selectNotificationStream.add(
        const AndroidCallNotificationAction(
          action: 'action_answer',
          callId: 'stream-call',
        ),
      );
      await pumpEventQueue();
      expect(fake.invocations, contains('answer'));

      manager.callPermissionRequester = () async => false;
      manager.selectNotificationStream.add(
        const AndroidCallNotificationAction(
          action: 'action_answer',
          callId: 'stream-call',
        ),
      );
      await pumpEventQueue();
      expect(fake.invocations, contains('hangup'));
      await manager.release();
      if (StringeeCallManager().calls.contains(model)) {
        StringeeCallManager().clear(model, dismissCallWidget: false);
      }
      await fake.close();
    });

    test('notification initialization queues launch action once', () async {
      platformLog.notificationLaunchDetails =
          const NotificationAppLaunchDetails(
        true,
        notificationResponse: NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotification,
          payload: 'launch-call',
        ),
      );
      final manager = AndroidPushManager();
      final events = <AndroidCallNotificationAction>[];
      final subscription =
          manager.selectNotificationStream.stream.listen(events.add);

      await manager.handleNotificationAction();
      await manager.handleNotificationAction();
      await pumpEventQueue();

      expect(events.single.action, 'action_open_call');
      expect(events.single.callId, 'launch-call');
      await subscription.cancel();
    });

    test('cleanupForDisconnect removes Android session and flags', () async {
      SharedPreferences.setMockInitialValues({
        androidStringeeAccessTokenKey: 'token',
        'stringee_pending_notification_action': 'action_answer',
        'stringee_pending_notification_action_call_id': 'call',
        'stringee_pending_notification_action_created_at':
            DateTime.now().millisecondsSinceEpoch,
      });
      final manager = AndroidPushManager()
        ..isAnswerFromPush = true
        ..isRejectFromPush = true;

      await manager.cleanupForDisconnect();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(androidStringeeAccessTokenKey), isNull);
      expect(manager.isAnswerFromPush, isFalse);
      expect(manager.isRejectFromPush, isFalse);
    });
  });
}
