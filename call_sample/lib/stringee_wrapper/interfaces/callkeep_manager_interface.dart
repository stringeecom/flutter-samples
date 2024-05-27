import 'package:call_sample/stringee_wrapper/common/common.dart';

import '../call/stringee_call_model.dart';

abstract class CallkeepManagerInterface {
  Future<Result> reportOutgoingCallIfNeeded({
    required StringeeCallModel stringeeCallModel,
  });

  Future<Result> reportIncomingCallIfNeeded({
    required StringeeCallModel stringeeCallModel,
    bool fromPushKit = false,
  });

  Future<Result> answerCallIfNeeded(
      {required StringeeCallModel stringeeCallModel});

  Future<Result> reportEndCallIfNeeded(
      {required StringeeCallModel stringeeCallModel, int? reason});
}
