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
  StringeeCallManager._internal() {
    _callkeepManager = CallkeepManager();
  }

  /// get the singleton instance
  static StringeeCallManager get instance => _instance;

  factory StringeeCallManager() => _instance;

  /// list of calls
  final List<StringeeCallModel> _calls = [];

  /// callkeep manager to handle callkit
  late CallkeepManager _callkeepManager;

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

    // add the call to the list
    _calls.add(stringeeCallModel);

    if (isIOS) {
      // TODO: - show callkit
    } else {
      // TODO: - handle incoming call for android
    }

    final initializedCallResult = await stringeeCallModel.call.initAnswer();

    if (initializedCallResult['status']) {
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
    StringeeCallModel stringeeCallModel;
    if (call != null) {
      stringeeCallModel = StringeeCallModel(
        StringeeCallWrapper(call),
        isIncomingCall: false,
        from: from,
        to: to,
        customData: customData,
        videoQuality: videoQuality,
      );
    } else {
      stringeeCallModel = StringeeCallModel(
        StringeeCall2Wrapper(call2!),
        isIncomingCall: false,
        from: from,
        to: to,
        customData: customData,
        videoQuality: videoQuality,
      );
    }
    _calls.add(stringeeCallModel);
    return Result.success(stringeeCallModel);
  }

  @override
  Future<Result> answeredCall(StringeeCallModel call) async {
    // TODO: - handle call answered
    if (isIOS) {
      // answer callkit
    } else {
      // android
    }
    return Result.success('Call answered successfully');
  }

  @override
  Future<Result> endedCall(StringeeCallModel call) async {
    // remove the call from the list
    _calls.remove(call);

    // TODO: - handle call ended
    if (isIOS) {
      // end callkit
    } else {
      // android
    }

    // dismiss the call screen
    StringeeWrapper().stringeeListener?.onDismissCallWidget.call('Call ended');
    return Result.success('Call ended successfully');
  }

  @override
  Future<Result> madeCall(StringeeCallModel call) async {
    if (isIOS) {
      // show callkit
    } else {
      // android
    }
    return Result.success('Call made successfully');
  }
}
