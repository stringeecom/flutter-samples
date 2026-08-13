import 'dart:io';

export 'response.dart';

/// Whether the current runtime platform is iOS.
bool get isIOS => Platform.isIOS;

/// UI lifecycle shared by incoming and outgoing calls.
enum CallState {
  /// An incoming call is waiting for an answer or rejection.
  incoming,

  /// An outgoing call request is being created.
  calling,

  /// The remote endpoint is ringing.
  ringing,

  /// Signaling is answered while media is still connecting.
  starting,

  /// Signaling is answered and media is connected.
  started,

  /// The remote endpoint reported busy.
  busy,

  /// The call has ended and should be cleared.
  ended,
}
