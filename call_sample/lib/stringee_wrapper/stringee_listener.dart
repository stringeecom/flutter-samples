import 'package:flutter/material.dart';

/// A listener for Stringee events
class StringeeListener {
  final Function() onConnected;
  final Function() onDisConnected;
  final Function() onRequestNewToken;
  final Function(int code, String message) onConnectError;
  final Function(Widget callWidget) onPresentCallWidget;
  final Function(String message) onDismissCallWidget;

  StringeeListener({
    required this.onConnected,
    required this.onDisConnected,
    required this.onRequestNewToken,
    required this.onConnectError,
    required this.onPresentCallWidget,
    required this.onDismissCallWidget,
  });
}
