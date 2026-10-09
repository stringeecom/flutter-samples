# Stringee Flutter Samples

Production-oriented Flutter samples for Stringee Call, Chat, and push
notifications on Android and iOS.

## Samples

| Sample | Demonstrates |
| --- | --- |
| [`call_sample`](call_sample/) | Voice and video calls using both `StringeeCall` and `StringeeCall2`, token persistence, Android FCM notifications, and iOS PushKit/CallKit |
| [`chat_notification_sample`](chat_notification_sample/) | Stringee Chat conversations, messages, participants, Firebase Messaging, APNs, token persistence, and logout |

Both applications use `stringee_plugin: ^1.3.4`. Android release builds enable
R8 and resource shrinking; the plugin supplies targeted Stringee, WebRTC, and
JNI consumer rules. Access tokens are entered at runtime, stored for automatic
reconnect, and removed on logout. Neither sample generates a Stringee access
token from an API secret in the mobile application.

## Requirements

- A recent stable Flutter SDK with Dart `>=3.3.4`.
- Android Studio and JDK 17 for Android builds.
- Xcode and CocoaPods for iOS builds; iOS 15.0 or later. Each `ios/Podfile`
  installs Stringee iOS SDK 2.2.0 from its podspec URL, because that version is
  not published to the CocoaPods trunk.
- A Stringee project with the required Call or Chat features enabled.
- A trusted backend that issues Stringee access tokens.
- A Firebase project for Android notifications and Chat push notifications.
- A physical iOS device for complete PushKit/CallKit testing.

## Get started

Open the sample you want to run and install its dependencies:

```shell
cd call_sample
flutter pub get
flutter run
```

or:

```shell
cd chat_notification_sample
flutter pub get
flutter run
```

Paste an access token issued by your backend into the connection screen. After
a successful connection, the sample persists the token and reconnects on the
next launch. Use **Logout** to unregister push, disconnect Stringee, and clear
the saved session.

See the sample-specific setup and flow documentation:

- [`call_sample/README.md`](call_sample/README.md)
- [`chat_notification_sample/README.md`](chat_notification_sample/README.md)

## Firebase and notifications

Configure each application with FlutterFire CLI from its own directory:

```shell
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
flutterfire configure --platforms=android,ios
```

The call sample uses Android FCM and iOS PushKit/CallKit for incoming-call
presentation. The chat sample uses Firebase Messaging on Android and APNs on
iOS for chat notifications. Platform capabilities and credentials must also be
configured in Firebase, the Stringee developer portal, and Xcode as described
in each sample README.

## Call sample coverage

The call application exposes four independent outgoing-call cases:

| API | Voice | Video |
| --- | --- | --- |
| `StringeeCall` | Supported | Supported |
| `StringeeCall2` | Supported | Supported |

Its shared wrapper validates SDK responses, bounds answer waits, controls the
call timer, handles outgoing-connected state, prevents duplicate end handling,
and avoids sending an unnecessary Stringee end request after the SDK has
already terminated a call.

## Chat sample coverage

The chat application demonstrates:

- Creating and querying one-to-one conversations.
- Local, latest, before, and after pagination.
- Sending, loading, editing, pinning, deleting, and revoking messages.
- Adding/removing participants, changing roles, typing state, and mark-as-read.
- Foreground, background, notification-open, and push-token refresh handling.
- Stringee conversation and message object-change events.

Its current automated line coverage is **91.9% (542/590)**:

| File | Line coverage |
| --- | ---: |
| `lib/chat_screen.dart` | 88.1% |
| `lib/conversation.dart` | 96.6% |

## Validate a sample

Run these commands from the selected sample directory:

```shell
flutter analyze
flutter test --coverage
flutter build apk --debug
flutter build ios --debug --no-codesign
dart doc --validate-links
```

Generated `coverage/`, `doc/api/`, build outputs, local Flutter overrides, and
machine-specific Firebase files should remain ignored according to the sample's
repository policy.

## Stringee documentation

- [Getting started with the Stringee Flutter plugin](https://developer.stringee.com/docs/getting-started-flutter)
- [Push notifications for Flutter](https://developer.stringee.com/docs/push-notification/flutter)
