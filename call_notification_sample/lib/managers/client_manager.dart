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
    if (Platform.isIOS) {
      CallkeepManager.shared?.configureCallKeep();
    }
  }

  static ClientManager? _instance;

  factory ClientManager() {
    _instance ??= ClientManager._privateConstructor();
    return _instance!;
  }

  bool isInCall = false;
  //String token = 'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZULTE3MTA5MTczNDgiLCJpc3MiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZUIiwiZXhwIjoxNzEzNTA5MzQ4LCJ1c2VySWQiOiJpb3MyIn0.OVEH7acsrGJk_NJ_WKfdJVp3ZNFbaGm88WXT5fDpP08';
  String token = 'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZULTE3MTA5MTcyOTgiLCJpc3MiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZUIiwiZXhwIjoxNzEzNTA5Mjk4LCJ1c2VySWQiOiJpb3MxIn0.8gF7myCvT85CByIxExFNrcbs-DqrGUvt4gbBTEj5-Fc';
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
            (value) => { debugPrint( 'Register push $token --- ${value.toString()}')});
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
