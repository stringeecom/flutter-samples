import 'dart:io';

export 'result.dart';

bool get isIOS => Platform.isIOS;

enum CallState {
  incoming,
  calling,
  ringing,
  starting,
  started,
  busy,
  ended,
}
