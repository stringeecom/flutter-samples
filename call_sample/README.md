# StringeeWrapper Class Documentation

The `StringeeWrapper` class serves as a singleton interface to interact with the Stringee API for handling voice and video calls. This documentation provides an overview of its properties, methods, and usage.

## Table of Contents

- [Constructors](#constructors)
- [Properties](#properties)
- [Methods](#methods)
  - [connect](#connect)
  - [disconnect](#disconnect)
  - [enablePush](#enablepush)
  - [unregisterPush](#unregisterpush)
  - [makeCall](#makecall)
  - [addListener](#addlistener)

## Constructors

### `StringeeWrapper()`

- Returns the singleton instance of `StringeeWrapper`.

## Properties

### `stringeeListener`

- Type: `StringeeListener?`
- Description: Getter for `_stringeeListener`.

### `callTimeout`

- Type: `int`
- Description: Timeout for a call, default is 60 seconds.

### `connected`

- Type: `bool`
- Description: Indicates if the client is connected to the Stringee server.

## Methods

### `configure`

```dart
void configure({int callTimeOut = 60})
```

- Description: Configure properties for call.
- Parameters:
  - `callTimeOut` (int): Time out for call if have no interaction in seconds. Default is 60
  - more properties can be added here later

### `connect`

```dart
Future<void> connect(String token) async
```

- Description: Connects to the Stringee server using the provided token.
- Parameters:
  - `token` (String): The token of the user.

### `disconnect`

```dart
Future<void> disconnect() async
```

- Description: Disconnects from the Stringee server.

### `enablePush`

```dart
Future<bool> enablePush({bool? isProduction, bool? isVoip}) async
```

- Description: Enables push to receive notification incoming calls when app is in background. Check more on [Receive Push](#receive-push)
- Parameters:
  - `isProduction` (bool?, optional): Indicates if the push is for production. Defaults to `kReleaseMode`.
  - `isVoip` (bool?, optional): Indicates if the push is for VoIP.

### `unregisterPush`

```dart
Future<bool> unregisterPush() async
```

- Description: Unregisters push notifications.

### `makeCall`

```dart
Future<void> makeCall({
  required String from,
  required String to,
  bool isVideoCall = false,
  Map<dynamic, dynamic>? customData,
  VideoQuality? videoQuality,
}) async
```

- Description: Makes a call to the specified user.
- Parameters:
  - `from` (String): The caller ID.
  - `to` (String): The callee ID.
  - `isVideoCall` (bool, optional): Indicates if the call is a video call. Defaults to `false`.
  - `customData` (Map<dynamic, dynamic>?, optional): Custom data for the call.
  - `videoQuality` (VideoQuality?, optional): Quality of the video.

### `addListener`

```dart
Future<void> addListener(StringeeListener listener) async
```

- Description: Adds a listener to listen to events from `StringeeWrapper`.
- Parameters:
  - `listener` ([StringeeListener](#stringeelistener-class)): The listener to listen to events.

## StringeeListener Class

The `StringeeListener` class is a listener for handling various events from the `StringeeWrapper`.

### `onConnected`

- Type: `Function()`
- Description: Callback function called when the client is connected to Stringee server.

### `onDisConnected`

- Type: `Function()`
- Description: Callback function called when the client is disconnected to Stringee server.

### `onRequestNewToken`

- Type: `Function()`
- Description: Callback function called when the token is expired, you should call [connect](#connect) with new token.

### `onReceiveCallInfo`

- Type: `Function(Map<dynamic, dynamic> event)?`
- Description: Optional callback function called when the client receives call information.

### `onReceiveCustomMessage`

- Type: `Function(Map<dynamic, dynamic> event)?`
- Description: Optional callback function called when the client receives a custom message.

### `onConnectError`

- Type: `Function(int code, String message)`
- Description: Callback function called when the client encounters an error.

### `onPresentCallWidget`

- Type: `Function(Widget callWidget)`
- Description: Callback function called when the client should present a call widget.

### `onDismissCallWidget`

- Type: `Function(String message)`
- Description: Callback function called when the client should dismiss a call widget.

## Receive Push

To receive incoming calls when app on background/terminated, you have to enable push. To handle it, `StringeeWrapper` using:

- iOS: CallKit and PushKit
- Android: FCM

**NOTE: When push was enabled, your app should call [connect](#connect) as soon as possible to receive incoming call from Stringee.**
