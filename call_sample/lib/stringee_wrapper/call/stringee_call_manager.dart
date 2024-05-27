import 'package:call_sample/stringee_wrapper/common/common.dart';
import 'package:call_sample/stringee_wrapper/stringee_wrapper.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../interfaces/interfaces.dart';
import '../push_manager/callkeep_manager.dart';
import 'stringee_call_model.dart';

class StringeeCallManager implements StringeeCallManagerInterface {
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

  StringeeCallModel? callWithUuid(String uuid) {
    try {
      return _calls.firstWhere(
        (element) => element.uuid == uuid,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<Result<StringeeCallModel>> handleIncomingCall({
    StringeeCall? call,
    StringeeCall2? call2,
  }) async {
    if (call == null && call2 == null) {
      return Result.failure('Call cannot be null');
    }
    // create a call model
    StringeeCallModel stringeeCallModel;
    if (call != null) {
      stringeeCallModel = StringeeCallModel(
        StringeeCallWrapper(call),
        isIncomingCall: true,
      );
    } else {
      stringeeCallModel = StringeeCallModel(
        StringeeCall2Wrapper(call2!),
        isIncomingCall: true,
      );
    }

    // TODO: - handle current call if needed

    final initializedCallResult = await stringeeCallModel.call.initAnswer();

    if (initializedCallResult['status']) {
      // add the call to the list
      _calls.add(stringeeCallModel);
      if (isIOS) {
        CallkeepManager()
            .reportIncomingCallIfNeeded(stringeeCallModel: stringeeCallModel);
      } else {
        // TODO: - handle incoming call for android
      }
      return Result.success(stringeeCallModel);
    } else {
      return Result.failure('Error while handle Incoming call');
    }
  }

  @override
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
    await stringeeCallModel.makeCall();
    return Result.success(stringeeCallModel);
  }

  Future<void> answerStringeeCall(StringeeCallModel call) async {
    if (call.isIncomingCall) {
      await call.call.answer();
    }
  }

  Future<void> endStringeeCall(StringeeCallModel call) async {
    if (call.isIncomingCall &&
        call.mediaState == StringeeMediaState.disconnected) {
      await call.call.reject();
    } else {
      await call.call.hangup();
    }
    _calls.remove(call);

    // TODO: - dismiss the call screen or handle next call if needed
    StringeeWrapper().stringeeListener?.onDismissCallWidget.call('Call ended');
  }
}
