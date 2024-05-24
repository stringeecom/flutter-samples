enum CallStatus {
  calling,
  ringing,
  answered,
  busy,
  ended,
  hold,
}

extension CallStatusX on CallStatus {
  bool get isCalling => this == CallStatus.calling;
  bool get isRinging => this == CallStatus.ringing;
  bool get isAnswered => this == CallStatus.answered;
  bool get isBusy => this == CallStatus.busy;
  bool get isEnded => this == CallStatus.ended;
  bool get isHold => this == CallStatus.hold;
}
