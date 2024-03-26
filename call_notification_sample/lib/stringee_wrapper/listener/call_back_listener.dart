class CallBackListener {
  void Function()? onSuccess;
  void Function(String message)? onError;

  CallBackListener({
    this.onSuccess,
    this.onError,
  });
}
