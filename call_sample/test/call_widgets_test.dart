import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:call_sample/stringee_wrapper/common/common.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_action_widget.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_answer.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_audio.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_end.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_mic.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_switch.dart';
import 'package:call_sample/stringee_wrapper/widgets/call_button_video.dart';
import 'package:call_sample/stringee_wrapper/widgets/sc_calling_widget.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_avatar_widget.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_incall_widget.dart';
import 'package:call_sample/stringee_wrapper/widgets/stringee_ringing_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

import 'test_support.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _modelHost(StringeeCallModel model, Widget child) {
  return MaterialApp(
    home: ChangeNotifierProvider<StringeeCallModel>.value(
      value: model,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(installPlatformChannelMocks);

  testWidgets('base actions render configured icons and invoke callbacks',
      (tester) async {
    var presses = 0;
    final widgets = <Widget>[
      CallActionWidget(icon: Icons.add, onPressed: () => presses++),
      CallButtonAnswer(onPressed: () => presses++),
      CallButtonEnd(onPressed: () => presses++),
      CallButtonMic(enabled: true, onPressed: () => presses++),
      CallButtonMic(enabled: false, onPressed: () => presses++),
      CallButtonVideo(enabled: true, onPressed: () => presses++),
      CallButtonVideo(enabled: false, onPressed: () => presses++),
      CallButtonSwitch(onPressed: () => presses++),
    ];

    await tester.pumpWidget(
      _host(Wrap(
          children: widgets.map((widget) => SizedBox(child: widget)).toList())),
    );

    expect(find.byIcon(Icons.call_rounded), findsOneWidget);
    expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
    expect(find.byIcon(Icons.videocam_off_rounded), findsOneWidget);
    expect(find.byIcon(Icons.flip_camera_ios_rounded), findsOneWidget);
    for (final button in find.byType(ElevatedButton).evaluate().toList()) {
      await tester.tap(find.byWidget(button.widget));
    }
    expect(presses, widgets.length);
  });

  testWidgets('audio action maps all supported routes to an icon',
      (tester) async {
    final cases = <AudioType, IconData>{
      AudioType.speakerPhone: Icons.volume_up,
      AudioType.wiredHeadset: Icons.headphones,
      AudioType.earpiece: Icons.volume_down,
      AudioType.bluetooth: Icons.bluetooth,
    };
    var presses = 0;
    await tester.pumpWidget(
      _host(
        Wrap(
          children: cases.keys
              .map(
                (type) => CallButtonAudio(
                  audioDevice: AudioDevice(audioType: type),
                  onPressed: () => presses++,
                ),
              )
              .toList(),
        ),
      ),
    );

    for (final icon in cases.values) {
      expect(find.byIcon(icon), findsOneWidget);
    }
    for (final button in find.byType(ElevatedButton).evaluate().toList()) {
      await tester.tap(find.byWidget(button.widget));
    }
    expect(presses, cases.length);
  });

  testWidgets('shared layout and avatar handle initials and empty values',
      (tester) async {
    await tester.pumpWidget(
      _host(
        SCCallingWidget(
          body: const Column(
            children: [
              StringeeAvatarWidget(text: 'alice'),
              StringeeAvatarWidget(text: ''),
              StringeeAvatarWidget(),
            ],
          ),
          bottom: const Text('controls'),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('controls'), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNWidgets(6));
  });

  testWidgets('ringing UI exposes incoming answer and reject actions',
      (tester) async {
    final fake = FakeStringeeCall(from: 'Alice');
    final model = StringeeCallModel(fake);
    await tester.pumpWidget(_modelHost(model, const StringeeRingingWidget()));

    expect(find.text(CallState.incoming.name), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(CallButtonAnswer), findsOneWidget);
    expect(find.byType(CallButtonEnd), findsOneWidget);

    await tester.tap(find.byType(CallButtonAnswer));
    await tester.pump();
    await tester.tap(find.byType(CallButtonEnd));
    await tester.pump();
    expect(fake.invocations, containsAll(<String>['answer', 'hangup']));
    model.dispose();
    await fake.close();
  });

  testWidgets('ringing UI exposes one end action for outgoing calls',
      (tester) async {
    final fake = FakeStringeeCall(to: 'Bob');
    final model = StringeeCallModel(
      fake,
      isIncomingCall: false,
      from: 'Alice',
      to: 'Bob',
    );
    await tester.pumpWidget(_modelHost(model, const StringeeRingingWidget()));

    expect(find.text(CallState.calling.name), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.byType(CallButtonAnswer), findsNothing);
    expect(find.byType(CallButtonEnd), findsOneWidget);
    await tester.tap(find.byType(CallButtonEnd));
    await tester.pump();
    expect(fake.invocations, contains('hangup'));
    model.dispose();
    await fake.close();
  });

  testWidgets('voice in-call UI renders timer and executes controls',
      (tester) async {
    final fake = FakeStringeeCall(to: 'Bob');
    final model = StringeeCallModel(
      fake,
      isIncomingCall: false,
      from: 'Alice',
      to: 'Bob',
    )..callState = CallState.started;
    await tester.pumpWidget(_modelHost(model, const StringeeIncallWidget()));

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    expect(find.byType(StringeeAvatarWidget), findsOneWidget);
    await tester.tap(find.byType(CallButtonAudio));
    await tester.tap(find.byType(CallButtonMic));
    await tester.pump();
    expect(fake.invocations, contains('mute:true'));
    model.dispose();
    await fake.close();
  });

  testWidgets('video in-call UI renders placeholders and all controls',
      (tester) async {
    final fake = FakeStringeeCall(to: 'Bob', isVideoCall: true);
    final model = StringeeCallModel(
      fake,
      isIncomingCall: false,
      from: 'Alice',
      to: 'Bob',
      isVideoCall: true,
    )..callState = CallState.started;
    await tester.pumpWidget(_modelHost(model, const StringeeIncallWidget()));

    expect(find.byType(Placeholder), findsNWidgets(2));
    expect(find.byType(CallButtonVideo), findsOneWidget);
    expect(find.byType(CallButtonSwitch), findsOneWidget);
    await tester.tap(find.byType(CallButtonVideo));
    await tester.tap(find.byType(CallButtonMic));
    await tester.tap(find.byType(CallButtonSwitch));
    await tester.pump();
    expect(
      fake.invocations,
      containsAll(<String>['enableVideo:false', 'mute:true', 'switchCamera']),
    );
    model.dispose();
    await fake.close();
  });
}
