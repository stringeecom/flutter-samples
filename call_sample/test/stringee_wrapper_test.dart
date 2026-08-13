import 'dart:async';

import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/push_manager/android_push_manager.dart';
import 'package:call_sample/stringee_wrapper/stringee_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final nativeEvents = StreamController<dynamic>.broadcast();
  late PlatformCallLog platformLog;
  final wrapper = StringeeWrapper();
  final manager = StringeeCallManager();

  setUpAll(() async {
    platformLog = await installPlatformChannelMocks();
    SharedPreferences.setMockInitialValues({});
    StringeeClient.broadcastStream = nativeEvents.stream;
  });

  tearDownAll(() async {
    for (final call in manager.calls.toList()) {
      manager.clear(call, dismissCallWidget: false);
    }
    await AndroidPushManager().cleanupForDisconnect();
    await nativeEvents.close();
  });

  test('requires initialization before client operations', () async {
    expect(() => wrapper.connect('token'), throwsException);
    expect(() => wrapper.registerPush(), throwsException);
    expect(() => wrapper.unregisterPush(), throwsException);
    expect(() => wrapper.disconnect(), throwsException);
    expect(() => wrapper.logout(), throwsException);
    expect(() => wrapper.makeVoiceCall(to: '1001'), throwsException);
  });

  test('initializes once and validates/persists access token', () async {
    wrapper.initialize(baseAPIUrl: 'https://api.example.test');
    final client = wrapper.stringeeClient;
    wrapper.initialize();
    expect(wrapper.stringeeClient, same(client));
    expect(wrapper.connected, isFalse);
    expect(wrapper.isConnected, isFalse);
    expect(wrapper.callTimeout, 60);

    await expectLater(wrapper.connect('  '), throwsArgumentError);
    await wrapper.connect('  access-token  ');
    expect(await wrapper.getSavedAccessToken(), 'access-token');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(androidStringeeAccessTokenKey), 'access-token');
    expect(
        platformLog.stringee.any((call) => call.method == 'connect'), isTrue);

    await wrapper.clearSavedAccessToken();
    expect(await wrapper.getSavedAccessToken(), isEmpty);
  });

  test('forwards all connection and message events to current listener',
      () async {
    final events = <String>[];
    final customMessages = <Map<dynamic, dynamic>>[];
    final listener = StringeeListener(
      onConnected: (userId) => events.add('connected:$userId'),
      onDisConnected: () => events.add('disconnected'),
      onRequestNewToken: () => events.add('token'),
      onConnectError: (code, message) => events.add('error:$code:$message'),
      onPresentCallWidget: (_) => events.add('present'),
      onDismissCallWidget: (message) => events.add('dismiss:$message'),
      onReceiveCustomMessage: customMessages.add,
    );
    await wrapper.addListener(listener);
    final client = wrapper.stringeeClient!;

    nativeEvents.add({
      'nativeEventType': StringeeObjectEventType.client.index,
      'uuid': client.uuid,
      'event': 'didConnect',
      'body': {
        'userId': 'user-1000',
        'projectId': 'project',
        'isReconnecting': false,
      },
    });
    await pumpEventQueue();
    expect(wrapper.connected, isTrue);
    expect(wrapper.isConnected, isTrue);
    expect(events, contains('connected:user-1000'));

    client.eventStreamController.add({
      'eventType': StringeeClientEvents.didFailWithError,
      'body': {'code': 401, 'message': 'invalid'},
    });
    client.eventStreamController.add({
      'eventType': StringeeClientEvents.requestAccessToken,
      'body': null,
    });
    client.eventStreamController.add({
      'eventType': StringeeClientEvents.didReceiveCustomMessage,
      'body': {'message': 'hello'},
    });
    await pumpEventQueue();

    expect(events, containsAll(<String>['error:401:invalid', 'token']));
    expect(customMessages.single['message'], 'hello');

    nativeEvents.add({
      'nativeEventType': StringeeObjectEventType.client.index,
      'uuid': client.uuid,
      'event': 'didDisconnect',
      'body': {
        'userId': 'user-1000',
        'projectId': 'project',
        'isReconnecting': false,
      },
    });
    await pumpEventQueue();
    expect(events, contains('disconnected'));
    expect(wrapper.connected, isFalse);

    wrapper.removeListener(
      StringeeListener(
        onConnected: (_) {},
        onDisConnected: () {},
        onRequestNewToken: () {},
        onConnectError: (_, __) {},
        onPresentCallWidget: (_) {},
        onDismissCallWidget: (_) {},
      ),
    );
    expect(wrapper.stringeeListener, same(listener));
    wrapper.removeListener(listener);
    expect(wrapper.stringeeListener, isNull);
  });

  test('presents all four outgoing call variants when connected', () async {
    final presented = <Widget>[];
    final listener = StringeeListener(
      onConnected: (_) {},
      onDisConnected: () {},
      onRequestNewToken: () {},
      onConnectError: (_, __) {},
      onPresentCallWidget: presented.add,
      onDismissCallWidget: (_) {},
    );
    await wrapper.addListener(listener);
    wrapper.setCallWidget(const SizedBox(key: Key('custom-call')));
    final client = wrapper.stringeeClient!;
    nativeEvents.add({
      'nativeEventType': StringeeObjectEventType.client.index,
      'uuid': client.uuid,
      'event': 'didConnect',
      'body': {
        'userId': '1000',
        'projectId': 'project',
        'isReconnecting': false,
      },
    });
    await pumpEventQueue();

    final actions = <Future<void> Function()>[
      () => wrapper.makeVoiceCall(to: '1001'),
      () => wrapper.makeVideoCall(to: '1002', videoQuality: VideoQuality.hd),
      () => wrapper.makeVoiceCall2(to: '1003'),
      () => wrapper.makeVideoCall2(
            from: 'alias',
            to: '1004',
            customData: const {'source': 'test'},
            videoQuality: VideoQuality.fullHd,
          ),
    ];
    for (final action in actions) {
      await action();
      expect(manager.calls, hasLength(1));
      manager.clear(manager.calls.single, dismissCallWidget: false);
    }
    expect(presented, hasLength(4));
    expect(
        presented.every((widget) => widget is ChangeNotifierProvider), isTrue);

    await wrapper.makeVoiceCall(to: ' ');
    expect(presented, hasLength(4));
    wrapper.setCallWidget(null);
  });

  test('handles incoming Call and Call2 including active-call rejection',
      () async {
    final presented = <Widget>[];
    await wrapper.addListener(
      StringeeListener(
        onConnected: (_) {},
        onDisConnected: () {},
        onRequestNewToken: () {},
        onConnectError: (_, __) {},
        onPresentCallWidget: presented.add,
        onDismissCallWidget: (_) {},
      ),
    );
    final client = wrapper.stringeeClient!;

    client.eventStreamController.add({
      'eventType': StringeeClientEvents.incomingCall,
      'body': StringeeCall(client),
    });
    await pumpEventQueue();
    expect(presented, hasLength(1));
    expect(manager.calls, hasLength(1));

    client.eventStreamController.add({
      'eventType': StringeeClientEvents.incomingCall2,
      'body': StringeeCall2(client),
    });
    await pumpEventQueue();
    expect(presented, hasLength(1));
    expect(
      platformLog.stringee.any((call) => call.method == 'reject2'),
      isTrue,
    );
    manager.clear(manager.calls.single, dismissCallWidget: false);

    client.eventStreamController.add({
      'eventType': StringeeClientEvents.incomingCall2,
      'body': StringeeCall2(client),
    });
    await pumpEventQueue();
    expect(presented, hasLength(2));
    manager.clear(manager.calls.single, dismissCallWidget: false);
  });

  test('persists push registration and unregisters saved token', () async {
    SharedPreferences.setMockInitialValues({});
    await wrapper.handleRegisterPushResult('ignored', {'status': false});
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isPushRegistered'), isNull);

    await wrapper.handleRegisterPushResult('push-token', {'status': true});
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isPushRegistered'), isTrue);
    expect(prefs.getString('pushToken'), 'push-token');

    await wrapper.unregisterPush();
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('isPushRegistered'), isNull);
    expect(prefs.getString('pushToken'), isNull);
    await wrapper.unregisterPush();
  });

  test('disconnect preserves foreground token while logout clears all state',
      () async {
    SharedPreferences.setMockInitialValues({
      stringeeAccessTokenKey: 'foreground-token',
      androidStringeeAccessTokenKey: 'android-token',
    });
    await wrapper.disconnect();
    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(stringeeAccessTokenKey), 'foreground-token');
    expect(prefs.getString(androidStringeeAccessTokenKey), isNull);

    await prefs.setString(stringeeAccessTokenKey, 'foreground-token');
    await prefs.setString(androidStringeeAccessTokenKey, 'android-token');
    await prefs.setBool('isPushRegistered', true);
    await prefs.setString('pushToken', 'push-token');
    await wrapper.logout();
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(stringeeAccessTokenKey), isNull);
    expect(prefs.getString(androidStringeeAccessTokenKey), isNull);
    expect(prefs.getBool('isPushRegistered'), isNull);
    expect(platformLog.stringee.where((call) => call.method == 'disconnect'),
        isNotEmpty);
  });
}
