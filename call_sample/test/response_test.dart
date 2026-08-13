import 'package:call_sample/stringee_wrapper/common/response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Response exposes mutually exclusive success and failure values', () {
    final success = Response<int>.success(42);
    final failure = Response<int>.failure('failed');

    expect(success.success, 42);
    expect(success.failure, isNull);
    expect(success.isSuccess, isTrue);
    expect(success.isFailure, isFalse);
    expect(failure.success, isNull);
    expect(failure.failure, 'failed');
    expect(failure.isSuccess, isFalse);
    expect(failure.isFailure, isTrue);
  });
}
