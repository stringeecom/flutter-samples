import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:call_sample/stringee_wrapper/common/common.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installPlatformChannelMocks);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final manager = StringeeCallManager();
    for (final call in manager.calls.toList()) {
      manager.clear(call, dismissCallWidget: false);
    }
    manager.endedCalls.clear();
  });

  test('looks up calls and returns null for unknown identifiers', () async {
    final fake = FakeStringeeCall(callId: 'call-lookup');
    final model = StringeeCallModel(fake)..setUuid('uuid-lookup');
    final manager = StringeeCallManager();
    manager.calls.add(model);

    expect(manager.callWithUuid('uuid-lookup'), same(model));
    expect(manager.callWithUuid('unknown'), isNull);
    expect(manager.callWithCallId('call-lookup'), same(model));
    expect(manager.callWithCallId(''), isNull);
    expect(manager.callWithCallId('unknown'), isNull);

    manager.clear(model, dismissCallWidget: false);
    await fake.close();
  });

  test('answers only incoming calls and propagates SDK answer failures',
      () async {
    final manager = StringeeCallManager();
    final outgoingFake = FakeStringeeCall();
    final outgoing = StringeeCallModel(outgoingFake, isIncomingCall: false);
    expect((await manager.answerStringeeCall(outgoing)).failure,
        'Only incoming calls can be answered');

    final incomingFake = FakeStringeeCall()..succeed = false;
    final incoming = StringeeCallModel(incomingFake);
    manager.calls.add(incoming);
    expect((await manager.answerStringeeCall(incoming)).failure, 'Failure');

    incomingFake.succeed = true;
    final result = await manager.answerStringeeCall(incoming);
    expect(result.isSuccess, isTrue);
    expect(incoming.callState, CallState.starting);
    expect(incomingFake.invocations, contains('answer'));

    manager.clear(incoming, dismissCallWidget: false);
    outgoing.dispose();
    await outgoingFake.close();
    await incomingFake.close();
  });

  test('ends unanswered incoming with reject and answered call with hangup',
      () async {
    final manager = StringeeCallManager();
    final incomingFake = FakeStringeeCall(callId: 'incoming');
    final incoming = StringeeCallModel(incomingFake);
    manager.calls.add(incoming);
    expect(incoming.isShouldReject, isTrue);
    await manager.endStringeeCall(incoming);
    expect(incomingFake.invocations, contains('reject'));

    final activeFake = FakeStringeeCall(callId: 'active');
    final active = StringeeCallModel(activeFake)
      ..signalingState = StringeeSignalingState.answered
      ..callState = CallState.started;
    manager.calls.add(active);
    expect(active.isShouldReject, isFalse);
    await manager.endStringeeCall(active);
    expect(activeFake.invocations, contains('hangup'));

    await incomingFake.close();
    await activeFake.close();
  });

  test('clear releases once, records ended calls and bounds history', () async {
    final manager = StringeeCallManager();
    final fakes = <FakeStringeeCall>[];
    for (var index = 0; index < 22; index++) {
      final fake = FakeStringeeCall(callId: 'call-$index');
      fakes.add(fake);
      final model = StringeeCallModel(fake);
      manager.calls.add(model);
      manager.clear(model, dismissCallWidget: false);
      manager.clear(model, dismissCallWidget: false);
    }

    expect(manager.calls, isEmpty);
    expect(manager.endedCalls, hasLength(20));
    expect(manager.endedCalls.first.call.callId, 'call-2');
    for (final fake in fakes) {
      await fake.close();
    }
  });

  test('creates both outgoing generations and enforces one active call',
      () async {
    final manager = StringeeCallManager();
    final client = StringeeClient();

    final first = await manager.handleOutgoingStringeeCall(
      call: StringeeCall(client),
      from: '1000',
      to: '1001',
      isVideoCall: false,
    );
    expect(first.isSuccess, isTrue);
    expect(first.success?.isVideoCall, isFalse);

    final blocked = await manager.handleOutgoingStringeeCall2(
      call: StringeeCall2(client),
      from: '1000',
      to: '1002',
      isVideoCall: true,
    );
    expect(blocked.failure, 'There is an active call');
    manager.clear(first.success!, dismissCallWidget: false);

    final second = await manager.handleOutgoingStringeeCall2(
      call: StringeeCall2(client),
      from: '1000',
      to: '1002',
      isVideoCall: true,
      videoQuality: VideoQuality.hd,
    );
    expect(second.isSuccess, isTrue);
    expect(second.success?.isVideoCall, isTrue);
    manager.clear(second.success!, dismissCallWidget: false);
  });

  test('makeCall starts audio/service on success', () async {
    final fake = FakeStringeeCall(callId: 'outgoing');
    final model = StringeeCallModel(
      fake,
      isIncomingCall: false,
      from: '1000',
      to: '1001',
    );
    final manager = StringeeCallManager();
    manager.calls.add(model);

    final result = await manager.makeCall(model);

    expect(result.isSuccess, isTrue);
    expect(fake.invocations, contains('makeCallFromParams'));
    manager.clear(model, dismissCallWidget: false);
    await fake.close();
  });
}
