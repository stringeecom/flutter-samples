class Result<T> {
  final T? success;
  final String? failure;

  Result({this.success, this.failure});

  factory Result.success(T value) {
    return Result(success: value);
  }

  factory Result.failure(String message) {
    return Result(failure: message);
  }

  bool get isSucess => success != null;
  bool get isFailure => failure != null;
}
