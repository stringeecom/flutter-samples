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
import 'call/stringee_call_model.dart';
import 'push_manager/callkeep_manager.dart';
import 'push_manager/android_push_manager.dart';
import 'stringee_listener.dart';

export 'package:stringee_plugin/stringee_plugin.dart' show VideoQuality;

export 'stringee_listener.dart';

/// Shared-preferences key used to restore the foreground Stringee session.
const String stringeeAccessTokenKey = 'stringee_access_token';

/// Application-level facade for connection, push registration, and calls.
///
/// The singleton owns one [StringeeClient], persists the last access token,
/// translates SDK events into [StringeeListener] callbacks, and creates a
/// shared call UI for both `StringeeCall` generations.
class StringeeWrapper {
  static final StringeeWrapper _instance = StringeeWrapper._internal();

  /// Returns the process-wide wrapper instance.
  factory StringeeWrapper() {
    return _instance;
  }

  StringeeWrapper._internal();

  StringeeClient? _stringeeClient;
  StringeeListener? _stringeeListener;
  Future<void>? _pendingPushRegistration;

  // call widget
  Widget? _callWidget;

  /// Overrides the widget presented for incoming and outgoing calls.
  ///
  /// Passing `null` restores the built-in [StringeeCallWidget].
  void setCallWidget(Widget? callWidget) {
    _callWidget = callWidget;
  }

  // timeout for call
  final int _callTimeout = 60;

  /// The underlying SDK client, or `null` before [initialize].
  StringeeClient? get stringeeClient => _stringeeClient;

  /// The currently registered application listener.
  StringeeListener? get stringeeListener => _stringeeListener;

  /// Maximum time, in seconds, for a call to reach its started state.
  int get callTimeout => _callTimeout;

  /// Whether the underlying SDK client is currently connected.
  bool get connected => _stringeeClient?.hasConnected ?? false;

  /// Creates the SDK client and starts listening for Stringee events.
  ///
  /// Optional [serverAddresses] and [baseAPIUrl] select custom Stringee
  /// endpoints. Repeated calls are ignored after the client is created.
  void initialize({
    List<StringeeServerAddress>? serverAddresses,
    String? baseAPIUrl,
  }) {
    if (_stringeeClient != null) {
      return;
    }
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

  /// Persists [token] and connects to Stringee.
  ///
  /// Throws when [initialize] has not been called or [token] is empty.
  Future<void> connect(String token) async {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    final accessToken = token.trim();
    if (accessToken.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Access token cannot be empty');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(stringeeAccessTokenKey, accessToken);
    if (!isIOS) {
      await prefs.setString(androidStringeeAccessTokenKey, accessToken);
    }
    await _stringeeClient!.connect(accessToken);
  }

  /// Returns the access token stored for automatic reconnect.
  Future<String> getSavedAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(stringeeAccessTokenKey) ?? '';
  }

  /// Removes the access token used by foreground and Android background flows.
  Future<void> clearSavedAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(stringeeAccessTokenKey);
    if (!isIOS) {
      await prefs.remove(androidStringeeAccessTokenKey);
    }
  }

  Future<void> _clearSavedPushRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isPushRegistered');
    await prefs.remove('pushToken');
  }

  /// Registers the current FCM or PushKit token for incoming-call push.
  ///
  /// Concurrent calls share the same pending registration operation.
  Future<void> registerPush({bool? isProduction, bool? isVoip}) {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    final pending = _pendingPushRegistration;
    if (pending != null) return pending;

    late final Future<void> operation;
    operation = _registerPush(
      isProduction: isProduction,
      isVoip: isVoip,
    ).whenComplete(() {
      if (identical(_pendingPushRegistration, operation)) {
        _pendingPushRegistration = null;
      }
    });
    _pendingPushRegistration = operation;
    return operation;
  }

  Future<void> _registerPush({bool? isProduction, bool? isVoip}) async {
    if (isIOS && CallkeepManager().pushToken.isNotEmpty) {
      Map<dynamic, dynamic> registerPushResult =
          await _stringeeClient!.registerPush(
        CallkeepManager().pushToken,
        isVoip: isVoip,
        // if isProduction is null, use kReleaseMode
        isProduction: isProduction ?? kReleaseMode,
      );
      await handleRegisterPushResult(
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
        await handleRegisterPushResult(deviceToken, registerPushResult);
      }
      return;
    }
  }

  /// Persists a successful push-registration result for later unregistering.
  Future<void> handleRegisterPushResult(
    String token,
    Map<dynamic, dynamic> value,
  ) async {
    if (value['status'] == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isPushRegistered', true);
      await prefs.setString('pushToken', token);
    }
  }

  /// Unregisters the saved device token from Stringee, when registered.
  Future<void> unregisterPush() async {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    await _pendingPushRegistration;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    bool isPushRegistered = prefs.getBool('isPushRegistered') ?? false;
    if (!isPushRegistered) {
      return;
    }
    String token = prefs.getString('pushToken') ?? '';
    if (token.isNotEmpty) {
      Map<dynamic, dynamic> unRegisterPushResult =
          await _stringeeClient!.unregisterPush(token);
      if (unRegisterPushResult['status'] == true) {
        await prefs.remove('isPushRegistered');
        await prefs.remove('pushToken');
      }
    }
  }

  /// Unregisters Android push state and disconnects the SDK client.
  ///
  /// Unlike [logout], this method does not clear the saved foreground token.
  Future<void> disconnect() async {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    try {
      if (!isIOS) await unregisterPush();
    } catch (error) {
      debugPrint('Unable to unregister Stringee push: $error');
    } finally {
      if (!isIOS) await AndroidPushManager().cleanupForDisconnect();
      await _stringeeClient!.disconnect();
    }
  }

  /// Unregisters push, clears the persisted session, and disconnects.
  Future<void> logout() async {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    try {
      await unregisterPush();
    } catch (error) {
      debugPrint('Unable to unregister Stringee push: $error');
    } finally {
      try {
        if (!isIOS) await AndroidPushManager().cleanupForDisconnect();
      } catch (error) {
        debugPrint('Unable to clean up Android call state: $error');
      }
      try {
        await _clearSavedPushRegistration();
        await clearSavedAccessToken();
      } finally {
        await _stringeeClient!.disconnect();
      }
    }
  }

  /// Presents an outgoing voice call backed by [StringeeCall].
  Future<void> makeVoiceCall({
    String? from,
    required String to,
    Map<dynamic, dynamic>? customData,
  }) async {
    final client = _clientForOutgoingCall(to);
    if (client == null) return;
    final result =
        await StringeeCallManager.instance.handleOutgoingStringeeCall(
      call: StringeeCall(client),
      from: from ?? _stringeeClient!.userId!,
      to: to.trim(),
      isVideoCall: false,
      customData: customData,
    );
    _presentOutgoingCall(result);
  }

  /// Presents an outgoing video call backed by [StringeeCall].
  Future<void> makeVideoCall({
    String? from,
    required String to,
    Map<dynamic, dynamic>? customData,
    VideoQuality? videoQuality,
  }) async {
    final client = _clientForOutgoingCall(to);
    if (client == null) return;
    final result =
        await StringeeCallManager.instance.handleOutgoingStringeeCall(
      call: StringeeCall(client),
      from: from ?? _stringeeClient!.userId!,
      to: to.trim(),
      isVideoCall: true,
      customData: customData,
      videoQuality: videoQuality,
    );
    _presentOutgoingCall(result);
  }

  /// Presents an outgoing voice call backed by [StringeeCall2].
  Future<void> makeVoiceCall2({
    String? from,
    required String to,
    Map<dynamic, dynamic>? customData,
  }) async {
    final client = _clientForOutgoingCall(to);
    if (client == null) return;
    final result =
        await StringeeCallManager.instance.handleOutgoingStringeeCall2(
      call: StringeeCall2(client),
      from: from ?? _stringeeClient!.userId!,
      to: to.trim(),
      isVideoCall: false,
      customData: customData,
    );
    _presentOutgoingCall(result);
  }

  /// Presents an outgoing video call backed by [StringeeCall2].
  Future<void> makeVideoCall2({
    String? from,
    required String to,
    Map<dynamic, dynamic>? customData,
    VideoQuality? videoQuality,
  }) async {
    final client = _clientForOutgoingCall(to);
    if (client == null) return;
    final result =
        await StringeeCallManager.instance.handleOutgoingStringeeCall2(
      call: StringeeCall2(client),
      from: from ?? _stringeeClient!.userId!,
      to: to.trim(),
      isVideoCall: true,
      customData: customData,
      videoQuality: videoQuality,
    );
    _presentOutgoingCall(result);
  }

  StringeeClient? _clientForOutgoingCall(String to) {
    if (_stringeeClient == null) {
      throw Exception('Wrapper is not initialized');
    }
    if (!connected) {
      debugPrint('Cannot make call while Stringee client is disconnected');
      return null;
    }
    if (to.trim().isEmpty) {
      debugPrint('Cannot make call with an empty callee id');
      return null;
    }
    return _stringeeClient;
  }

  void _presentOutgoingCall(Response<StringeeCallModel> result) {
    if (result.isSuccess) {
      _stringeeListener?.onPresentCallWidget.call(
        ChangeNotifierProvider(
          create: (_) => result.success!,
          child: _callWidget ?? const StringeeCallWidget(),
        ),
      );
    } else {
      debugPrint('Error: ${result.failure}');
    }
  }

  /// Registers [listener] as the application event sink.
  ///
  /// Registering another listener replaces the previous listener.
  Future<void> addListener(StringeeListener listener) async {
    _stringeeListener = listener;
  }

  /// Removes [listener] if it is the currently registered instance.
  void removeListener(StringeeListener listener) {
    if (identical(_stringeeListener, listener)) {
      _stringeeListener = null;
    }
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
        _incomingStringeeCall(call);
        break;
      case StringeeClientEvents.incomingCall2:
        StringeeCall2 call2 = event['body'];
        _incomingStringeeCall2(call2);
        break;
      default:
        break;
    }
  }

  Future<void> _incomingStringeeCall(StringeeCall call) async {
    debugPrint('Incoming StringeeCall');
    final result =
        await StringeeCallManager.instance.handleIncomingStringeeCall(call);
    await _presentIncomingCall(result, call.reject);
  }

  Future<void> _incomingStringeeCall2(StringeeCall2 call) async {
    debugPrint('Incoming StringeeCall2');
    final result =
        await StringeeCallManager.instance.handleIncomingStringeeCall2(call);
    await _presentIncomingCall(result, call.reject);
  }

  Future<void> _presentIncomingCall(
    Response<StringeeCallModel> result,
    Future<Map<dynamic, dynamic>> Function() reject,
  ) async {
    if (result.isSuccess) {
      _stringeeListener?.onPresentCallWidget.call(
        ChangeNotifierProvider(
          create: (_) => result.success,
          child: _callWidget ?? const StringeeCallWidget(),
        ),
      );
    } else {
      debugPrint('Error: ${result.failure}');
      if (result.failure == 'There is an active call') {
        await reject();
      }
      // TODO: - handle error if needed
    }
  }

  /// Alias for [connected] retained for existing sample integrations.
  bool get isConnected => _stringeeClient?.hasConnected ?? false;

  /// Requests camera, microphone, and supported Bluetooth permissions.
  Future<bool> requestCallPermissions() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    List<Permission> permissions = [Permission.camera, Permission.microphone];
    if (androidInfo.version.sdkInt >= 31) {
      permissions.add(Permission.bluetoothConnect);
    }
    return _requestPermission(permissions);
  }

  /// Requests notification permission on Android 13 or newer.
  Future<bool> requestNotificationPermissions() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      List<Permission> permissions = [Permission.notification];
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
