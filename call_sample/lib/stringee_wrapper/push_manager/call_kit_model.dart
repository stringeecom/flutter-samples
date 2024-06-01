import 'dart:async';

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
  }

  Timer? _timer;
  int _count = 0;

  int get count => _count;

  _startCountTimeout() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: timeout), () {
      if (uuid != null) {
        CallkeepManager().callkeep.endCall(uuid!);
      }
    });
  }

  stopCountTimeout() {
    _timer?.cancel();
  }
}
