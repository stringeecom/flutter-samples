import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../listener/connection_listener.dart';
import 'call_manager.dart';

class ClientManager {
  ClientManager._privateConstructor();

  static ClientManager? _instance;

  factory ClientManager() {
    _instance ??= ClientManager._privateConstructor();
    return _instance!;
  }

  bool isInCall = false;
  String token =
      'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZULTE3MDYwMDM1NjUzMDEiLCJpc3MiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZUIiwidXNlcklkIjoidXNlcjIiLCJleHAiOjE3Mzc1Mzk1NjV9.iPDwwG74XabcmVGZhoEAzWP8WmaebBoJj6blKGy8uEA';
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

  void release() {
    debugPrint('release clientManager');
    ClientManager().isInCall = false;
    if (_stringeeClient != null) {
      _stringeeClient!.destroy();
    }
    ClientManager._instance = null;
  }
}
