import 'package:flutter/material.dart';

/// Application callbacks emitted by `StringeeWrapper`.
class StringeeListener {
  /// Called after the SDK connects, with the authenticated Stringee user ID.
  final Function(String userId) onConnected;

  /// Called after the SDK connection is closed.
  final Function() onDisConnected;

  /// Called when Stringee requires a replacement access token.
  final Function() onRequestNewToken;

  /// Called when the active call receives application call information.
  final Function(Map<dynamic, dynamic> event)? onReceiveCallInfo;

  /// Called when the client receives a Stringee custom message.
  final Function(Map<dynamic, dynamic> event)? onReceiveCustomMessage;

  /// Called when connecting fails with an SDK error code and message.
  final Function(int code, String message) onConnectError;

  /// Called with the call UI that the application should present.
  final Function(Widget callWidget) onPresentCallWidget;

  /// Called when the application should dismiss its presented call UI.
  final Function(String message) onDismissCallWidget;

  /// Creates the callback collection consumed by `StringeeWrapper`.
  StringeeListener({
    required this.onConnected,
    required this.onDisConnected,
    required this.onRequestNewToken,
    required this.onConnectError,
    required this.onPresentCallWidget,
    required this.onDismissCallWidget,
    this.onReceiveCallInfo,
    this.onReceiveCustomMessage,
  });
}
