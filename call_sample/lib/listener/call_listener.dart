enum CallStatus {
  incoming,
  calling,
  ringing,
  starting,
  started,
  busy,
  ended,
}

class CallListener {
  void Function(CallStatus status) onCallStatus;
  void Function(String message) onError;
  void Function() onReceiveLocalStream;
  void Function() onReceiveRemoteStream;
  void Function(bool isOn) onSpeakerChange;
  void Function(bool isOn) onMicChange;
  void Function(bool isOn) onVideoChange;

  CallListener({
    required this.onCallStatus,
    required this.onError,
    required this.onReceiveLocalStream,
    required this.onReceiveRemoteStream,
    required this.onSpeakerChange,
    required this.onMicChange,
    required this.onVideoChange,
  });
}
