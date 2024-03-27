import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../common/common.dart';
import '../listener/call_back_listener.dart';
import '../listener/stringee_listener.dart';
import '../push_manager/android_push_manager.dart';
import '../push_manager/callkeep_manager.dart';
import '../widget/call_widget.dart';
import 'call_wrapper.dart';

export '../common/common.dart';
export '../listener/call_back_listener.dart';
export '../listener/call_listener.dart';
export '../listener/stringee_listener.dart';
export '../push_manager/android_push_manager.dart';
export '../push_manager/callkeep_manager.dart';
export '../widget/call_widget.dart';
export 'call_wrapper.dart';

class StringeeWrapper {
  StringeeWrapper._privateConstructor() {
    if (Platform.isIOS) {
      CallkeepManager.shared?.configureCallKeep();
    }
  }

  static StringeeWrapper? _instance;

  factory StringeeWrapper() {
    _instance ??= StringeeWrapper._privateConstructor();
    return _instance!;
  }

  StringeeListener? _listener;
  StringeeClient? _stringeeClient;
  String? token;
  bool _isPermissionGranted = false;

  StringeeClient? get stringeeClient => _stringeeClient;

  StringeeListener? get listener => _listener;
  CallWidget? callWidget;

  void connect(String token) {
    _stringeeClient ??= StringeeClient();
    _stringeeClient!.registerEvent(StringeeClientListener(
      onConnect: (userId) {
        debugPrint('onConnect: $userId');
        if (_listener != null) {
          _listener!.onConnected(userId);
        }
      },
      onDisconnect: () {
        debugPrint('onDisconnect');
        if (_listener != null) {
          _listener!.onDisconnected();
        }
      },
      onFailWithError: (code, message) {
        debugPrint('onFailWithError: code - $code - message - $message');
        if (_listener != null) {
          _listener!.onConnectError(code, message);
        }
      },
      onRequestAccessToken: () {
        debugPrint('onRequestAccessToken');
        if (_listener != null) {
          _listener!.onRequestNewToken();
        }
      },
      onReceiveCustomMessage: (from, message) {
        debugPrint('onReceiveCustomMessage: from - $from - message - $message');
      },
      onIncomingCall: (stringeeCall) async {
        debugPrint('onIncomingCall: callId - ${stringeeCall.id}');
        if (isInCall) {
          stringeeCall.reject();
          return;
        }
        isInCall = true;
        CallWrapper().initAnswer(
            new CallBackListener(
              onSuccess: () {
                debugPrint('initAnswer onSuccess');
                handleShowCallWidget();
              },
              onError: (message) {
                debugPrint('initAnswer onError: $message');
              },
            ),
            stringeeCall: stringeeCall);
      },
      onIncomingCall2: (stringeeCall2) async {
        debugPrint('onIncomingCall2: callId - ${stringeeCall2.id}');
        if (isInCall) {
          stringeeCall2.reject();
          return;
        }
        isInCall = true;
        CallWrapper().initAnswer(
            new CallBackListener(
              onSuccess: () {
                debugPrint('initAnswer onSuccess');
                handleShowCallWidget();
              },
              onError: (message) {
                debugPrint('initAnswer onError: $message');
              },
            ),
            stringeeCall2: stringeeCall2);
      },
    ));
    if (!_stringeeClient!.hasConnected) {
      _stringeeClient!.connect(token);
    }
  }

  void handleShowCallWidget() {
    if (isIOS) {
      if (_listener != null &&
          !CallWrapper().isCallNotInitialized() &&
          callWidget == null) {
        callWidget = new CallWidget();
        _listener!.onNeedShowCallWidget(callWidget!);
      }
    } else {
      StringeeWrapper().requestPermissions().then((value) {
        if (value) {
          // if (CallWrapper().isCallNotInitialized()) {
          //   if (_listener != null) {
          //     _listener!.onNeedDismissCallWidget('Call not initialized');
          //   }
          //   return;
          // }
          if (AndroidPushManager().isRejectFromPush) {
            CallWrapper().endCall(false);
            AndroidPushManager().isRejectFromPush = false;
          } else if (AndroidPushManager().isAnswerFromPush) {
            CallWrapper().answer();
            AndroidPushManager().isAnswerFromPush = false;
            if (_listener != null &&
                !CallWrapper().isCallNotInitialized() &&
                callWidget == null) {
              callWidget = new CallWidget();
              _listener!.onNeedShowCallWidget(callWidget!);
            }
          } else {
            if (_listener != null &&
                !CallWrapper().isCallNotInitialized() &&
                callWidget == null) {
              callWidget = new CallWidget();
              _listener!.onNeedShowCallWidget(callWidget!);
            }
          }
        } else {
          CallWrapper().endCall(false);
        }
      });
    }
  }

  Future<bool> requestPermissions() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    List<Permission> permissions = [
      Permission.camera,
      Permission.microphone,
    ];
    if (androidInfo.version.sdkInt >= 31) {
      permissions.add(Permission.bluetoothConnect);
    }
    if (androidInfo.version.sdkInt >= 33) {
      permissions.add(Permission.notification);
    }

    Map<Permission, PermissionStatus> permissionsStatus =
        await permissions.request();
    debugPrint('Permission statuses - $permissionsStatus');
    bool isAllGranted = true;
    permissionsStatus.forEach((key, value) {
      if (value != PermissionStatus.granted) {
        isAllGranted = false;
      }
    });
    if (isAllGranted) {
      _isPermissionGranted = true;
    }
    return isAllGranted;
  }

  bool hasConnected() {
    if (_stringeeClient == null) {
      return false;
    } else {
      return _stringeeClient!.hasConnected;
    }
  }

  void registerEvent(StringeeListener listener) {
    _listener = listener;
  }

  void registerPush(
    String token, {
    bool? isProduction,
    bool? isVoip,
    CallBackListener? callBackListener,
  }) {
    if (stringeeClient == null) {
      return;
    }
    this.token = token;
    stringeeClient!
        .registerPush(token, isVoip: isVoip, isProduction: isProduction)
        .then((value) {
      debugPrint('registerPush: ${value['message']}');
      if (callBackListener != null) {
        if (value['status']) {
          if (callBackListener.onSuccess != null) {
            callBackListener.onSuccess!();
          }
        } else {
          if (callBackListener.onError != null) {
            callBackListener.onError!(value['message']);
          }
        }
      }
    });
  }

  void unregisterPush({CallBackListener? callBackListener}) async {
    if (!isStringEmpty(this.token) && stringeeClient == null) {
      stringeeClient!.unregisterPush(this.token!).then((value) {
        debugPrint('unregisterPush: ${value['message']}');
        if (callBackListener != null) {
          if (value['status']) {
            if (callBackListener.onSuccess != null) {
              callBackListener.onSuccess!();
            }
          } else {
            if (callBackListener.onError != null) {
              callBackListener.onError!(value['message']);
            }
          }
        }
      });
    }
  }

  void makeCall(String from, String to, bool isVideoCall,
      CallBackListener callBackListener) {
    if (!_isPermissionGranted && !isIOS) {
      if (callBackListener.onError != null) {
        callBackListener.onError!('Permission not granted');
      }
      return;
    }

    if (_stringeeClient == null) {
      if (callBackListener.onError != null) {
        callBackListener.onError!('StringeeClient is null');
      }
      return;
    }
    CallWrapper().makeCall(
        from,
        to,
        isVideoCall,
        new CallBackListener(
          onSuccess: () {
            if (callBackListener.onSuccess != null) {
              callBackListener.onSuccess!();
            }
            debugPrint('makeCall onSuccess');
            if (_listener != null && callWidget == null) {
              callWidget = new CallWidget();
              _listener!.onNeedShowCallWidget(callWidget!);
            }
          },
          onError: (message) {
            if (callBackListener.onError != null) {
              callBackListener.onError!(message);
            }
          },
        ));
  }

  void release() {
    debugPrint('release stringee');
    isInCall = false;
    if (_stringeeClient != null) {
      _stringeeClient!.destroy();
    }
    _instance = null;
  }
}
