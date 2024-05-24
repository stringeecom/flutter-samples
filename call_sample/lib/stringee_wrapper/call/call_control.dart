class CallControl {
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoEnable = false;
  bool _isVideo = false;

  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;
  bool get isVideoEnable => _isVideoEnable;
  bool get isVideo => _isVideo;

  void setMute(bool isMuted) {
    _isMuted = isMuted;
  }

  void setSpeaker(bool isSpeaker) {
    _isSpeaker = isSpeaker;
  }

  void setVideoEnable(bool isVideoEnable) {
    _isVideoEnable = isVideoEnable;
  }

  void setVideo(bool isVideo) {
    _isVideo = isVideo;
  }
}
