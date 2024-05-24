import 'package:call_sample/stringee_wrapper/call/call.dart';
import 'package:call_sample/stringee_wrapper/common/common.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import '../interfaces/interfaces.dart';
import '../push_manager/callkeep_manager.dart';

class StringeeCallManager implements StringeeCallInterface {
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
  List<StringeeCallModel> _calls = [];

  /// callkeep manager to handle callkit
  late CallkeepManager _callkeepManager;

  @override
  Future<Result> handleIncomingCall({
    StringeeCall? call,
    StringeeCall2? call2,
  }) async {
    assert(call != null || call2 != null, 'Call cannot be null');

    // create a call model
    StringeeCallModel callModel = StringeeCallModel(call: call, call2: call2);

    // TODO: - handle current call if needed

    // add the call to the list
    _calls.add(callModel);

    if (isIOS) {
      // TODO: - show callkit
    } else {
      // TODO: - handle incoming call for android
    }

    // initialize the call
    if (callModel.isCall) {
      return _handleInitializedCall(
          callModel, await callModel.call!.initAnswer());
    } else {
      return _handleInitializedCall(
          callModel, await callModel.call2!.initAnswer());
    }
  }

  Future<Result> _handleInitializedCall(
    StringeeCallModel callModel,
    Map<dynamic, dynamic> value,
  ) async {
    // TODO: - handle initialized call
    if (value['status']) {
      return Result.success(callModel);
    } else {
      return Result.failure('Error while handle Incoming call');
    }
  }

  @override
  Future<Result> handleOutgoingCall({
    required String from,
    required String to,
    StringeeCall? call,
    StringeeCall2? call2,
  }) async {
    // create a call model
    StringeeCallModel callModel = StringeeCallModel(call: call, call2: call2);

    // TODO: - make call

    return Result.success(callModel);
  }
}
