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
  });

  test('validates outgoing identifiers before calling SDK', () async {
    final fake = FakeStringeeCall();
    final model = StringeeCallModel(
      fake,
      isIncomingCall: false,
      from: ' ',
      to: '1001',
    );

    final result = await model.makeCall();

    expect(result.isFailure, isTrue);
    expect(result.failure, 'from and to cannot be null or empty');
    expect(fake.invocations, isEmpty);
    model.dispose();
    await fake.close();
  });

  test('makes outgoing call with normalized values and reports failure',
      () async {
    final fake = FakeStringeeCall();
    final model = StringeeCallModel(
      fake,
      isIncomingCall: false,
      from: ' 1000 ',
      to: ' 1001 ',
      isVideoCall: true,
      customData: const {'source': 'test'},
      videoQuality: VideoQuality.hd,
    );

    expect(model.callState, CallState.calling);
    expect(model.callee, '1001');
    expect(model.isVideoCall, isTrue);
    expect((await model.makeCall()).isSuccess, isTrue);
    expect(fake.invocations, contains('makeCallFromParams'));

    fake.succeed = false;
    expect((await model.makeCall()).failure, 'Error while making call');
    model.dispose();
    await fake.close();
  });

  test('updates mute video camera and audio-device control state', () async {
    final fake = FakeStringeeCall(isVideoCall: true);
    final model = StringeeCallModel(fake, isIncomingCall: false);
    final speaker = AudioDevice(audioType: AudioType.speakerPhone);

    expect(model.isMute, isFalse);
    expect((await model.muteCall()).isSuccess, isTrue);
    expect(model.isMute, isTrue);
    expect((await model.mute(false)).isSuccess, isTrue);
    expect(model.isMute, isFalse);
    expect((await model.enableVideo()).isSuccess, isTrue);
    expect(model.isVideoEnable, isFalse);
    expect((await model.switchCamera()).isSuccess, isTrue);
    expect((await model.changeAudioDevice(speaker)).isSuccess, isTrue);
    expect(model.audioDevice.audioType, AudioType.speakerPhone);

    fake.succeed = false;
    expect((await model.mute(true)).failure, 'Error while mute');
    expect((await model.enableVideo()).failure, 'Error while enableVideo');
    expect((await model.switchCamera()).failure, 'Error while enableVideo');
    expect(
      (await model.changeAudioDevice(speaker)).failure,
      'Error while changeSpeaker',
    );
    model.dispose();
    await fake.close();
  });

  test('combines signaling and media before starting the call', () async {
    final fake = FakeStringeeCall(isVideoCall: true);
    final model = StringeeCallModel(fake, isIncomingCall: false);
    var notifications = 0;
    model.addListener(() => notifications++);

    fake.emit(
      StringeeCallEvents.didChangeSignalingState,
      StringeeSignalingState.ringing,
    );
    await pumpEventQueue();
    expect(model.callState, CallState.ringing);

    fake.emit(
      StringeeCallEvents.didChangeSignalingState,
      StringeeSignalingState.answered,
    );
    await pumpEventQueue();
    expect(model.callState, CallState.starting);

    fake.emit(
      StringeeCallEvents.didChangeMediaState,
      StringeeMediaState.connected,
    );
    await pumpEventQueue();
    expect(model.callState, CallState.started);
    expect(notifications, greaterThan(1));

    model.startTimerIfNeeded();
    model.startTimerIfNeeded();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(model.time, '00:01');
    model.dispose();
    await fake.close();
  });

  test('handles both Call and Call2 stream/video events', () async {
    final fake = FakeStringeeCall(callId: 'video-id', isVideoCall: true);
    final model = StringeeCallModel(fake);

    expect(model.callState, CallState.incoming);
    expect(model.callee, '1000');
    expect(model.readyLocalView, isFalse);
    expect(model.readyRemoteView, isFalse);

    fake.emit(StringeeCallEvents.didReceiveLocalStream, 'other');
    fake.emit(StringeeCallEvents.didReceiveLocalStream, 'video-id');
    fake.emit(StringeeCall2Events.didReceiveRemoteStream, 'video-id');
    await pumpEventQueue();
    expect(model.readyLocalView, isTrue);
    expect(model.readyRemoteView, isTrue);

    fake.emit(
      StringeeCall2Events.didChangeMediaState,
      StringeeMediaState.disconnected,
    );
    fake.emit(
      StringeeCall2Events.didChangeSignalingState,
      StringeeSignalingState.calling,
    );
    await pumpEventQueue();
    expect(model.callState, CallState.calling);

    model.setUuid('uuid-1');
    expect(model.uuid, 'uuid-1');
    model.release();
    model.release();
    model.dispose();
    await fake.close();
  });

  test('forwards call info and clears terminal signaling once', () async {
    final fake = FakeStringeeCall();
    final model = StringeeCallModel(fake);
    StringeeCallManager().calls.add(model);

    fake.emit(
      StringeeCallEvents.didChangeSignalingState,
      StringeeSignalingState.busy,
    );
    await pumpEventQueue();
    expect(model.callState, CallState.busy);
    expect(StringeeCallManager().calls, isNot(contains(model)));
    expect(StringeeCallManager().endedCalls, contains(model));

    expect((await model.hangupCall()).isSuccess, isTrue);
    expect((await model.rejectCall()).isSuccess, isTrue);
    model.dispose();
    await fake.close();
  });

  test('answers incoming call idempotently and resets on SDK failure',
      () async {
    final fake = FakeStringeeCall();
    final model = StringeeCallModel(fake);
    StringeeCallManager().calls.add(model);

    fake.succeed = false;
    expect((await model.answerCall()).isFailure, isTrue);
    fake.succeed = true;
    expect((await model.answerCall()).isSuccess, isTrue);
    expect((await model.answerCall()).success, 'Call answered already');
    expect(fake.invocations.where((item) => item == 'answer'), hasLength(2));

    StringeeCallManager().clear(model);
    model.dispose();
    await fake.close();
  });
}
