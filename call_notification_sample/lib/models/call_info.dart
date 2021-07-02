abstract class CallInfo {
  void onStatusChange(String status) {}
  void onReceiveLocalStream(){}
  void onReceiveRemoteStream(){}
  void onMuteState(bool isMute){}
  void onSpeakerState(bool isSpeakerOn){}
  void onVideoState(bool isVideoEnable){}
}
