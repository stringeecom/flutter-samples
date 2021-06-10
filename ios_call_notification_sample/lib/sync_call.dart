/*
    Ý tưởng:
    Trên iOS 13, luồng nhận cuộc gọi onIncomingCall event từ Stringee SDK và luồng nhận push từ apple sẽ là bất đồng bộ.
    Để apply theo rule mới của apple, sử dụng class này để map giữa push và call
    Một thời điểm sẽ chỉ có 1 cuộc gọi được xử lý, các cuộc khác đến khi đang có cuộc gọi thì sẽ reject.

    Đối tượng này sẽ wrap 1 StringeeCall object và lưu 1 số trạng thái của cuộc gọi
**/

import 'package:ios_call_notification_sample/call_manager.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

class SyncCall {
  StringeeCall stringeeCall;

  int serial = 1;
  String callId = '';
  String uuid = ''; // uuid da su dung de show callkit
  StringeeSignalingState callState = StringeeSignalingState.calling; // trang thai cua StringeeCall

  bool userRejected = false;
  bool userAnswered = false; // Người dùng đã click và nút answer ở màn hình incoming call của callkit hoặc của app
  bool callAnswered = false; // StringeeCall đã được answer (đã gọi hàm answer của StringeeCall object)
  bool audioSessionActived = false; // AudioSession của iOS đã được active thì khi answer call của Stringee mới kết nối thoại được

  bool endedCallkit = false;
  bool endedStringeeCall = false;

  bool isMute = false;
  bool isSpeaker = false;
  bool videoEnabled = false;
  bool hasLocalStream = false;
  bool hasRemoteStream = false;
  var _status = '';

  set status(value) {
    _status = value;
    updateUI();
  }

  get status => _status;

  bool showedCallkit() {
    return !uuid.isEmpty;
  }

  bool isThisCall(String callId, int serial) {
    return this.callId == callId && this.serial == serial;
  }

  bool ended() {
    bool callkitEndStatus = false;
    if (uuid.isEmpty) {
      callkitEndStatus = true;
    } else {
      callkitEndStatus = endedCallkit;
    }

    return callkitEndStatus && endedStringeeCall;
  }

  void attachCall(StringeeCall call) {
    stringeeCall = call;
    serial = call.serial;
    callId = call.id;
    videoEnabled = call.isVideoCall;
  }

  void answerIfConditionPassed() {
    /*
      Voi iOS, Answer StringeeCall khi thoa man cac yeu to:
      1. Da nhan duoc su kien incomingCall (có StringeeCall object)
      2. User da click answer
      3. Chua goi ham answer cua StringeeCall lan nao
      4. AudioSession da active
    **/
    if (stringeeCall == null ||
        !userAnswered ||
        callAnswered ||
        !audioSessionActived) {
      print(
          'answerIfConditionPassed, condition has not been passed, stringeeCall: ' +
              stringeeCall.toString() +
              ", userAnswered: " +
              userAnswered.toString() +
              ", callAnswered: " +
              callAnswered.toString() +
              ", audioSessionActived: " +
              audioSessionActived.toString());
      return;
    }

    // Cập nhật giao diện từ incomingCall ==> calling
    if (CallManager.shared.callScreenKey != null && CallManager.shared.callScreenKey.currentState != null) {
      CallManager.shared.callScreenKey.currentState.changeToCallingUI();
    }

    stringeeCall.answer().then((result) {
      String message = result['message'];
      bool status = result['status'];
      print("answer: " + message);
      callAnswered = true;
      if (!status) {
        endCallIfNeed();
      }
    });
  }

  Future<bool> reject() async {
    if (stringeeCall == null) {
      print("SyncCall reject failed, stringeeCall: " + stringeeCall.toString());
      return false;
    }

    bool status;
    await stringeeCall.reject().then((result) {
      String message = result['message'];
      status = result['status'];
      print("SyncCall reject, message: " + message);
      endCallIfNeed();
    });
    return status;
  }

  Future<bool> hangup() async {
    if (stringeeCall == null) {
      print("SyncCall hangup failed, stringeeCall: " + stringeeCall.toString());
      return false;
    }

    bool status;
    await stringeeCall.hangup().then((result) {
      String message = result['message'];
      status = result['status'];
      print("SyncCall hangup, message: " + message + ", status: " + status.toString());
      endCallIfNeed();
    });
    return status;
  }

  void mute({bool isMute}) {
    if (stringeeCall == null) {
      print("SyncCall mute failed, stringeeCall: " + stringeeCall.toString());
      return;
    }

    if (isMute != null) {
      this.isMute = isMute;
    } else {
      this.isMute = !this.isMute;
    }
    stringeeCall.mute(this.isMute);
    updateUI();
  }

  Future<bool> setSpeakerphoneOn() async {
    if (stringeeCall == null) {
      print("SyncCall setSpeakerphoneOn failed, stringeeCall: " + stringeeCall.toString());
      return false;
    }

    isSpeaker = !isSpeaker;
    await stringeeCall.setSpeakerphoneOn(isSpeaker);
    updateUI();
    return true;
  }

  void switchCamera() {
    if (stringeeCall == null) {
      print("SyncCall switchCamera failed, stringeeCall: " + stringeeCall.toString());
      return;
    }

    stringeeCall.switchCamera();
  }

  Future<bool> enableVideo() async {
    if (stringeeCall == null) {
      print("SyncCall enableVideo failed, stringeeCall: " + stringeeCall.toString());
      return false;
    }

    videoEnabled = !videoEnabled;
    await stringeeCall.enableVideo(videoEnabled);
    updateUI();
    return true;
  }

  void endCallIfNeed() {
    CallManager.shared.clearDataEndDismiss();
  }

  void updateUI() {
    if (CallManager.shared.callScreenKey != null && CallManager.shared.callScreenKey.currentState != null) {
      CallManager.shared.callScreenKey.currentState.setState(() {});
    }
  }
}
