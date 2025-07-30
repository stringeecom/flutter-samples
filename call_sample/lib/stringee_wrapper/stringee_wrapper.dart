import 'dart:async';

import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_call_widget.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

import 'common/common.dart';
import 'push_manager/callkeep_manager.dart';
import 'stringee_listener.dart';

export 'package:stringee_plugin/stringee_plugin.dart' show VideoQuality;

export 'stringee_listener.dart';

class StringeeWrapper {
  static final StringeeWrapper _instance = StringeeWrapper._internal();

  factory StringeeWrapper() {
    return _instance;
  }

  StringeeWrapper._internal();

  StringeeClient? _stringeeClient;
  StringeeListener? _stringeeListener;

  // call widget
  Widget? _callWidget;

  void setCallWidget(Widget? callWidget) {
    _callWidget = callWidget;
  }

  // timeout for call
  final int _callTimeout = 60;

  StringeeClient? get stringeeClient => _stringeeClient;

  StringeeListener? get stringeeListener => _stringeeListener;

  int get callTimeout => _callTimeout;

  bool get connected => _stringeeClient?.hasConnected ?? false;

  /// initialize Stringee client with server address andd base api url
  /// [serverAddress] is the server address
  /// [baseApiUrl] is the base api url
  void initialize({
    List<StringeeServerAddress>? serverAddresses,
    String? baseAPIUrl,
  }) {
    if (kDebugMode) {
      print('StringeeWrapper initialize $baseAPIUrl $serverAddresses');
    }
    _stringeeClient = StringeeClient(
      serverAddresses: serverAddresses,
      baseAPIUrl: baseAPIUrl,
    );

    _stringeeClient!.eventStreamController.stream.listen((event) {
      _handleStringeeEvent(event as Map<dynamic, dynamic>);
    });

    /// move this to somewhere else to configure with more options like appName, icon, etc.
    if (isIOS) {
      CallkeepManager().configureCallKeep();
    }
  }

  /// connect to Stringee server
  /// [token] is the token of the user
  Future<void> connect(String token) async {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    _stringeeClient!.connect(token);
  }

  /// register push to receive call when app is in background
  Future<void> registerPush({bool? isProduction, bool? isVoip}) async {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    if (isIOS && CallkeepManager().pushToken.isNotEmpty) {
      Map<dynamic, dynamic> registerPushResult =
          await _stringeeClient!.registerPush(
        CallkeepManager().pushToken,
        isVoip: isVoip,
        // if isProduction is null, use kReleaseMode
        isProduction: isProduction ?? kReleaseMode,
      );
      handleRegisterPushResult(
        CallkeepManager().pushToken,
        registerPushResult,
      );
      return;
    }
    if (!isIOS) {
      String deviceToken = await FirebaseMessaging.instance.getToken() ?? '';
      if (deviceToken.isNotEmpty) {
        Map<dynamic, dynamic> registerPushResult =
            await _stringeeClient!.registerPush(deviceToken);
        handleRegisterPushResult(
          deviceToken,
          registerPushResult,
        );
      }
      return;
    }
  }

  void handleRegisterPushResult(
      String token, Map<dynamic, dynamic> value) async {
    if (value['status']) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('isPushRegistered', true);
      prefs.setString('pushToken', token);
    }
  }

  /// unregister push to receive call when app is in background
  Future<void> unregisterPush() async {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isPushRegistered = prefs.getBool('isPushRegistered') ?? false;
    if (!isPushRegistered) {
      return;
    }
    String token = prefs.getString('pushToken') ?? '';
    if (token.isNotEmpty) {
      Map<dynamic, dynamic> unRegisterPushResult =
          await _stringeeClient!.unregisterPush(token);
      if (unRegisterPushResult['status']) {
        prefs.remove('isPushRegistered');
        prefs.remove('pushToken');
      }
    }
  }

  /// disconnect from Stringee server
  Future<void> disconnect() async {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    //await unregisterPush();
    _stringeeClient!.disconnect();
  }

  /// make a call
  /// [from] is the caller id
  /// [to] is the callee id
  /// [isVideoCall] is the type of the call
  /// if [isVideoCall] is true, the call is a video call
  /// if [isVideoCall] is false, the call is an audio call
  /// [isVideoCall] default is false
  Future<void> makeCall({
    String? from,
    required String to,
    bool isVideoCall = false,
    Map<dynamic, dynamic>? customData,
    VideoQuality? videoQuality,
  }) async {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    StringeeCall? call;
    StringeeCall2? call2;
    if (isVideoCall) {
      call2 = StringeeCall2(_stringeeClient!);
    } else {
      call = StringeeCall(_stringeeClient!);
    }
    final result = await StringeeCallManager.instance.handleOutgoingCall(
      call: call,
      call2: call2,
      from: from ?? _stringeeClient!.userId!,
      to: to,
      customData: customData,
      videoQuality: videoQuality,
    );
    if (result.isSuccess) {
      _stringeeListener?.onPresentCallWidget.call(ChangeNotifierProvider(
        create: (_) => result.success!,
        child: _callWidget ?? const StringeeCallWidget(),
      ));
    } else {
      debugPrint('Error: ${result.failure}');
    }
  }

  /// add listener to listen event from StringeeWrapper
  /// [listener] is the listener to listen event
  Future<void> addListener(StringeeListener listener) async {
    _stringeeListener = listener;
  }

  Future<void> _handleStringeeEvent(Map<dynamic, dynamic> event) async {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    switch (event['eventType']) {
      case StringeeClientEvents.didConnect:
        _stringeeListener?.onConnected.call(_stringeeClient!.userId!);
        break;
      case StringeeClientEvents.didDisconnect:
        _stringeeListener?.onDisConnected.call();
        break;
      case StringeeClientEvents.didFailWithError:
        int code = event['body']['code'];
        String msg = event['body']['message'];
        _stringeeListener?.onConnectError.call(code, msg);
        break;
      case StringeeClientEvents.requestAccessToken:
        _stringeeListener?.onRequestNewToken.call();
        break;
      case StringeeClientEvents.didReceiveCustomMessage:
        _stringeeListener?.onReceiveCustomMessage?.call(event['body']);
        break;
      case StringeeClientEvents.incomingCall:
        StringeeCall call = event['body'];
        _incomingCall(call, null);
        break;
      case StringeeClientEvents.incomingCall2:
        StringeeCall2 call2 = event['body'];
        _incomingCall(null, call2);
        break;
      default:
        break;
    }
  }

  Future<void> _incomingCall(StringeeCall? call, StringeeCall2? call2) async {
    debugPrint('Incoming call');
    final result = await StringeeCallManager.instance
        .handleIncomingCall(call: call, call2: call2);
    if (result.isSuccess) {
      _stringeeListener?.onPresentCallWidget.call(ChangeNotifierProvider(
        create: (_) => result.success,
        child: _callWidget ?? const StringeeCallWidget(),
      ));
    } else {
      debugPrint('Error: ${result.failure}');
      if (result.failure == 'There is an active call') {
        if (call != null) {
          call.reject();
        }
        if (call2 != null) {
          call2.reject();
        }
      }
      // TODO: - handle error if needed
    }
  }

  bool get isConnected => _stringeeClient?.hasConnected ?? false;

  Future<bool> requestCallPermissions() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    List<Permission> permissions = [
      Permission.camera,
      Permission.microphone,
    ];
    if (androidInfo.version.sdkInt >= 31) {
      permissions.add(Permission.bluetoothConnect);
    }
    return _requestPermission(permissions);
  }

  Future<bool> requestNotificationPermissions() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      List<Permission> permissions = [
        Permission.notification,
      ];
      return _requestPermission(permissions);
    }
    return true;
  }

  Future<bool> _requestPermission(List<Permission> permissions) async {
    Map<Permission, PermissionStatus> permissionsStatus =
        await permissions.request();
    debugPrint('Permission statuses - $permissionsStatus');
    bool isAllGranted = true;
    permissionsStatus.forEach((key, value) {
      if (value != PermissionStatus.granted) {
        isAllGranted = false;
      }
    });
    return isAllGranted;
  }
}
