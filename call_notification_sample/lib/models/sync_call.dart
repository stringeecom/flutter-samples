// /*
//     Ý tưởng:
//     Trên iOS 13, luồng nhận cuộc gọi onIncomingCall event từ Stringee SDK và luồng nhận push từ apple sẽ là bất đồng bộ.
//     Để apply theo rule mới của apple, sử dụng class này để map giữa push và call
//     Một thời điểm sẽ chỉ có 1 cuộc gọi được xử lý, các cuộc khác đến khi đang có cuộc gọi thì sẽ reject.
//
//     Đối tượng này sẽ wrap 1 StringeeCall object và lưu 1 số trạng thái của cuộc gọi
// **/
//
// import 'package:ios_call_notification_sample/managers/ios_call_manager.dart';
// import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';
//
// class SyncCall {
//   StringeeCall? stringeeCall;
//   StringeeCall2? stringeeCall2;
//
//   int? serial = 1;
//   String? callId = '';
//   String? uuid = ''; // uuid da su dung de show callkit
//   StringeeSignalingState? callState =
//       StringeeSignalingState.calling; // trang thai cua StringeeCall
//
//   bool userRejected = false;
//   bool userAnswered =
//       false; // Người dùng đã click và nút answer ở màn hình incoming call của callkit hoặc của app
//   bool callAnswered =
//       false; // StringeeCall đã được answer (đã gọi hàm answer của StringeeCall object)
//   bool audioSessionActived =
//       false; // AudioSession của iOS đã được active thì khi answer call của Stringee mới kết nối thoại được
//
//   bool endedCallkit = false;
//   bool endedStringeeCall = false;
//
//   bool isMute = false;
//   bool isSpeaker = false;
//   bool videoEnabled = false;
//   bool hasLocalStream = false;
//   bool hasRemoteStream = false;
//   var _status = '';
//   bool mediaFirstTimeConnected =
//       false; // Thêm biến này để check nếu là lần đầu media connected thì nếu là cuộc gọi video sẽ cho audio ra loa ngoài
//
//   set status(value) {
//     _status = value;
//     updateUI();
//   }
//
//   get status => _status;
//
//   bool showedCallkit() {
//     return uuid!.isNotEmpty;
//   }
//
//   bool isThisCall(String? callId, int? serial) {
//     return this.callId == callId && this.serial == serial;
//   }
//
//   bool ended() {
//     bool callkitEndStatus = false;
//     if (uuid!.isEmpty) {
//       callkitEndStatus = true;
//     } else {
//       callkitEndStatus = endedCallkit;
//     }
//
//     return callkitEndStatus && endedStringeeCall;
//   }
//
//   void attachCall(StringeeCall call) {
//     stringeeCall = call;
//     serial = call.serial;
//     callId = call.id;
//     videoEnabled = call.isVideoCall;
//   }
//
//   void attachCall2(StringeeCall2 call) {
//     stringeeCall2 = call;
//     serial = call.serial;
//     callId = call.id;
//     videoEnabled = call.isVideoCall;
//   }
//
//   void answerCallkitCall() {
//     /*
//     * Hàm này thực hiện answer cuộc gọi đã show sử dụng CallKeep
//     * Sau khi thành công sẽ nhận được sự kiện CallKeepPerformAnswerCallAction của CallKeep
//     * **/
//     if (uuid == null || uuid!.isEmpty) {
//       return;
//     }
//
//     IOSCallManager.shared!.callKeep.answerIncomingCall(uuid!);
//   }
//
//   void answerIfConditionPassed() {
//     /*
//       Voi iOS, Answer StringeeCall khi thoa man cac yeu to:
//       1. Da nhan duoc su kien incomingCall (có StringeeCall object) hoac incomingCall2 (co StringeeCall2 object)
//       2. User da click answer
//       3. Chua goi ham answer cua StringeeCall lan nao
//       4. AudioSession da active
//     **/
//     if (!userAnswered ||
//         callAnswered ||
//         !audioSessionActived ||
//         (stringeeCall == null && stringeeCall2 == null)) {
//       print(
//           'answerIfConditionPassed, condition has not been passed, userAnswered: ' +
//               userAnswered.toString() +
//               ", callAnswered: " +
//               callAnswered.toString() +
//               ", audioSessionActived: " +
//               audioSessionActived.toString());
//       return;
//     }
//
//     // Cập nhật giao diện từ incomingCall ==> calling
//     if (IOSCallManager.shared!.callScreenKey != null &&
//         IOSCallManager.shared!.callScreenKey!.currentState != null) {
//       IOSCallManager.shared!.callScreenKey!.currentState!.changeToCallingUI();
//     }
//
//     if (stringeeCall != null) {
//       stringeeCall!.answer().then((result) {
//         String message = result['message'];
//         bool status = result['status'];
//         print("answer: " + message);
//         callAnswered = true;
//         if (!status) {
//           endCallIfNeed();
//         }
//       });
//     } else if (stringeeCall2 != null) {
//       stringeeCall2!.answer().then((result) {
//         String message = result['message'];
//         bool status = result['status'];
//         print("answer: " + message);
//         callAnswered = true;
//         if (!status) {
//           endCallIfNeed();
//         }
//       });
//     }
//   }
//
//   Future<bool?> reject() async {
//     if (stringeeCall == null && stringeeCall2 == null) {
//       print("SyncCall reject failed, call: " +
//           stringeeCall.toString() +
//           ", call2: " +
//           stringeeCall2.toString());
//       return false;
//     }
//
//     bool? status;
//
//     if (stringeeCall != null) {
//       await stringeeCall!.reject().then((result) {
//         String message = result['message'];
//         status = result['status'];
//         print("SyncCall reject, message: " + message);
//         endCallIfNeed();
//       });
//     } else {
//       await stringeeCall2!.reject().then((result) {
//         String message = result['message'];
//         status = result['status'];
//         print("SyncCall reject, message: " + message);
//         endCallIfNeed();
//       });
//     }
//
//     return status;
//   }
//
//   Future<bool?> hangup() async {
//     if (stringeeCall == null && stringeeCall2 == null) {
//       print("SyncCall hangup failed, call: " +
//           stringeeCall.toString() +
//           ", call2: " +
//           stringeeCall2.toString());
//       return false;
//     }
//
//     bool? status;
//
//     if (stringeeCall != null) {
//       await stringeeCall!.hangup().then((result) {
//         String message = result['message'];
//         status = result['status'];
//         print("SyncCall hangup, message: " +
//             message +
//             ", status: " +
//             status.toString());
//         endCallIfNeed();
//       });
//     } else {
//       await stringeeCall2!.hangup().then((result) {
//         String message = result['message'];
//         status = result['status'];
//         print("SyncCall hangup, message: " +
//             message +
//             ", status: " +
//             status.toString());
//         endCallIfNeed();
//       });
//     }
//
//     return status;
//   }
//
//   void mute({bool? isMute}) {
//     if (stringeeCall == null && stringeeCall2 == null) {
//       print("SyncCall mute failed, call: " +
//           stringeeCall.toString() +
//           ", call2: " +
//           stringeeCall2.toString());
//       return;
//     }
//
//     if (isMute != null) {
//       this.isMute = isMute;
//     } else {
//       this.isMute = !this.isMute;
//     }
//
//     if (stringeeCall != null) {
//       stringeeCall!.mute(this.isMute);
//     } else {
//       stringeeCall2!.mute(this.isMute);
//     }
//     updateUI();
//   }
//
//   Future<bool> setSpeakerphoneOn() async {
//     if (stringeeCall == null && stringeeCall2 == null) {
//       print("SyncCall setSpeakerphoneOn failed, call: " +
//           stringeeCall.toString() +
//           ", call2: " +
//           stringeeCall2.toString());
//       return false;
//     }
//
//     isSpeaker = !isSpeaker;
//     if (stringeeCall != null) {
//       await stringeeCall!.setSpeakerphoneOn(isSpeaker);
//     } else {
//       await stringeeCall2!.setSpeakerphoneOn(isSpeaker);
//     }
//     updateUI();
//     return true;
//   }
//
//   void switchCamera() {
//     if (stringeeCall == null && stringeeCall2 == null) {
//       print("SyncCall switchCamera failed, call: " +
//           stringeeCall.toString() +
//           ", call2: " +
//           stringeeCall2.toString());
//       return;
//     }
//
//     if (stringeeCall != null) {
//       stringeeCall!.switchCamera();
//     } else {
//       stringeeCall2!.switchCamera();
//     }
//   }
//
//   Future<bool> enableVideo() async {
//     if (stringeeCall == null && stringeeCall2 == null) {
//       print("SyncCall enableVideo failed, call: " +
//           stringeeCall.toString() +
//           ", call2: " +
//           stringeeCall2.toString());
//       return false;
//     }
//
//     videoEnabled = !videoEnabled;
//     if (stringeeCall != null) {
//       await stringeeCall!.enableVideo(videoEnabled);
//     } else {
//       await stringeeCall2!.enableVideo(videoEnabled);
//     }
//     updateUI();
//     return true;
//   }
//
//   void routeAudioToSpeakerIfNeed() {
//     if (mediaFirstTimeConnected) {
//       return;
//     }
//
//     if ((stringeeCall != null && stringeeCall!.isVideoCall) ||
//         (stringeeCall2 != null && stringeeCall2!.isVideoCall)) {
//       mediaFirstTimeConnected = true;
//       isSpeaker = false;
//       setSpeakerphoneOn();
//     }
//   }
//
//   void endCallIfNeed() {
//     IOSCallManager.shared!.clearDataEndDismiss();
//   }
//
//   void updateUI() {
//     if (IOSCallManager.shared!.callScreenKey != null &&
//         IOSCallManager.shared!.callScreenKey!.currentState != null) {
//       IOSCallManager.shared!.callScreenKey!.currentState!.setState(() {});
//     }
//   }
//
//   /// Thêm các hàm xử lý chung cho StringeeCall và StringeeCall2 của Stringee
//   ///
//   bool hasStringeeCall() {
//     return stringeeCall != null || stringeeCall2 != null;
//   }
//
//   bool isVideoCall() {
//     if (stringeeCall != null) {
//       return stringeeCall!.isVideoCall;
//     } else if (stringeeCall2 != null) {
//       return stringeeCall2!.isVideoCall;
//     }
//
//     return false;
//   }
//
//   String? from() {
//     if (stringeeCall != null) {
//       return stringeeCall!.from;
//     } else if (stringeeCall2 != null) {
//       return stringeeCall2!.from;
//     }
//     return "";
//   }
//
//   String? to() {
//     if (stringeeCall != null) {
//       return stringeeCall!.to;
//     } else if (stringeeCall2 != null) {
//       return stringeeCall2!.to;
//     }
//     return "";
//   }
//
//   void destroy() {
//     if (stringeeCall != null) {
//       return stringeeCall!.destroy();
//     } else if (stringeeCall2 != null) {
//       stringeeCall2!.destroy();
//     }
//   }
// }
