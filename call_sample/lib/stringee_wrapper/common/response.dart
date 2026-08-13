/// Result container that carries either a success value or a failure message.
class Response<T> {
  /// The successful value, or `null` when the operation failed.
  final T? success;

  /// The failure message, or `null` when the operation succeeded.
  final String? failure;

  /// Creates a response from explicit success or failure values.
  Response({this.success, this.failure});

  /// Creates a successful response containing [value].
  factory Response.success(T value) {
    return Response(success: value);
  }

  /// Creates a failed response containing [message].
  factory Response.failure(String message) {
    return Response(failure: message);
  }

  /// Whether this response contains a success value.
  bool get isSuccess => success != null;

  /// Whether this response contains a failure message.
  bool get isFailure => failure != null;
}
