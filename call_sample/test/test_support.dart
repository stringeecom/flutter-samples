import 'dart:async';

import 'package:call_sample/stringee_wrapper/interfaces/stringee_call_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

const _stringeeEventChannel =
    MethodChannel('com.stringee.flutter.eventchannel');
const _audioEventChannel = MethodChannel(
  'com.stringee.flutter.audio.event_channel',
);
const _notificationChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);
const _callkeepMethodChannel = MethodChannel('FlutterCallKeep.Method');

class PlatformCallLog {
  final List<MethodCall> stringee = [];
  final List<MethodCall> audio = [];
  final List<MethodCall> notifications = [];
  final List<MethodCall> callkeep = [];
  bool callkeepActive = true;
  NotificationAppLaunchDetails? notificationLaunchDetails;
}

Future<PlatformCallLog> installPlatformChannelMocks() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final log = PlatformCallLog();
  FlutterLocalNotificationsPlatform.instance =
      FakeLocalNotificationsPlatform(log);

  messenger.setMockMethodCallHandler(_stringeeEventChannel, (_) async => null);
  messenger.setMockMethodCallHandler(_audioEventChannel, (_) async => null);
  messenger.setMockMethodCallHandler(
    StringeeClient.methodChannel,
    (call) async {
      log.stringee.add(call);
      return <String, dynamic>{
        'status': true,
        'code': 0,
        'message': 'Success',
      };
    },
  );
  messenger.setMockMethodCallHandler(
    StringeeAudioManager.methodChannel,
    (call) async {
      log.audio.add(call);
      return <String, dynamic>{
        'status': true,
        'code': 0,
        'message': 'Success',
      };
    },
  );
  messenger.setMockMethodCallHandler(_notificationChannel, (call) async {
    log.notifications.add(call);
    switch (call.method) {
      case 'initialize':
      case 'requestFullScreenIntentPermission':
        return true;
      case 'getNotificationAppLaunchDetails':
        return log.notificationLaunchDetails;
      default:
        return null;
    }
  });
  messenger.setMockMethodCallHandler(_callkeepMethodChannel, (call) async {
    log.callkeep.add(call);
    if (call.method == 'isCallActive') return log.callkeepActive;
    return null;
  });
  return log;
}

class FakeLocalNotificationsPlatform
    extends AndroidFlutterLocalNotificationsPlugin {
  FakeLocalNotificationsPlatform(this.log);

  final PlatformCallLog log;

  @override
  Future<bool> initialize(
    AndroidInitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async {
    log.notifications.add(const MethodCall('initialize'));
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async {
    return log.notificationLaunchDetails;
  }

  @override
  Future<void> show(
    int id,
    String? title,
    String? body, {
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    log.notifications.add(
      MethodCall('show', <String, Object?>{
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
      }),
    );
  }

  @override
  Future<void> cancel(int id, {String? tag}) async {
    log.notifications.add(MethodCall('cancel', <String, Object?>{'id': id}));
  }

  @override
  Future<void> cancelAll() async {
    log.notifications.add(const MethodCall('cancelAll'));
  }

  @override
  Future<bool?> requestFullScreenIntentPermission() async {
    log.notifications.add(
      const MethodCall('requestFullScreenIntentPermission'),
    );
    return true;
  }

  @override
  Future<void> startForegroundService(
    int id,
    String? title,
    String? body, {
    AndroidNotificationDetails? notificationDetails,
    String? payload,
    AndroidServiceStartType startType = AndroidServiceStartType.startSticky,
    Set<AndroidServiceForegroundType>? foregroundServiceTypes,
  }) async {
    log.notifications.add(
      MethodCall('startForegroundService', <String, Object?>{
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
      }),
    );
  }

  @override
  Future<void> stopForegroundService() async {
    log.notifications.add(const MethodCall('stopForegroundService'));
  }
}

class FakeStringeeCall implements StringeeCallInterface {
  FakeStringeeCall({
    this.callId = 'call-1',
    this.serial = 1,
    this.from = '1000',
    this.to = '1001',
    this.fromAlias = 'Caller',
    this.toAlias = 'Callee',
    this.callType = StringeeCallType.appToAppOutgoing,
    this.customDataFromYourServer,
    this.isVideoCall = false,
  });

  @override
  String? callId;
  @override
  int? serial;
  @override
  String? from;
  @override
  String? to;
  @override
  String? fromAlias;
  @override
  String? toAlias;
  @override
  StringeeCallType? callType;
  @override
  String? customDataFromYourServer;
  @override
  bool isVideoCall;

  final StreamController<dynamic> events = StreamController.broadcast();
  final List<String> invocations = [];
  bool succeed = true;

  Map<String, dynamic> get response => <String, dynamic>{
        'status': succeed,
        'code': succeed ? 0 : -1,
        'message': succeed ? 'Success' : 'Failure',
      };

  @override
  StreamController<dynamic> get eventStreamController => events;

  void emit(Object eventType, Object body) {
    events.add(<dynamic, dynamic>{'eventType': eventType, 'body': body});
  }

  @override
  Future<Map<dynamic, dynamic>> answer() async {
    invocations.add('answer');
    return response;
  }

  @override
  Future<Result> changeAudioDevice(AudioDevice device) async {
    invocations.add('changeAudioDevice');
    return Result(
      status: succeed,
      code: succeed ? 0 : -1,
      message: succeed ? 'Success' : 'Failure',
    );
  }

  @override
  Future<Map<dynamic, dynamic>> enableVideo(bool enableVideo) async {
    invocations.add('enableVideo:$enableVideo');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> getCallStats() async {
    invocations.add('getCallStats');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> hangup() async {
    invocations.add('hangup');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> initAnswer() async {
    invocations.add('initAnswer');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> makeCall(
    Map<dynamic, dynamic> parameters,
  ) async {
    invocations.add('makeCall');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> makeCallFromParams(
      MakeCallParams params) async {
    invocations.add('makeCallFromParams');
    isVideoCall = params.isVideoCall ?? false;
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> mute(bool mute) async {
    invocations.add('mute:$mute');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> reject() async {
    invocations.add('reject');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> resumeVideo() async {
    invocations.add('resumeVideo');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> send(String dtmf) async {
    invocations.add('send:$dtmf');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> sendCallInfo(
    Map<dynamic, dynamic> callInfo,
  ) async {
    invocations.add('sendCallInfo');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> setMirror(
    bool isLocal,
    bool isMirror,
  ) async {
    invocations.add('setMirror:$isLocal:$isMirror');
    return response;
  }

  @override
  Future<Map<dynamic, dynamic>> switchCamera({String? cameraId}) async {
    invocations.add('switchCamera');
    return response;
  }

  Future<void> close() => events.close();
}
