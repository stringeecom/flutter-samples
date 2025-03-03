class Response<T> {
  final T? success;
  final String? failure;

  Response({this.success, this.failure});

  factory Response.success(T value) {
    return Response(success: value);
  }

  factory Response.failure(String message) {
    return Response(failure: message);
  }

  bool get isSuccess => success != null;

  bool get isFailure => failure != null;
}
