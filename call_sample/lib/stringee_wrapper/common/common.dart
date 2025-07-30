import 'dart:io';

export 'response.dart';

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
