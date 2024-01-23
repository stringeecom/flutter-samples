class ConnectionListener {
  void Function(String status) onConnect;
  void Function() onIncomingCall;
  void Function() onIncomingCall2;

  ConnectionListener(
      {required this.onConnect,
      required this.onIncomingCall,
      required this.onIncomingCall2});
}
