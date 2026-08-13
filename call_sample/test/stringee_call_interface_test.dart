import 'package:call_sample/stringee_wrapper/interfaces/stringee_call_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installPlatformChannelMocks);

  for (final useCall2 in <bool>[false, true]) {
    test('StringeeCall${useCall2 ? '2' : ''} wrapper delegates full API',
        () async {
      final client = StringeeClient();
      final StringeeCallInterface wrapper = useCall2
          ? StringeeCall2Wrapper(StringeeCall2(client))
          : StringeeCallWrapper(StringeeCall(client));

      expect(wrapper.callId, isNull);
      expect(wrapper.serial, isNull);
      expect(wrapper.from, isNull);
      expect(wrapper.to, isNull);
      expect(wrapper.fromAlias, isNull);
      expect(wrapper.toAlias, isNull);
      expect(wrapper.callType, isNull);
      expect(wrapper.customDataFromYourServer, isNull);
      expect(wrapper.isVideoCall, isFalse);
      expect(wrapper.eventStreamController, isNotNull);

      final params = MakeCallParams('1000', '1001', isVideoCall: true);
      expect(
        (await wrapper.makeCall(const {'from': '1000', 'to': '1001'}))[
            'status'],
        isTrue,
      );
      expect((await wrapper.makeCallFromParams(params))['status'], isTrue);
      expect((await wrapper.initAnswer())['status'], isTrue);
      expect((await wrapper.answer())['status'], isTrue);
      expect((await wrapper.reject())['status'], isTrue);
      expect((await wrapper.hangup())['status'], isTrue);
      expect((await wrapper.send('1'))['status'], isTrue);
      expect((await wrapper.sendCallInfo(const {'key': 'value'}))['status'],
          isTrue);
      expect((await wrapper.getCallStats())['status'], isTrue);
      expect((await wrapper.mute(true))['status'], isTrue);
      expect((await wrapper.enableVideo(false))['status'], isTrue);
      expect(
        await wrapper.changeAudioDevice(
          AudioDevice(audioType: AudioType.speakerPhone),
        ),
        isA<Result>(),
      );
      expect((await wrapper.switchCamera(cameraId: 'front'))['status'], isTrue);
      expect((await wrapper.resumeVideo())['status'], isTrue);
      expect((await wrapper.setMirror(true, true))['status'], isTrue);
    });
  }
}
