import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:call_sample/stringee_wrapper/push_manager/call_kit_model.dart';
import 'package:call_sample/stringee_wrapper/push_manager/callkeep_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PlatformCallLog platformLog;
  final callManager = StringeeCallManager();
  final callkeep = CallkeepManager();

  setUpAll(() async {
    platformLog = await installPlatformChannelMocks();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    for (final call in callManager.calls.toList()) {
      callManager.clear(call, dismissCallWidget: false);
    }
    callManager.endedCalls.clear();
    platformLog.callkeep.clear();
    platformLog.callkeepActive = true;
  });

  test('rejects CallKit operations without a UUID', () async {
    final fake = FakeStringeeCall();
    final model = StringeeCallModel(fake);

    expect((await callkeep.answerCallIfNeeded(model)).failure, 'uuid is empty');
    expect(
      (await callkeep.reportEndCallIfNeeded(stringeeCallModel: model)).failure,
      'uuid is empty',
    );
    expect(
      (await callkeep.reportMuteCallIfNeeded(
        stringeeCallModel: model,
        muted: true,
      ))
          .failure,
      'uuid is empty',
    );
    model.dispose();
    await fake.close();
  });

  test('reports outgoing start connected mute and end lifecycle', () async {
    final fake = FakeStringeeCall(to: 'Bob', toAlias: 'B', isVideoCall: true);
    final model = StringeeCallModel(
      fake,
      isIncomingCall: false,
      from: 'Alice',
      to: 'Bob',
    );

    expect(
        (await callkeep.reportOutgoingCallIfNeeded(model)).isSuccess, isTrue);
    expect(model.uuid, isNotEmpty);
    expect((await callkeep.answerCallIfNeeded(model)).isSuccess, isTrue);
    expect(
      (await callkeep.reportMuteCallIfNeeded(
        stringeeCallModel: model,
        muted: true,
      ))
          .isSuccess,
      isTrue,
    );
    expect(
      (await callkeep.reportEndCallIfNeeded(stringeeCallModel: model))
          .isSuccess,
      isTrue,
    );
    expect(
      platformLog.callkeep.map((call) => call.method),
      containsAll(<String>[
        'startCall',
        'setMutedCall',
        'endCall',
      ]),
    );
    model.dispose();
    await fake.close();
  });

  test('reports and correlates duplicate incoming call metadata', () async {
    final firstFake = FakeStringeeCall(
      callId: 'incoming-id',
      serial: 9,
      from: 'Alice',
      fromAlias: 'Alice Alias',
    );
    final first = StringeeCallModel(firstFake);
    expect(
        (await callkeep.reportIncomingCallIfNeeded(first)).isSuccess, isTrue);
    expect(first.uuid, isNotEmpty);

    final secondFake = FakeStringeeCall(callId: 'incoming-id', serial: 9);
    final second = StringeeCallModel(secondFake);
    expect(
        (await callkeep.reportIncomingCallIfNeeded(second)).isSuccess, isTrue);
    expect(second.uuid, first.uuid);

    final otherFake = FakeStringeeCall(callId: 'different', serial: 10);
    final other = StringeeCallModel(otherFake);
    expect(
        (await callkeep.reportIncomingCallIfNeeded(other)).isSuccess, isTrue);
    expect(other.uuid, isEmpty);

    await callkeep.reportEndCallIfNeeded(stringeeCallModel: first);
    first.dispose();
    second.dispose();
    other.dispose();
    await firstFake.close();
    await secondFake.close();
    await otherFake.close();
  });

  test('does not report a Stringee call already retained as ended', () async {
    final fake = FakeStringeeCall(callId: 'ended-id');
    final model = StringeeCallModel(fake);
    callManager.endedCalls.add(model);

    expect(
      (await callkeep.reportIncomingCallIfNeeded(model)).failure,
      'Call has ended',
    );
    model.dispose();
    await fake.close();
  });

  test('ends CallKit only when another device handled the call', () async {
    final fake = FakeStringeeCall(callId: 'other-device');
    final model = StringeeCallModel(fake)..setUuid('external-uuid');

    final result = await callkeep.reportEndCallIfNeeded(
      stringeeCallModel: model,
      reason: -1000,
    );

    expect(result.isSuccess, isTrue);
    expect(fake.invocations, isEmpty);
    expect(
        platformLog.callkeep.any((call) => call.method == 'endCall'), isTrue);
    model.dispose();
    await fake.close();
  });

  test('rejects end when active CallKit UUID does not match', () async {
    final activeFake = FakeStringeeCall(callId: 'active');
    final active = StringeeCallModel(activeFake);
    await callkeep.reportIncomingCallIfNeeded(active);

    final otherFake = FakeStringeeCall(callId: 'other');
    final other = StringeeCallModel(otherFake)..setUuid('wrong-uuid');
    expect(
      (await callkeep.reportEndCallIfNeeded(stringeeCallModel: other)).failure,
      'uuid is not matched',
    );

    await callkeep.reportEndCallIfNeeded(stringeeCallModel: active);
    active.dispose();
    other.dispose();
    await activeFake.close();
    await otherFake.close();
  });

  test('reports ended reason and also ends the matching Stringee call',
      () async {
    final fake = FakeStringeeCall(callId: 'reason-call');
    final model = StringeeCallModel(fake);
    callManager.calls.add(model);
    await callkeep.reportIncomingCallIfNeeded(model);

    expect(
      (await callkeep.reportEndCallIfNeeded(
        stringeeCallModel: model,
        reason: 2,
      ))
          .isSuccess,
      isTrue,
    );
    await pumpEventQueue();
    expect(fake.invocations, contains('reject'));
    expect(callManager.calls, isNot(contains(model)));
    await fake.close();
  });

  test('hasActiveCall checks tracked calls until an active one is found',
      () async {
    expect(await callkeep.hasActiveCall(), isFalse);
    final firstFake = FakeStringeeCall(callId: 'first');
    final first = StringeeCallModel(firstFake)..setUuid('uuid-first');
    callManager.calls.add(first);
    platformLog.callkeepActive = false;
    expect(await callkeep.hasActiveCall(), isFalse);
    platformLog.callkeepActive = true;
    expect(await callkeep.hasActiveCall(), isTrue);

    callManager.clear(first, dismissCallWidget: false);
    await pumpEventQueue();
    await firstFake.close();
  });

  test('CallKitModel timeout ends orphan while stop cancels cleanup', () async {
    final orphan = CallKitModel(uuid: 'orphan', timeout: 0);
    expect(orphan.count, 0);
    await pumpEventQueue();
    expect(
      platformLog.callkeep.any((call) => call.method == 'endCall'),
      isTrue,
    );

    platformLog.callkeep.clear();
    final correlated = CallKitModel(uuid: 'correlated', timeout: 0)
      ..stopCountTimeout();
    expect(correlated.uuid, 'correlated');
    await pumpEventQueue();
    expect(platformLog.callkeep, isEmpty);
  });
}
