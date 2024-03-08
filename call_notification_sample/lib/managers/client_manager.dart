import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:ios_call_notification_sample/managers/callkeep_manager.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../listener/connection_listener.dart';
import 'call_manager.dart';

class ClientManager {
  ClientManager._privateConstructor() {
    CallkeepManager.shared?.configureCallKeep();
  }

  static ClientManager? _instance;

  factory ClientManager() {
    _instance ??= ClientManager._privateConstructor();
    return _instance!;
  }

  bool isInCall = false;
  //String token = 'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZULTE3MDk4ODMwMDAiLCJpc3MiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZUIiwiZXhwIjoxNzEyNDc1MDAwLCJ1c2VySWQiOiIyMjIyMiJ9.naDJAmExQf2hu_ArjfQcC1uEYpq1Z4fysGzne3M5gPk';
  String token = 'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZULTE3MDk2MTQ1MjciLCJpc3MiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZUIiwiZXhwIjoxNzEyMjA2NTI3LCJ1c2VySWQiOiIxMTExMSJ9.m9rPHB9dFcd7RCr3k7qtQls-rwfxZMj7Bap0_kkKaUI';
  bool isAppInBackground = false;
  ConnectionListener? _listener;
  StringeeClient? _stringeeClient;
  CallManager? callManager;

  StringeeClient? get stringeeClient => _stringeeClient;

  void connect() {
    _stringeeClient ??= StringeeClient();
    _stringeeClient!.registerEvent(StringeeClientListener(
      onConnect: (userId) {
        debugPrint('onConnect: $userId');
        if (_listener != null) {
          _listener!.onConnect('Connected as $userId');
        }
        if (Platform.isIOS) {
          registerCallPush(CallkeepManager.shared?.pushToken ?? '');
        }
        if (Platform.isAndroid) {
          ///Register push with firebase token
          FirebaseMessaging.instance.getToken().then((token) {
            stringeeClient!.registerPush(token!).then((value) {
              debugPrint('Register push ${value['message']}');
            });
          });
        }
      },
      onDisconnect: () {
        debugPrint('onDisconnect');
        if (_listener != null) {
          _listener!.onConnect('Disconnected');
        }
      },
      onFailWithError: (code, message) {
        debugPrint('onFailWithError: code - $code - message - $message');
        if (_listener != null) {
          _listener!.onConnect('Connect fail: $message');
        }
      },
      onRequestAccessToken: () {
        debugPrint('onRequestAccessToken');
      },
      onReceiveCustomMessage: (from, message) {
        debugPrint('onReceiveCustomMessage: from - $from - message - $message');
      },
      onIncomingCall: (stringeeCall) {
        debugPrint('onIncomingCall: callId - ${stringeeCall.id}');
        if (isInCall) {
          stringeeCall.reject();
          return;
        }
        callManager = CallManager();
        CallManager().initializedIncomingCall(true, stringeeCall: stringeeCall);
        CallManager().initAnswer();
        if (_listener != null) {
          _listener!.onIncomingCall();
        }
      },
      onIncomingCall2: (stringeeCall2) {
        debugPrint('onIncomingCall2: callId - ${stringeeCall2.id}');
        if (isInCall) {
          stringeeCall2.reject();
          return;
        }
        callManager = CallManager();
        CallManager()
            .initializedIncomingCall(false, stringeeCall2: stringeeCall2);
        CallManager().initAnswer();
        if (_listener != null) {
          _listener!.onIncomingCall2();
        }
      },
    ));
    if (!_stringeeClient!.hasConnected) {
      _stringeeClient!.connect(token);
    }
  }

  void registerEvent(ConnectionListener listener) {
    _listener = listener;
  }

  void registerCallPush(String token) {
    _stringeeClient?.registerPush(token, isVoip: true, isProduction: false).then(
            (value) => { debugPrint( 'Register push ${token} --- ${value.toString()}')});
  }

  void release() {
    debugPrint('release clientManager');
    ClientManager().isInCall = false;
    if (_stringeeClient != null) {
      _stringeeClient!.destroy();
    }
    ClientManager._instance = null;
  }
}
