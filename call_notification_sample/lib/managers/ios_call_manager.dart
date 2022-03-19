import 'dart:async';
import 'package:flutter/material.dart';

import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';
import 'dart:io' show Platform;

import 'package:uuid/uuid.dart';
import 'package:callkeep/callkeep.dart';

import 'package:ios_call_notification_sample/screens/call_screen.dart';
import '../models/sync_call.dart';
import 'instance_manager.dart' as InstanceManager;

class IOSCallManager with WidgetsBindingObserver {
  static IOSCallManager _instance;

  static IOSCallManager get shared {
    if (_instance == null) {
      _instance = IOSCallManager._internal();
    }

    return _instance;
  }

  // Cac bien xu ly pushkit + callkit
  SyncCall syncCall = null;
  List<String> _fakeCallUuids = new List(); // mảng các uuid của các call được show từ callkit mà cần end ngay sau khi show thành công (xử lý cho rule mới trên iOS 13)
  List<SyncCall> _oldSyncCalls = new List(); // mảng các syncCall đã xử lý rồi, sẽ không xử lý lại nữa (xử lý cho StringeeX)
  final FlutterCallkeep callKeep = FlutterCallkeep();
  String pushToken = "";
  bool registeredPushWithStringeeServer = false;
  /*
    Thư viện Flutter bên iOS đang có mỗi lỗi liên quan đến render. Một số link tham khảo:
    https://github.com/flutter/flutter/issues/50732
    https://github.com/flutter/flutter/issues/33236
    Việc này dẫn đến khi có cuộc gọi đến và app ở trạng thái background hoặc tắt thì sẽ không thể hiển thị giao diện của màn incomingCall, Calling.
    Từ đó không thể quản lý StringeeCall trong CallScreen (call_screen.dart).
    => cần tracking trạng thái của call và cập nhật giao diện khi người dùng mở app nếu cần.
   **/
  GlobalKey<CallScreenState> callScreenKey = null; // Tham chiếu đến CallScreen để có thể cập nhật giao diện khi cần
  AppLifecycleState appLifecycleState = AppLifecycleState.resumed;
  BuildContext contextToShowCallScreen = null;
  Timer _incomingCallTimeoutTimer;

  IOSCallManager._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  void destroy() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // TODO: implement didChangeAppLifecycleState
    super.didChangeAppLifecycleState(state);
    print('didChangeAppLifecycleState = $state');
    appLifecycleState = state;
    if (state == AppLifecycleState.resumed && syncCall != null && syncCall.hasStringeeCall() && !syncCall.ended()) {
      showCallScreen(contextToShowCallScreen);
    }
  }

  /// Cac ham xu ly Callkit
  ///
  Future<void> configureCallKeep() async {
    callKeep.on(CallKeepPushKitToken(), onPushKitToken);
    callKeep.on(CallKeepDidDisplayIncomingCall(), didDisplayIncomingCall);
    callKeep.on(CallKeepPushKitReceivedNotification(), didReceivePushNotification);
    callKeep.on(CallKeepPerformAnswerCallAction(), answerCall);
    callKeep.on(CallKeepPerformEndCallAction(), endCall);
    callKeep.on(CallKeepDidPerformSetMutedCallAction(), didPerformSetMutedCallAction);
    callKeep.on(CallKeepDidActivateAudioSession(), didActivateAudioSession);

    callKeep.setup(<String, dynamic>{
      'ios': {
        'appName': 'Stringee',
      },
      'android': {
        'alertTitle': 'Permissions required',
        'alertDescription':
            'This application needs to access your phone accounts',
        'cancelButton': 'Cancel',
        'okButton': 'ok',
      },
    });
  }

  void registerPushWithStringeeServer() {
    if (registeredPushWithStringeeServer) {
      return;
    }

    if (pushToken == null || pushToken.isEmpty) {
      print('Push token khong hop le');
      return;
    }

    InstanceManager.client
        .registerPush(pushToken, isProduction: false)
        .then((result) {
      bool status = result['status'];
      String message = result['message'];
      print('Result for resgister push: ' + message);
      if (status) {
        registeredPushWithStringeeServer = true;
      }
    });
  }

  void handleIncomingCallEvent(StringeeCall call, BuildContext context) {
    print("handleIncomingCallEvent, callId: " + call.id);

    // Chưa có sync call thì tạo mới
    if (syncCall == null) {
      syncCall = SyncCall();
      syncCall.attachCall(call);
      syncCall.uuid = genUUID();

      // Show callkit
      callKeep.displayIncomingCall(syncCall.uuid, call.from, localizedCallerName: call.fromAlias);

      // Show callScreen
      showCallScreen(context);

      call.initAnswer().then((result) {
        String message = result['message'];
        print("initAnswer: " + message);
      });
      syncCall.answerIfConditionPassed();

      return;
    }

    // Cuộc gọi mới không phải là cuộc gọi đang xử lý thì reject
    if (!syncCall.isThisCall(call.id, call.serial)) {
      print("Cuộc gọi mới không phải là cuộc gọi đang xử lý thì reject");
      call.reject();
      return;
    }

    // Người dùng đã click reject cuộc gọi thì reject
    if (syncCall.userRejected) {
      print("Người dùng đã click reject cuộc gọi thì reject");
      call.reject();
      return;
    }

    // Chưa show callkit thì show không thì update thông tin người gọi lên giao diện
    syncCall.attachCall(call);
    if (syncCall.uuid.isEmpty) {
      syncCall.uuid = genUUID();
      callKeep.displayIncomingCall(syncCall.uuid, call.from, localizedCallerName: call.fromAlias);
    } else {
      callKeep.updateDisplay(syncCall.uuid, displayName: call.fromAlias, handle: call.from);
    }

    showCallScreen(context);

    call.initAnswer();
    syncCall.answerIfConditionPassed();
  }

  void handleIncomingCall2Event(StringeeCall2 call, BuildContext context) {
    print("handleIncomingCall2Event, callId: " + call.id);

    // Chưa có sync call thì tạo mới
    if (syncCall == null) {
      syncCall = SyncCall();
      syncCall.attachCall2(call);
      syncCall.uuid = genUUID();

      // Show callkit
      callKeep.displayIncomingCall(syncCall.uuid, call.from, localizedCallerName: call.fromAlias);

      // Show callScreen
      showCallScreen(context);

      call.initAnswer().then((result) {
        String message = result['message'];
        print("initAnswer: " + message);
      });
      syncCall.answerIfConditionPassed();

      return;
    }

    // Cuộc gọi mới không phải là cuộc gọi đang xử lý thì reject
    if (!syncCall.isThisCall(call.id, call.serial)) {
      print("Cuộc gọi mới không phải là cuộc gọi đang xử lý thì reject");
      call.reject();
      return;
    }

    // Người dùng đã click reject cuộc gọi thì reject
    if (syncCall.userRejected) {
      print("Người dùng đã click reject cuộc gọi thì reject");
      call.reject();
      return;
    }

    // Chưa show callkit thì show không thì update thông tin người gọi lên giao diện
    syncCall.attachCall2(call);
    if (syncCall.uuid.isEmpty) {
      syncCall.uuid = genUUID();
      callKeep.displayIncomingCall(syncCall.uuid, call.from, localizedCallerName: call.fromAlias);
    } else {
      callKeep.updateDisplay(syncCall.uuid, displayName: call.fromAlias, handle: call.from);
    }

    showCallScreen(context);

    call.initAnswer();
    syncCall.answerIfConditionPassed();
  }

  void showCallScreen(BuildContext context) {
    if (context == null) {
      return;
    }

    contextToShowCallScreen = context;

    // Listen events
    addListenerForCall();

    if (appLifecycleState != AppLifecycleState.resumed || syncCall == null || !syncCall.hasStringeeCall() || callScreenKey != null) {
      return;
    }

    callScreenKey = GlobalKey<CallScreenState>();
    CallScreen callScreen = CallScreen(
        key: callScreenKey,
        fromUserId: syncCall.to(),
        toUserId: syncCall.from(),
        isVideo: syncCall.isVideoCall());
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => callScreen),
    );
  }

  void addListenerForCall() {
    // StringeeCall
    if (syncCall.stringeeCall != null && !syncCall.stringeeCall.eventStreamController.hasListener) {
      syncCall.stringeeCall.eventStreamController.stream.listen((event) {
        Map<dynamic, dynamic> map = event;
        switch (map['eventType']) {
          case StringeeCallEvents.didChangeSignalingState:
            handleSignalingStateChangeEvent(map['body']);
            break;
          case StringeeCallEvents.didChangeMediaState:
            handleMediaStateChangeEvent(map['body']);
            break;
          case StringeeCallEvents.didReceiveCallInfo:
            handleReceiveCallInfoEvent(map['body']);
            break;
          case StringeeCallEvents.didHandleOnAnotherDevice:
            handleHandleOnAnotherDeviceEvent(map['body']);
            break;
          case StringeeCallEvents.didReceiveLocalStream:
            handleReceiveLocalStreamEvent(map['body']);
            break;
          case StringeeCallEvents.didReceiveRemoteStream:
            handleReceiveRemoteStreamEvent(map['body']);
            break;
          default:
            break;
        }
      });
    }

    // StringeeCall2
    if (syncCall.stringeeCall2 != null && !syncCall.stringeeCall2.eventStreamController.hasListener) {
      syncCall.stringeeCall2.eventStreamController.stream.listen((event) {
        Map<dynamic, dynamic> map = event;
        switch (map['eventType']) {
          case StringeeCall2Events.didChangeSignalingState:
            handleSignalingStateChangeEvent(map['body']);
            break;
          case StringeeCall2Events.didChangeMediaState:
            handleMediaStateChangeEvent(map['body']);
            break;
          case StringeeCall2Events.didReceiveCallInfo:
            handleReceiveCallInfoEvent(map['body']);
            break;
          case StringeeCall2Events.didHandleOnAnotherDevice:
            handleHandleOnAnotherDeviceEvent(map['body']);
            break;
          case StringeeCall2Events.didReceiveLocalStream:
            handleReceiveLocalStreamEvent(map['body']);
            break;
          case StringeeCall2Events.didReceiveRemoteStream:
            handleReceiveRemoteStreamEvent(map['body']);
            break;
          default:
            break;
        }
      });
    }
  }

  void showFakeCall() {
    /*
      Rule mới của Apple trên iOS 13 là bắt buộc show Callkit khi nhận được push từ Pushkit.
      Trong một số trường hợp call không hợp lệ lẽ ra không xử lý nhưng vẫn cần show callkit.
      => Phương án: show lên 1 call đến callkit show đó end call luôn.
      Note: Thực hiện end fake call trong callback 'didDisplayIncomingCall'
    **/
    String fakeCallUuid = genUUID();
    callKeep.displayIncomingCall(fakeCallUuid, "Stringee", localizedCallerName: "Call Ended");
    _fakeCallUuids.add(fakeCallUuid);
  }

  void endFakeCall(String uuid) {
    if (_fakeCallUuids.contains(uuid)) {
      callKeep.endCall(uuid);
      _fakeCallUuids.remove(uuid);
      print("End fake call voi uuid: " + uuid);
    }
  }

  void saveSyncCallToHandledCallList(SyncCall call) {
    _oldSyncCalls.removeWhere((element) =>
        element.callId == call.callId && element.serial == call.serial);
    _oldSyncCalls.add(call);
  }

  void removeSyncCallFromHandledCallList(String callId, int serial) {
    _oldSyncCalls.removeWhere(
        (element) => element.callId == callId && element.serial == serial);
  }

  bool checkIfCallIsHandledOrNot(String callId, int serial) {
    for (SyncCall loopCall in _oldSyncCalls) {
      if (loopCall.callId == callId && loopCall.serial == serial) {
        return true;
      }
    }

    return false;
  }

  void deleteSyncCallIfNeed() {
    if (syncCall == null) {
      print("SyncCall is deleted");
      return;
    }

    if (syncCall.ended()) {
      saveSyncCallToHandledCallList(syncCall);
      syncCall = null;
    } else {
      print("deleteSyncCallIfNeed failed, endedCallkit: " +
          syncCall.endedCallkit.toString() +
          " endedStringeeCall: " +
          syncCall.endedStringeeCall.toString());
    }
  }

  void endCallkit() {
    callKeep.endAllCalls();
  }

  /// Handle event for call

  void handleSignalingStateChangeEvent(StringeeSignalingState state) {
    print('handleSignalingStateChangeEvent - $state');
    syncCall.callState = state;
    switch (state) {
      case StringeeSignalingState.calling:
        syncCall.status = state.toString().split('.')[1];
        break;
      case StringeeSignalingState.ringing:
        syncCall.status = state.toString().split('.')[1];
        break;
      case StringeeSignalingState.answered:
        syncCall.status = state.toString().split('.')[1];
        break;
      case StringeeSignalingState.busy:
        syncCall.endedStringeeCall = true;
        clearDataEndDismiss();
        break;
      case StringeeSignalingState.ended:
        syncCall.endedStringeeCall = true;
        clearDataEndDismiss();
        break;
      default:
        break;
    }
  }

  void handleMediaStateChangeEvent(StringeeMediaState state) {
    print('handleMediaStateChangeEvent - $state');
    syncCall.status = state.toString().split('.')[1];
    switch (state) {
      case StringeeMediaState.connected:
        syncCall.routeAudioToSpeakerIfNeed();
        break;
      case StringeeMediaState.disconnected:
        break;
      default:
        break;
    }
  }

  void handleReceiveCallInfoEvent(Map<dynamic, dynamic> info) {
    print('handleReceiveCallInfoEvent - $info');
  }

  void handleHandleOnAnotherDeviceEvent(StringeeSignalingState state) {
    print('handleHandleOnAnotherDeviceEvent - $state');
    if (state == StringeeSignalingState.answered || state == StringeeSignalingState.busy || state == StringeeSignalingState.ended) {
      syncCall.endedStringeeCall = true;
      clearDataEndDismiss();
    }
  }

  void handleReceiveLocalStreamEvent(String callId) {
    print('handleReceiveLocalStreamEvent - $callId');
    syncCall.hasLocalStream = true;
  }

  void handleReceiveRemoteStreamEvent(String callId) {
    print('handleReceiveRemoteStreamEvent - $callId');
    syncCall.hasRemoteStream = true;
  }

  void clearDataEndDismiss() {
    print('clearDataEndDismiss');
    if (syncCall != null) {
      syncCall.destroy();
    }
    endCallkit();
    deleteSyncCallIfNeed();
    if (callScreenKey != null && callScreenKey.currentState != null) {
      callScreenKey.currentState.dismiss();
      callScreenKey = null;
    }
  }

  /*
      Handle cho truong hop A goi B, nhung A end call rat nhanh, B nhan duoc push nhung khong nhan duoc incoming call
      ==> Sau khi ket noi den Stringee server 3s ma chua nhan duoc cuoc goi den thi xoa Callkit Call va syncCall
    **/
  void startTimeoutForIncomingCall() {
    if (_incomingCallTimeoutTimer != null || syncCall == null) {
      return;
    }

    Timer(Duration(seconds: 3), () {
      if (syncCall == null) {
        return;
      }

      if (!syncCall.hasStringeeCall()) {
        syncCall.endedStringeeCall = true;
        callKeep.endAllCalls();
        saveSyncCallToHandledCallList(syncCall);
        syncCall = null;
      }
    });
  }

  void stopTimeoutForIncomingCall() {
    if (_incomingCallTimeoutTimer != null) {
      _incomingCallTimeoutTimer.cancel();
      _incomingCallTimeoutTimer = null;
    }
  }

  /// CallKeep
  ///

  void onPushKitToken(CallKeepPushKitToken event) {
    // Nhận được token của Apple => Register với StringeeServer
    print('[onPushKitToken] token => ${event.token}');
    pushToken = event.token;
    registerPushWithStringeeServer();
  }

  Future<void> didReceivePushNotification(CallKeepPushKitReceivedNotification event) async {
    print('CallKeepPushKitReceivedNotification, callId: ${event.callId}, callStatus: ${event.callStatus}, uuid: ${event.uuid}, serial: ${event.serial},');
    String callId = event.callId;
    String callStatus = event.callStatus;
    String uuid = event.uuid;
    int serial = event.serial;

    // call khong hop le => can end o day
    if (callId.isEmpty || callStatus != "started") {
      _fakeCallUuids.add(uuid);
      endFakeCall(uuid);
      return;
    }

    // call da duoc xu ly roi thi ko xu ly lai => can end callkit da duoc show ben native
    if (checkIfCallIsHandledOrNot(callId, serial)) {
      // _callKit.endCall(uuid);
      callKeep.endCall(uuid);
      removeSyncCallFromHandledCallList(callId, serial);
      deleteSyncCallIfNeed();
      return;
    }

    // Chưa có sync call (Trường hợp cuộc gọi mới) => tạo sync call và lưu lại thông tin
    if (syncCall == null) {
      print("handleIncomingPushNotification, syncCall: " + syncCall.toString());
      syncCall = new SyncCall();
      syncCall.callId = callId;
      syncCall.serial = serial;
      syncCall.uuid = uuid;
      IOSCallManager.shared.startTimeoutForIncomingCall();
      return;
    }

    // Đã có sync call nhưng là của cuộc gọi khác => end callkit này (callkit vừa được show bên native)
    if (!syncCall.isThisCall(callId, serial)) {
      print('END CALLKIT KHI NHAN DUOC PUSH, PUSH MOI KHONG PHAI SYNC CALL');
      // _callKit.endCall(uuid);
      callKeep.endCall(uuid);
      return;
    }

    // Đã có sync call, thông tin cuộc gọi là trùng khớp, nhưng đã show callkit rồi => end callkit vừa show
    if (syncCall.showedCallkit() && syncCall.uuid != uuid) {
      print('END CALLKIT KHI NHAN DUOC PUSH, SYNC CALL DA SHOW CALLKIT');
      // _callKit.endCall(uuid);
      callKeep.endCall(uuid);
    }
  }

  void didDisplayIncomingCall(CallKeepDidDisplayIncomingCall event) {
    print("didDisplayIncomingCall, callId: ${event.callId}, uuid: ${event.uuid}, serial: ${event.serial}");
    endFakeCall(event.uuid);
    deleteSyncCallIfNeed();
  }

  Future<void> answerCall(CallKeepPerformAnswerCallAction event) async {
    // Called when the user answers an incoming call
    print("performAnswerCallAction, uuid: ${event.callUUID}");
    if (syncCall == null || syncCall.uuid.isEmpty || syncCall.uuid != event.callUUID) {
      return;
    }
    syncCall.userAnswered = true;
    syncCall.answerIfConditionPassed();
  }

  Future<void> endCall(CallKeepPerformEndCallAction event) async {
    print("performEndCallAction, uuid: ${event.callUUID} ");
    /*
       Được gọi khi người dùng reject (ngắt ở màn hình cuộc gọi đến) hoặc hangup (ngắt ở màn hình cuộc gọi đang diễn ra) cuộc gọi từ màn hỉnh callkit
       => Cần kiểm tra điều kiện để biết nên gọi hàm reject hay hangup của StringeeCall object. 2 hàm này có ý nghĩa khác nhau.
       **/
    if (syncCall == null || syncCall.uuid.isEmpty || syncCall.uuid != event.callUUID) {
      return;
    }

    syncCall.endedCallkit = true;
    syncCall.userRejected = true;

    if (syncCall.hasStringeeCall() && syncCall.callState != StringeeSignalingState.busy && syncCall.callState != StringeeSignalingState.ended) {
      // Nếu StringeeCall đã được answer thì gọi hàm hangup() nếu chưa thì reject()
      if (syncCall.callAnswered) {
        syncCall.hangup();
      } else {
        syncCall.reject();
      }
    }

    deleteSyncCallIfNeed();
  }

  Future<void> didPerformSetMutedCallAction(CallKeepDidPerformSetMutedCallAction event) async {
    // Called when the system or user mutes a call
    if (syncCall == null) {
      return;
    }

    syncCall.mute(isMute: event.muted);
  }

  void didActivateAudioSession(CallKeepDidActivateAudioSession event) {
    print("didActivateAudioSession, syncCall: " + syncCall.toString());
    if (syncCall == null) {
      return;
    }
    syncCall.audioSessionActived = true;
    syncCall.answerIfConditionPassed();
  }

  /// Utils
  ///
  String genUUID() {
    return new Uuid().v4();
  }
}
