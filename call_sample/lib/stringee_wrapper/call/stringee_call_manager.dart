import 'dart:async';

import 'package:call_sample/stringee_wrapper/common/common.dart';
import 'package:call_sample/stringee_wrapper/stringee_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

import '../interfaces/stringee_call_interface.dart';
import '../push_manager/callkeep_manager.dart';
import '../push_manager/android_push_manager.dart';
import 'stringee_call_model.dart';

/// Owns the single-active-call policy and platform call transitions.
///
/// Incoming and outgoing `StringeeCall`/`StringeeCall2` instances are adapted
/// to [StringeeCallModel] so UI, CallKit, notifications, and cleanup use one
/// lifecycle implementation.
class StringeeCallManager {
  /// singleton instance
  static final StringeeCallManager _instance = StringeeCallManager._internal();

  /// private constructor
  ///
  /// initialize the call manager
  StringeeCallManager._internal();

  /// Returns the process-wide call manager.
  static StringeeCallManager get instance => _instance;

  /// Returns the process-wide call manager.
  factory StringeeCallManager() => _instance;

  /// list of calls
  final List<StringeeCallModel> _calls = [];

  /// Recently ended calls retained for late PushKit/CallKit reconciliation.
  final List<StringeeCallModel> endedCalls = [];

  /// Active call models. The sample permits at most one entry.
  List<StringeeCallModel> get calls => _calls;

  /// Finds an active call by its CallKit [uuid].
  StringeeCallModel? callWithUuid(String uuid) {
    try {
      return _calls.firstWhere((element) => element.uuid == uuid);
    } catch (e) {
      return null;
    }
  }

  /// Finds an active call by its Stringee [callId].
  StringeeCallModel? callWithCallId(String callId) {
    if (callId.isEmpty) return null;
    try {
      return _calls.firstWhere((element) => element.call.callId == callId);
    } catch (_) {
      return null;
    }
  }

  /// Initializes and presents an incoming first-generation [call].
  Future<Response<StringeeCallModel>> handleIncomingStringeeCall(
    StringeeCall call,
  ) {
    return _handleIncomingCall(StringeeCallWrapper(call));
  }

  /// Initializes and presents an incoming second-generation [call].
  Future<Response<StringeeCallModel>> handleIncomingStringeeCall2(
    StringeeCall2 call,
  ) {
    return _handleIncomingCall(StringeeCall2Wrapper(call));
  }

  Future<Response<StringeeCallModel>> _handleIncomingCall(
    StringeeCallInterface call,
  ) async {
    // check current call if needed
    if (_calls.isNotEmpty || await CallkeepManager().hasActiveCall()) {
      // do nothing if there is an active call
      return Response.failure('There is an active call');
    }

    // create a call model
    StringeeCallModel stringeeCallModel = StringeeCallModel(
      call,
      isIncomingCall: true,
    );

    if (isIOS) {
      // add the call to the list
      _calls.add(stringeeCallModel);
      // report incoming call if needed
      final callkeepResponse =
          await CallkeepManager().reportIncomingCallIfNeeded(stringeeCallModel);
      if (callkeepResponse.isFailure) {
        _calls.remove(stringeeCallModel);
        stringeeCallModel.release();
        return Response.failure(
          callkeepResponse.failure ?? 'Error while reporting incoming call',
        );
      }
      // iOS will call initAnswer when audio session is active
      return Response.success(stringeeCallModel);
    } else {
      final initializedCallResponse = await stringeeCallModel.call.initAnswer();
      if (initializedCallResponse['status'] == true) {
        _calls.add(stringeeCallModel);
        final shouldPresent = await AndroidPushManager().reconcileIncomingCall(
          stringeeCallModel,
        );
        if (!shouldPresent) {
          return Response.failure('Call rejected from notification');
        }
        return Response.success(stringeeCallModel);
      } else {
        stringeeCallModel.release();
        return Response.failure('Error while handle Incoming call');
      }
    }
  }

  /// Creates an outgoing first-generation call model.
  Future<Response<StringeeCallModel>> handleOutgoingStringeeCall({
    required StringeeCall call,
    required String from,
    required String to,
    required bool isVideoCall,
    Map<dynamic, dynamic>? customData,
    VideoQuality? videoQuality,
  }) {
    return _handleOutgoingCall(
      call: StringeeCallWrapper(call),
      from: from,
      to: to,
      isVideoCall: isVideoCall,
      customData: customData,
      videoQuality: videoQuality,
    );
  }

  /// Creates an outgoing second-generation call model.
  Future<Response<StringeeCallModel>> handleOutgoingStringeeCall2({
    required StringeeCall2 call,
    required String from,
    required String to,
    required bool isVideoCall,
    Map<dynamic, dynamic>? customData,
    VideoQuality? videoQuality,
  }) {
    return _handleOutgoingCall(
      call: StringeeCall2Wrapper(call),
      from: from,
      to: to,
      isVideoCall: isVideoCall,
      customData: customData,
      videoQuality: videoQuality,
    );
  }

  Future<Response<StringeeCallModel>> _handleOutgoingCall({
    required StringeeCallInterface call,
    required String from,
    required String to,
    required bool isVideoCall,
    Map<dynamic, dynamic>? customData,
    VideoQuality? videoQuality,
  }) async {
    // check current call if needed
    if (_calls.isNotEmpty || await CallkeepManager().hasActiveCall()) {
      // do nothing if there is an active call
      return Response.failure('There is an active call');
    }
    // create a call model
    StringeeCallModel stringeeCallModel = StringeeCallModel(
      call,
      isIncomingCall: false,
      from: from,
      to: to,
      isVideoCall: isVideoCall,
      customData: customData,
      videoQuality: videoQuality,
    );
    _calls.add(stringeeCallModel);
    return Response.success(stringeeCallModel);
  }

  /// Sends the outgoing SDK make-call request and starts platform audio state.
  Future<Response> makeCall(StringeeCallModel stringeeCallModel) async {
    Response response = await stringeeCallModel.makeCall();
    if (response.isSuccess) {
      await StringeeAudioManager().start();
      if (!isIOS) {
        await AndroidPushManager().startInCallService(stringeeCallModel);
      }
    } else {
      Fluttertoast.showToast(
        msg: response.failure ?? 'Error while making call',
        toastLength: Toast.LENGTH_SHORT,
      );
      StringeeWrapper().stringeeListener?.onDismissCallWidget.call(
            'Error while making call',
          );
      clear(stringeeCallModel, dismissCallWidget: false);
    }
    return response;
  }

  /// Answers [call] after platform-specific audio prerequisites are ready.
  ///
  /// On iOS this wait is bounded by [StringeeWrapper.callTimeout] and stops if
  /// the model is cleared before CallKit activates its audio session.
  Future<Response> answerStringeeCall(StringeeCallModel call) async {
    /// check if the call is incoming and the audio is active
    if (!call.isIncomingCall) {
      return Response.failure('Only incoming calls can be answered');
    }
    if (isIOS) {
      // CallKit activates the audio session asynchronously. Stop waiting when
      // the call is cleared so an ended call can never be answered later.
      final deadline = DateTime.now().add(
        Duration(seconds: StringeeWrapper().callTimeout),
      );
      while (DateTime.now().isBefore(deadline)) {
        if (!_calls.contains(call) ||
            call.callState == CallState.ended ||
            call.callState == CallState.busy) {
          return Response.failure('Call ended before audio became active');
        }
        debugPrint('Answer call with audio ${CallkeepManager().isActiveAudio}');
        if (CallkeepManager().isActiveAudio && StringeeWrapper().connected) {
          final initResponse = await call.call.initAnswer();
          if (initResponse['status'] != true) {
            return Response.failure(
              initResponse['message']?.toString() ??
                  'Error while initializing incoming call',
            );
          }
          final answerResponse = await call.call.answer();
          if (answerResponse['status'] != true) {
            return Response.failure(
              answerResponse['message']?.toString() ??
                  'Error while answering call',
            );
          }
          call.signalingState = StringeeSignalingState.answered;
          call.callState = CallState.starting;
          await StringeeAudioManager().start();
          return Response.success(answerResponse);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      return Response.failure('Timed out waiting for CallKit audio session');
    }

    final answerResponse = await call.call.answer();
    if (answerResponse['status'] == true) {
      call.signalingState = StringeeSignalingState.answered;
      call.callState = CallState.starting;
      await StringeeAudioManager().start();
      await AndroidPushManager().startInCallService(call);
      return Response.success(answerResponse);
    }
    return Response.failure(
      answerResponse['message']?.toString() ?? 'Error while answering call',
    );
  }

  /// Rejects or hangs up [call] according to its current signaling state.
  Future<void> endStringeeCall(StringeeCallModel call) async {
    try {
      if (call.callState != CallState.ended &&
          call.callState != CallState.busy) {
        if (call.isShouldReject) {
          await call.call.reject();
        } else {
          await call.call.hangup();
        }
      }
    } finally {
      clear(call);
    }
  }

  /// Removes [call] once and releases all associated resources.
  void clear(StringeeCallModel call, {bool dismissCallWidget = true}) {
    if (!_calls.remove(call)) {
      return;
    }
    call.release();
    if (!isIOS) {
      unawaited(
        AndroidPushManager().cleanupCall(callId: call.call.callId ?? ''),
      );
    }
    endedCalls.add(call);
    if (endedCalls.length > 20) {
      endedCalls.removeAt(0);
    }
    if (dismissCallWidget) {
      StringeeWrapper().stringeeListener?.onDismissCallWidget.call(
            'Call ended',
          );
    }
  }
}
