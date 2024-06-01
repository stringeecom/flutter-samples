import 'package:flutter/material.dart';

/// A listener for Stringee events
class StringeeListener {
  final Function(String userId) onConnected;
  final Function() onDisConnected;
  final Function() onRequestNewToken;
  final Function(Map<dynamic, dynamic> event)? onReceiveCallInfo;
  final Function(Map<dynamic, dynamic> event)? onReceiveCustomMessage;
  final Function(int code, String message) onConnectError;
  final Function(Widget callWidget) onPresentCallWidget;
  final Function(String message) onDismissCallWidget;

  /// [StringeeListener] constructor
  /// [onConnected] is called when the client is connected
  /// [onDisConnected] is called when the client is disconnected
  /// [onRequestNewToken] is called when the client needs a new token
  /// [onReceiveCallInfo] is called when the client receives call info
  /// [onReceiveCustomMessage] is called when the client receives a custom message
  /// [onConnectError] is called when the client has an error
  /// [onPresentCallWidget] is called when the client should present a call widget
  /// [onDismissCallWidget] is called when the client should dismiss a call widget
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
