import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../common/common.dart';

abstract class StringeeCallInterface {
  /// Handle incoming call
  /// required [call] or [call2]
  Future<Result> handleIncomingCall({StringeeCall? call, StringeeCall2? call2});

  /// Handle outgoing call
  Future<Result> handleOutgoingCall({
    required String from,
    required String to,
    StringeeCall? call,
    StringeeCall2? call2,
  });
}
