class CallBackListener {
  void Function({dynamic result})? onSuccess;
  void Function(String message)? onError;

  CallBackListener({
    this.onSuccess,
    this.onError,
  });
}
