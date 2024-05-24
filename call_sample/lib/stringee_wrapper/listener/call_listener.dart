import '../call/call_status.dart';

class CallListener {
  final Function(CallStatus status) onCallStatus;
  final Function() onReceiveLocalStream;
  final Function() onReceiveRemoteStream;
  final Function(bool isOn) onSpeakerChange;
  final Function(bool isMute) onMuteChange;
  final Function(bool isOn) onVideoChange;

  CallListener({
    required this.onCallStatus,
    required this.onReceiveLocalStream,
    required this.onReceiveRemoteStream,
    required this.onSpeakerChange,
    required this.onMuteChange,
    required this.onVideoChange,
  });
}
