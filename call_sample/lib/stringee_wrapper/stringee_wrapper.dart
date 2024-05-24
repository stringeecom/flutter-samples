import 'dart:async';

import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_call_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'interfaces/stringee_wrapper_interface.dart';
import 'listener/stringee_listener.dart';

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
  }

  late StringeeClient _stringeeClient;
  StringeeListener? _stringeeListener;

  @override
  Future<void> connect(String token) async {
    _stringeeClient.connect(token);
  }

  @override
  Future<void> enablePush() {
    // TODO: implement enablePush
    throw UnimplementedError();
  }

  @override
  Future<void> unregisterPush() {
    // TODO: implement unregisterPush
    throw UnimplementedError();
  }

  @override
  Future<void> disconnect() {
    // TODO: implement disconnect
    throw UnimplementedError();
  }

  @override
  Future<void> makeCall(
      {required String from,
      required String to,
      bool isVideoCall = false}) async {
    StringeeCall? call;
    StringeeCall2? call2;
    if (isVideoCall) {
      call2 = StringeeCall2(_stringeeClient);
    } else {
      call = StringeeCall(_stringeeClient);
    }
    StringeeCallManager.instance.handleOutgoingCall(
      call: call,
      call2: call2,
      from: from,
      to: to,
    );
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
        final result =
            await StringeeCallManager.instance.handleIncomingCall(call: call);
        if (result.isSucess) {
          // TODO: - pass result to call widget if needed
          StringeeCallWidget callWidget = const StringeeCallWidget();
          _stringeeListener?.onPresentCallWidget.call(callWidget);
        } else {
          debugPrint('Error: ${result.failure}');
          // TODO: - handle error if needed
        }
        break;
      case StringeeClientEvents.incomingCall2:
        StringeeCall2 call2 = event['body'];
        final result =
            await StringeeCallManager.instance.handleIncomingCall(call2: call2);
        if (result.isSucess) {
          // TODO: - pass result to call widget if needed
          StringeeCallWidget callWidget = const StringeeCallWidget();
          _stringeeListener?.onPresentCallWidget.call(callWidget);
        } else {
          debugPrint('Error: ${result.failure}');
          // TODO: - handle error if needed
        }
        break;
      default:
        break;
    }
  }
}
