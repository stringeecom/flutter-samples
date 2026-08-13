import 'dart:async';

import '../call/stringee_call_model.dart';
import 'callkeep_manager.dart';

/// Correlates one CallKit UUID with its eventual Stringee call model.
///
/// PushKit can create CallKit UI before the SDK emits the incoming call. A
/// bounded timeout removes orphaned system call UI when correlation never
/// completes.
class CallKitModel {
  /// UUID handled by CallKit.
  String? uuid;

  /// Server-assigned Stringee call ID.
  String? callId;

  /// Stringee SDK call serial.
  int? serial;

  /// Correlated call model, or `null` while waiting for the SDK event.
  StringeeCallModel? callModel;

  /// Maximum seconds to keep an uncorrelated CallKit entry.
  final int timeout;

  /// Creates correlation state and starts a timeout when only [uuid] exists.
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
      // _checkCallExist();
    }
  }

  // _checkCallExist() async {
  //   if (callId != null) {
  //     final result = await StringeeWrapper().stringeeClient.existCall(callId!);
  //     if (!result['status']) {
  //       _endCallKit();
  //       return;
  //     }
  //   }
  // }

  Timer? _timer;
  int _count = 0;

  /// Remaining timeout counter value initialized for this model.
  int get count => _count;

  void _startCountTimeout() {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: timeout), () {
      if (uuid != null && callModel == null) {
        _endCallKit();
      }
    });
  }

  /// Cancels orphan cleanup after the SDK call has been correlated.
  void stopCountTimeout() {
    _timer?.cancel();
  }

  void _endCallKit() {
    if (uuid != null) {
      _timer?.cancel();
      CallkeepManager().callkeep.endCall(uuid!);
      CallkeepManager().removeCallKitModel(uuid!);
    }
  }
}
