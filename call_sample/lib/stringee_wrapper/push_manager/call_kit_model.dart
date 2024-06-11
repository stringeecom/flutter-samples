import 'dart:async';

import 'package:call_sample/stringee_wrapper/stringee_wrapper.dart';

import '../call/stringee_call_model.dart';
import 'callkeep_manager.dart';

class CallKitModel {
  // call uuid handled by callkit
  String? uuid;

  // call id of the stringee call
  String? callId;

  // serial of the stringee call
  int? serial;

  // stringee call model
  StringeeCallModel? callModel;

  final int timeout;

  /// [CallKitModel] constructor
  /// all params do not required
  /// if have [uuid] and do not have [callModel], start timeout to end call
  CallKitModel({
    this.uuid,
    this.callId,
    this.serial,
    this.timeout = 8,
    this.callModel,
  }) {
    _count = timeout;

    if (callModel == null && uuid != null) {
      _startCountTimeout();
    }

    if (callId != null && uuid != null && callModel == null) {
      // check call exist in stringee server then end call if not exist
      _checkCallExist();
    }
  }

  _checkCallExist() async {
    if (callId != null) {
      final result = await StringeeWrapper().stringeeClient.existCall(callId!);
      if (!result['status']) {
        _endCallKit();
        return;
      }
    }
  }

  Timer? _timer;
  int _count = 0;

  int get count => _count;

  _startCountTimeout() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: timeout), () {
      if (uuid != null && callModel == null) {
        _endCallKit();
      }
    });
  }

  stopCountTimeout() {
    _timer?.cancel();
  }

  _endCallKit() {
    if (uuid != null) {
      _timer?.cancel();
      CallkeepManager().callkeep.endCall(uuid!);
      CallkeepManager().removeCallKitModel(uuid!);
    }
  }
}
