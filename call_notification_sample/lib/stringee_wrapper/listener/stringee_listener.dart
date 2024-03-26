import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

class StringeeListener {
  void Function(String userId) onConnected;
  void Function() onDisconnected;
  void Function() onRequestNewToken;
  void Function(int code, String message) onConnectError;
  void Function(StringeeSignalingState signalingState)
      onCallSignalingStateChange;
  void Function(StringeeMediaState mediaState) onCallMediaStateChane;
  void Function() onShowCallWidget;
  void Function() onCallWidgetDismiss;

  StringeeListener({
    required this.onConnected,
    required this.onDisconnected,
    required this.onRequestNewToken,
    required this.onConnectError,
    required this.onCallSignalingStateChange,
    required this.onCallMediaStateChane,
    required this.onShowCallWidget,
    required this.onCallWidgetDismiss,
  });
}
