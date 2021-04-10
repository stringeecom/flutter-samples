import 'sync_call.dart';
import 'package:flutter_call_kit/flutter_call_kit.dart';
import 'package:uuid/uuid.dart';
import 'call_screen.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'call_screen.dart';
import 'dart:io' show Platform;

class CallManager with WidgetsBindingObserver {
  static CallManager _instance;

  static CallManager get shared {
    if (_instance == null) {
      _instance = CallManager._internal();
    }

    return _instance;
  }

  // Cac bien xu ly pushkit + callkit
  SyncCall syncCall = null;
  List<String> _fakeCallUuids = new List(); // mảng các uuid của các call được show từ callkit mà cần end ngay sau khi show thành công (xử lý cho rule mới trên iOS 13)
  List<SyncCall> _oldSyncCalls = new List(); // mảng các syncCall đã xử lý rồi, sẽ không xử lý lại nữa (xử lý cho StringeeX)
  FlutterCallKit _callKit = FlutterCallKit();

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

  CallManager._internal() {
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
    if (state == AppLifecycleState.resumed && syncCall != null && syncCall.stringeeCall!= null) {
      showCallScreen(syncCall.stringeeCall, contextToShowCallScreen);
    }
  }

  /// Cac ham xu ly Callkit
  ///
  Future<void> configureCallkitLibrary() async {
    _callKit.configure(
      IOSOptions("Stringee",
          imageName: '',
          supportsVideo: false,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1),
      didReceiveStartCallAction: didReceiveStartCallAction,
      performAnswerCallAction: performAnswerCallAction,
      performEndCallAction: performEndCallAction,
      didActivateAudioSession: didActivateAudioSession,
      didDisplayIncomingCall: didDisplayIncomingCall,
      didPerformSetMutedCallAction: didPerformSetMutedCallAction,
      didPerformDTMFAction: didPerformDTMFAction,
      didToggleHoldAction: didToggleHoldAction,
    );
  }

  Future<void> didReceiveStartCallAction(String uuid, String handle) async {
    // Get this event after the system decides you can start a call
    // You can now start a call from within your app
  }

  Future<void> performAnswerCallAction(String uuid) async {
    // Called when the user answers an incoming call
    print("performAnswerCallAction");
    if (syncCall == null || syncCall.uuid.isEmpty || syncCall.uuid != uuid) {
      return;
    }
    syncCall.userAnswered = true;
    syncCall.answerIfConditionPassed();
  }

  Future<void> performEndCallAction(String uuid) async {
    print("performEndCallAction: " + uuid);
    /*
     Được gọi khi người dùng reject (ngắt ở màn hình cuộc gọi đến) hoặc hangup (ngắt ở màn hình cuộc gọi đang diễn ra) cuộc gọi từ màn hỉnh callkit
     => Cần kiểm tra điều kiện để biết nên gọi hàm reject hay hangup của StringeeCall object. 2 hàm này có ý nghĩa khác nhau.
     **/
    if (syncCall == null || syncCall.uuid.isEmpty || syncCall.uuid != uuid) {
      return;
    }

    syncCall.endedCallkit = true;
    syncCall.userRejected = true;

    if (syncCall.stringeeCall != null && syncCall.callState != StringeeSignalingState.busy && syncCall.callState != StringeeSignalingState.ended) {
      // Nếu StringeeCall đã được answer thì gọi hàm hangup() nếu chưa thì reject()
      if (syncCall.callAnswered) {
        syncCall.hangup();
      } else {
        syncCall.reject();
      }
    }

    deleteSyncCallIfNeed();
  }

  Future<void> didActivateAudioSession() async {
    // you might want to do following things when receiving this event:
    // - Start playing ringback if it is an outgoing call
    print("===== didActivateAudioSession, syncCall: " + syncCall.toString());
    if (syncCall == null) {
      return;
    }
    syncCall.audioSessionActived = true;
    syncCall.answerIfConditionPassed();
  }

  Future<void> didDisplayIncomingCall(String error, String uuid, String handle,
      String localizedCallerName, bool fromPushKit) async {
    // You will get this event after RNCallKeep finishes showing incoming call UI
    // You can check if there was an error while displaying
    print("didDisplayIncomingCall: " + uuid);
    endFakeCall(uuid);
    deleteSyncCallIfNeed();
  }

  Future<void> didPerformSetMutedCallAction(bool mute, String uuid) async {
    // Called when the system or user mutes a call
    if (syncCall == null) {
      return;
    }

    syncCall.mute(isMute: mute);
  }

  Future<void> didPerformDTMFAction(String digit, String uuid) async {
    // Called when the system or user performs a DTMF action
  }

  Future<void> didToggleHoldAction(bool hold, String uuid) async {
    // Called when the system or user holds a call
  }

  void handleIncomingPushNotification(Map<String, dynamic> payload) {
    print("handleIncomingPushNotification");
    String callId = payload["callId"];
    String callStatus = payload["callStatus"];
    String uuid = payload["uuid"];
    int serial = payload["serial"];

    // call khong hop le => can end o day
    if (callId.isEmpty || callStatus != "started") {
      _fakeCallUuids.add(uuid);
      endFakeCall(uuid);
      return;
    }

    // call da duoc xu ly roi thi ko xu ly lai => can end callkit da duoc show ben native
    if (checkIfCallIsHandledOrNot(callId, serial)) {
      _callKit.endCall(uuid);
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
      return;
    }

    // Đã có sync call nhưng là của cuộc gọi khác => end callkit này (callkit vừa được show bên native)
    if (!syncCall.isThisCall(callId, serial)) {
      print('END CALLKIT KHI NHAN DUOC PUSH, PUSH MOI KHONG PHAI SYNC CALL');
      _callKit.endCall(uuid);
      return;
    }

    // Đã có sync call, thông tin cuộc gọi là trùng khớp, nhưng đã show callkit rồi => end callkit vừa show
    if (syncCall.showedCallkit() && syncCall.uuid != uuid) {
      print('END CALLKIT KHI NHAN DUOC PUSH, SYNC CALL DA SHOW CALLKIT');
      _callKit.endCall(uuid);
    }
  }

  void handleIncomingCallEvent(StringeeCall call, BuildContext context) {
    print("handleIncomingCallEvent");

    // Chưa có sync call thì tạo mới
    if (syncCall == null) {
      print("handleIncomingCallEvent, syncCall: " + syncCall.toString());
      syncCall = SyncCall();
      syncCall.attachCall(call);
      syncCall.uuid = genUUID();

      // Show callkit
      _callKit.displayIncomingCall(syncCall.uuid, call.from, call.fromAlias);

      // Show callScreen
      showCallScreen(call, context);

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
      _callKit.displayIncomingCall(syncCall.uuid, call.from, call.fromAlias);
    } else {
      _callKit.updateDisplay(syncCall.uuid, call.from, call.fromAlias);
    }

    showCallScreen(call, context);

    call.initAnswer();
    syncCall.answerIfConditionPassed();
  }

  void handleIncomingCall2Event(StringeeCall2 call, BuildContext context) {}

  void showCallScreen(StringeeCall call, BuildContext context) {
    if (context == null) {
      return;
    }

    contextToShowCallScreen = context;

    // Listen events
    if (!syncCall.stringeeCall.eventStreamController.hasListener) {
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
          case StringeeCallEvents.didChangeAudioDevice:
            if (Platform.isAndroid) {
              handleChangeAudioDeviceEvent(
                  map['selectedAudioDevice'], syncCall.stringeeCall);
            }
            break;
          default:
            break;
        }
      });
    }


    if (appLifecycleState != AppLifecycleState.resumed || syncCall == null || syncCall.stringeeCall == null || callScreenKey != null) {
      return;
    }

    callScreenKey = GlobalKey<CallScreenState>();
    print("======== SHOW CALL SCREEN ========");
    CallScreen callScreen = CallScreen(key: callScreenKey, fromUserId: syncCall.stringeeCall.from, toUserId: syncCall.stringeeCall.to, isVideo: syncCall.stringeeCall.isVideoCall);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => callScreen),
    );
  }

  void showFakeCall() {
    /*
      Rule mới của Apple trên iOS 13 là bắt buộc show Callkit khi nhận được push từ Pushkit.
      Trong một số trường hợp call không hợp lệ lẽ ra không xử lý nhưng vẫn cần show callkit.
      => Phương án: show lên 1 call đến callkit show đó end call luôn.
      Note: Thực hiện end fake call trong callback 'didDisplayIncomingCall'
    **/
    String fakeCallUuid = genUUID();
    _callKit.displayIncomingCall(fakeCallUuid, "Stringee", "CallEnded");
    _fakeCallUuids.add(fakeCallUuid);
  }

  void endFakeCall(String uuid) {
    if (_fakeCallUuids.contains(uuid)) {
      _callKit.endCall(uuid);
      _fakeCallUuids.remove(uuid);
      print("End fake call voi uuid: " + uuid);
    }
  }

  void saveSyncCallToHandledCallList(SyncCall call) {
    _oldSyncCalls.removeWhere((element) => element.callId == call.callId && element.serial == call.serial);
    _oldSyncCalls.add(call);
  }

  void removeSyncCallFromHandledCallList(String callId, int serial) {
    _oldSyncCalls.removeWhere((element) => element.callId == callId && element.serial == serial);
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
      print("deleteSyncCallIfNeed failed, endedCallkit: " + syncCall.endedCallkit.toString() + " endedStringeeCall: " + syncCall.endedStringeeCall.toString());
    }
  }

  void endCallkit() {
    print("endCallkit: " + syncCall.uuid);
    _callKit.endAllCalls();
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
  }

  void handleReceiveLocalStreamEvent(String callId) {
    print('handleReceiveLocalStreamEvent - $callId');
    syncCall.hasLocalStream = true;
  }

  void handleReceiveRemoteStreamEvent(String callId) {
    print('handleReceiveRemoteStreamEvent - $callId');
    syncCall.hasRemoteStream = true;
  }

  void handleChangeAudioDeviceEvent(
      AudioDevice audioDevice, StringeeCall call) {
    print('handleChangeAudioDeviceEvent - $audioDevice');
    switch (audioDevice) {
      case AudioDevice.speakerPhone:
      case AudioDevice.earpiece:
        if (call != null) {
          call.setSpeakerphoneOn(CallManager.shared.syncCall.isSpeaker);
        }
        break;
      case AudioDevice.bluetooth:
      case AudioDevice.wiredHeadset:
        CallManager.shared.syncCall.isSpeaker = false;
        if (call != null) {
          call.setSpeakerphoneOn(CallManager.shared.syncCall.isSpeaker);
        }
        break;
      case AudioDevice.none:
        print('handleChangeAudioDeviceEvent - non audio devices connected');
        break;
    }
  }

  void clearDataEndDismiss() {
    print('clearDataEndDismiss');
    syncCall.stringeeCall.destroy();
    endCallkit();
    deleteSyncCallIfNeed();
    if (callScreenKey != null) {
      callScreenKey.currentState.dismiss();
      callScreenKey = null;
    }
  }

  /// Utils
  ///
  String genUUID() {
    return new Uuid().v4();
  }
}