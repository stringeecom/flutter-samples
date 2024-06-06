import 'dart:async';

import 'package:call_sample/stringee_wrapper/common/common.dart';
import 'package:call_sample/stringee_wrapper/stringee_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../interfaces/stringee_call_interface.dart';
import '../push_manager/callkeep_manager.dart';
import 'stringee_call_model.dart';

class StringeeCallManager {
  /// singleton instance
  static final StringeeCallManager _instance = StringeeCallManager._internal();

  /// private constructor
  ///
  /// initialize the call manager
  StringeeCallManager._internal();

  /// get the singleton instance
  static StringeeCallManager get instance => _instance;

  factory StringeeCallManager() => _instance;

  /// list of calls
  final List<StringeeCallModel> _calls = [];

  List<StringeeCallModel> get calls => _calls;

  StringeeCallModel? callWithUuid(String uuid) {
    try {
      return _calls.firstWhere(
        (element) => element.uuid == uuid,
      );
    } catch (e) {
      return null;
    }
  }

  /// handle incoming call from stringee
  /// [call] is the incoming call
  /// [call2] is the incoming call for stringee 2
  /// if call and call2 are both null, return a failure result
  Future<Result<StringeeCallModel>> handleIncomingCall({
    StringeeCall? call,
    StringeeCall2? call2,
  }) async {
    if (call == null && call2 == null) {
      return Result.failure('Call cannot be null');
    }
    // create a call model
    StringeeCallModel stringeeCallModel = StringeeCallModel(
      call != null ? StringeeCallWrapper(call) : StringeeCall2Wrapper(call2!),
      isIncomingCall: true,
    );

    // check current call if needed
    if ((!isIOS && _calls.isNotEmpty) ||
        await CallkeepManager().hasActiveCall()) {
      // do nothing if there is an active call
      return Result.failure('There is an active call');
    }

    final initializedCallResult = await stringeeCallModel.call.initAnswer();
    if (initializedCallResult['status']) {
      _calls.add(stringeeCallModel);
      if (isIOS) {
        // add the call to the list
        CallkeepManager().reportIncomingCallIfNeeded(stringeeCallModel);
      }
      return Result.success(stringeeCallModel);
    } else {
      return Result.failure('Error while handle Incoming call');
    }
  }

  /// handle outgoing call from stringee
  /// [from] is the caller
  /// [to] is the callee
  Future<Result<StringeeCallModel>> handleOutgoingCall({
    required String from,
    required String to,
    StringeeCall? call,
    StringeeCall2? call2,
    Map<dynamic, dynamic>? customData,
    VideoQuality? videoQuality,
  }) async {
    if (call == null && call2 == null) {
      return Result.failure('Call cannot be null');
    }
    // create a call model
    StringeeCallModel stringeeCallModel = StringeeCallModel(
      call != null ? StringeeCallWrapper(call) : StringeeCall2Wrapper(call2!),
      isIncomingCall: false,
      from: from,
      to: to,
      customData: customData,
      videoQuality: videoQuality,
    );
    _calls.add(stringeeCallModel);
    return Result.success(stringeeCallModel);
  }

  Future<Result> makeCall(StringeeCallModel stringeeCallModel) async {
    Result result = await stringeeCallModel.makeCall();
    if (result.isSuccess) {
      await stringeeCallModel.call
          .setSpeakerphoneOn(stringeeCallModel.isVideoCall);
    }
    return result;
  }

  Future<void> answerStringeeCall(StringeeCallModel call) async {
    /// check if the call is incoming and the audio is active
    if (call.isIncomingCall) {
      if (isIOS) {
        // in iOS, we need to check if the audio is active
        // if the audio is active, we can answer the call
        Timer.periodic(const Duration(milliseconds: 100), (timer) {
          debugPrint(
              'Answer call with audio ${CallkeepManager().isActiveAudio}');
          if (CallkeepManager().isActiveAudio) {
            timer.cancel();
            call.signalingState = StringeeSignalingState.answered;
            call.call.answer();
            call.call.setSpeakerphoneOn(call.isVideoCall);
          }
        });
        return;
      }

      call.signalingState = StringeeSignalingState.answered;
      call.callState = CallState.starting;
      await call.call.answer();
      await call.call.setSpeakerphoneOn(call.isVideoCall);
    }
  }

  Future<void> endStringeeCall(StringeeCallModel call) async {
    if (call.isShouldReject) {
      await call.call.reject();
    } else {
      await call.call.hangup();
    }
    _calls.remove(call);

    StringeeWrapper().stringeeListener?.onDismissCallWidget.call('Call ended');
  }
}
