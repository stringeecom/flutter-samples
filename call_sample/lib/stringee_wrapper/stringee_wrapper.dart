import 'dart:async';

import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_call_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'common/common.dart';
import 'interfaces/stringee_wrapper_interface.dart';
import 'push_manager/callkeep_manager.dart';
import 'stringee_listener.dart';

export 'stringee_listener.dart';
export 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart'
    show VideoQuality;

class StringeeWrapper implements StringeeWrapperInterface {
  static final StringeeWrapper _instance = StringeeWrapper._internal();

  factory StringeeWrapper() {
    return _instance;
  }

  StringeeWrapper._internal() {
    _stringeeClient = StringeeClient();

    _stringeeClient.eventStreamController.stream.listen((event) {
      _handleStringeeEvent(event as Map<dynamic, dynamic>);
    });

    /// TODO: - configure callkeep for android
    /// move this to somewhere else to configure with more options like appName, icon, etc.
    if (isIOS) {
      CallkeepManager().configureCallKeep();
    }
  }

  late StringeeClient _stringeeClient;
  StringeeClient get stringeeClient => _stringeeClient;
  StringeeListener? _stringeeListener;

  StringeeListener? get stringeeListener => _stringeeListener;

  bool _isEnablePush = false;
  bool get isEnablePush => _isEnablePush;
  bool get connected => _stringeeClient.hasConnected;

  @override
  Future<void> connect(String token) async {
    _stringeeClient.connect(token);
  }

  @override
  Future<void> enablePush({bool? isProduction, bool? isVoip}) async {
    _isEnablePush = true;
    if (isIOS && CallkeepManager().pushToken.isNotEmpty) {
      _stringeeClient.registerPush(
        CallkeepManager().pushToken,
        isVoip: isVoip,
        isProduction: isProduction,
      );
    }
    // TODO: - handle push for android
  }

  @override
  Future<void> unregisterPush() async {
    _isEnablePush = false;
    if (isIOS && CallkeepManager().pushToken.isNotEmpty) {
      _stringeeClient.unregisterPush(CallkeepManager().pushToken);
    }
    // TODO: - handle push for android
  }

  @override
  Future<void> disconnect() async {
    _stringeeClient.disconnect();
  }

  @override
  Future<void> makeCall({
    required String from,
    required String to,
    bool isVideoCall = false,
    Map<dynamic, dynamic>? customData,
    VideoQuality? videoQuality,
  }) async {
    StringeeCall? call;
    StringeeCall2? call2;
    if (isVideoCall) {
      call2 = StringeeCall2(_stringeeClient);
    } else {
      call = StringeeCall(_stringeeClient);
    }
    final result = await StringeeCallManager.instance.handleOutgoingCall(
      call: call,
      call2: call2,
      from: from,
      to: to,
    );
    if (result.isSuccess) {
      _stringeeListener?.onPresentCallWidget.call(ChangeNotifierProvider(
        create: (_) => result.success,
        child: const StringeeCallWidget(),
      ));
    } else {
      debugPrint('Error: ${result.failure}');
    }
  }

  @override
  Future<void> addListener(StringeeListener listener) async {
    _stringeeListener = listener;
  }

  _handleStringeeEvent(Map<dynamic, dynamic> event) async {
    switch (event['eventType']) {
      case StringeeClientEvents.didConnect:
        debugPrint('StringeeClientEvents.didConnect ${event['body']}');
        _stringeeListener?.onConnected.call();
        break;
      case StringeeClientEvents.didDisconnect:
        debugPrint('StringeeClientEvents.didDisconnect ${event['body']}');
        _stringeeListener?.onDisConnected.call();
        break;
      case StringeeClientEvents.didFailWithError:
        int code = event['body']['code'];
        String msg = event['body']['message'];
        debugPrint('StringeeClientEvents.didFailWithError $code $msg');
        _stringeeListener?.onConnectError.call(code, msg);
        break;
      case StringeeClientEvents.requestAccessToken:
        debugPrint('StringeeClientEvents.requestAccessToken ${event['body']}');
        _stringeeListener?.onRequestNewToken.call();
        break;
      case StringeeClientEvents.didReceiveCustomMessage:
        debugPrint(
            'StringeeClientEvents.didReceiveCustomMessage ${event['body']}');
        // TODO: handle custom message later
        // _stringeeListener?.onReceiveCustomMessage.call();
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

  _incomingCall(StringeeCall? call, StringeeCall2? call2) async {
    final result = await StringeeCallManager.instance
        .handleIncomingCall(call: call, call2: call2);
    if (result.isSuccess) {
      _stringeeListener?.onPresentCallWidget.call(ChangeNotifierProvider(
        create: (_) => result.success,
        child: const StringeeCallWidget(),
      ));
    } else {
      debugPrint('Error: ${result.failure}');
      // TODO: - handle error if needed
    }
  }
}
