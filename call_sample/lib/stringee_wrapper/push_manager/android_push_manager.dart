import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:call_sample/stringee_wrapper/call/stringee_call_manager.dart';
import 'package:call_sample/stringee_wrapper/call/stringee_call_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

/// Shared-preferences key used by the Android background call client.
const String androidStringeeAccessTokenKey = 'stringee_android_access_token';

const String _pendingActionKey = 'stringee_pending_notification_action';
const String _pendingActionCallIdKey =
    'stringee_pending_notification_action_call_id';
const String _pendingActionCreatedAtKey =
    'stringee_pending_notification_action_created_at';
const String _incomingNotificationCallIdKey =
    'stringee_incoming_notification_call_id';
const String _foregroundServiceCallIdKey =
    'stringee_foreground_service_call_id';
const Duration _pendingActionTtl = Duration(minutes: 2);

/// A normalized incoming-call notification action.
class AndroidCallNotificationAction {
  /// Creates an action with an optional target [callId].
  const AndroidCallNotificationAction({required this.action, this.callId = ''});

  /// Notification action identifier.
  final String action;

  /// Stringee call ID targeted by the action.
  final String callId;
}

/// Extracts the Stringee payload from an FCM data message.
///
/// Stringee payloads have been delivered as both a JSON string and a nested
/// map, so the sample accepts both forms instead of assuming one transport
/// representation.
@visibleForTesting
Map<String, dynamic>? parseAndroidStringeePushData(
  Map<String, dynamic> messageData,
) {
  if (messageData['stringeePushNotification'] != '1.0') return null;

  final rawData = messageData['data'];
  if (rawData is Map) {
    return rawData.map((key, value) => MapEntry(key.toString(), value));
  }
  if (rawData is String && rawData.isNotEmpty) {
    try {
      final decoded = jsonDecode(rawData);
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Whether [data] represents a call status that should clear notification UI.
@visibleForTesting
bool isTerminalAndroidStringeePush(Map<String, dynamic> data) {
  final status = data['callStatus']?.toString() ?? '';
  final original = data['original'];
  final isOriginal = original == true || original == 1 || original == 'true';
  return status == 'ended' ||
      status == 'busy' ||
      status == 'agentEnded' ||
      (status == 'answered' && !isOriginal);
}

/// Whether a Stringee push payload describes a video call.
@visibleForTesting
bool isAndroidVideoCallPush(Map<String, dynamic> data) {
  final value = data['isVideoCall'];
  return value == true || value == 1 || value == '1' || value == 'true';
}

/// Whether [actual] is compatible with an optional [expected] call ID.
@visibleForTesting
bool doesAndroidCallIdMatch(String expected, String? actual) {
  return expected.isEmpty || expected == (actual ?? '');
}

/// Whether a persisted action is older than the supported reconciliation TTL.
@visibleForTesting
bool isPendingAndroidCallActionExpired({
  required int createdAtMillis,
  required DateTime now,
}) {
  if (createdAtMillis == 0) return true;
  return now.difference(DateTime.fromMillisecondsSinceEpoch(createdAtMillis)) >
      _pendingActionTtl;
}

/// Entry point used by flutter_local_notifications when Reject is pressed
/// while the Flutter UI isolate is not running.
@pragma('vm:entry-point')
Future<void> androidCallNotificationBackgroundAction(
  NotificationResponse response,
) async {
  DartPluginRegistrant.ensureInitialized();
  await AndroidPushManager().handleBackgroundNotificationResponse(response);
}

/// Coordinates Android FCM messages, call notifications, and foreground state.
///
/// Pending Answer/Reject actions are persisted briefly so they can be applied
/// after the foreground Stringee call object becomes available.
class AndroidPushManager {
  AndroidPushManager._privateConstructor() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    selectNotificationStream =
        StreamController<AndroidCallNotificationAction>.broadcast();
    androidSettings = const AndroidInitializationSettings('ic_noti');
    initializationSettings = InitializationSettings(android: androidSettings);
  }

  static AndroidPushManager? _instance;

  /// Returns the process-wide Android push manager.
  factory AndroidPushManager() {
    _instance ??= AndroidPushManager._privateConstructor();
    return _instance!;
  }

  late final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late final StreamController<AndroidCallNotificationAction>
      selectNotificationStream;
  late final AndroidInitializationSettings androidSettings;
  late final InitializationSettings initializationSettings;

  final int notificationId = 280196;
  final int inCallNotificationId = 14101997;
  final String channelId = 'stringee_incoming_call_v2';
  final String channelName = 'Incoming calls';
  final String channelDescription = 'Incoming Stringee call notifications';
  final String inCallChannelId = 'stringee_in_call_v1';
  final String inCallChannelName = 'Ongoing calls';
  final String inCallChannelDescription =
      'Keeps an active Stringee call running in the background';
  final String actionAnswer = 'action_answer';
  final String actionReject = 'action_reject';
  final String actionClickNotification = 'action_open_call';

  bool isAnswerFromPush = false;
  bool isRejectFromPush = false;
  Future<bool> Function()? callPermissionRequester;
  bool _initialized = false;
  StreamSubscription<AndroidCallNotificationAction>?
      _notificationActionSubscription;
  String _foregroundCallId = '';
  int? _connectedAtMillis;

  /// Handles one Firebase [message] and extracts its Stringee payload.
  Future<void> handleRemoteMessage(RemoteMessage message) async {
    final data = parseAndroidStringeePushData(message.data);
    if (data != null) await handleStringeePush(data);
  }

  /// Applies an already decoded Stringee push [data] payload.
  Future<void> handleStringeePush(Map<String, dynamic> data) async {
    final callStatus = data['callStatus']?.toString() ?? '';
    final callId = data['callId']?.toString() ?? '';
    if (callStatus == 'started') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final accessToken = prefs.getString(androidStringeeAccessTokenKey) ?? '';
      if (accessToken.isEmpty) {
        await cleanupCall(callId: callId);
        return;
      }
      final from = _asStringMap(data['from']);
      await showIncomingCallNotification(
        from['alias']?.toString() ?? '',
        from['number']?.toString() ?? '',
        callId: callId,
        isVideo: isAndroidVideoCallPush(data),
      );
      return;
    }
    if (isTerminalAndroidStringeePush(data)) {
      await cleanupCall(callId: callId);
    }
  }

  /// Shows the full-screen incoming-call notification for [callId].
  Future<void> showIncomingCallNotification(
    String fromAlias,
    String from, {
    required String callId,
    bool isVideo = false,
  }) async {
    final caller = fromAlias.isEmpty ? from : fromAlias;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_incomingNotificationCallIdKey, callId);
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
      ticker: 'Incoming call from $caller',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          actionAnswer,
          'Answer',
          titleColor: Colors.green,
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionReject,
          'Reject',
          titleColor: Colors.redAccent,
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    await flutterLocalNotificationsPlugin.show(
      notificationId,
      isVideo ? 'Incoming video call' : 'Incoming call',
      caller,
      NotificationDetails(android: androidDetails),
      payload: callId,
    );
    await prefs.reload();
    final currentCallId = prefs.getString(_incomingNotificationCallIdKey);
    if (currentCallId != callId) {
      await flutterLocalNotificationsPlugin.cancel(notificationId);
    }
  }

  /// Cancels the incoming notification when it belongs to [callId].
  ///
  /// An empty [callId] cancels whichever incoming notification is active.
  Future<void> cancelIncomingCallNotification({String callId = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final currentCallId = prefs.getString(_incomingNotificationCallIdKey) ?? '';
    if (callId.isNotEmpty &&
        currentCallId.isNotEmpty &&
        callId != currentCallId) {
      return;
    }
    await flutterLocalNotificationsPlugin.cancel(notificationId);
    await prefs.remove(_incomingNotificationCallIdKey);
  }

  /// Requests full-screen intent permission on Android versions that require it.
  Future<void> requestFullScreenIntentPermissionIfNeeded() async {
    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestFullScreenIntentPermission();
  }

  /// Starts the ongoing Android foreground service for [call].
  Future<void> startInCallService(StringeeCallModel call) async {
    _foregroundCallId = call.call.callId ?? '';
    _connectedAtMillis = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_foregroundServiceCallIdKey, _foregroundCallId);
    await _showInCallService(call, connected: false);
  }

  /// Marks [call] media as connected and starts its notification chronometer.
  Future<void> markCallConnected(StringeeCallModel call) async {
    final callId = call.call.callId ?? '';
    if (_foregroundCallId.isNotEmpty && _foregroundCallId != callId) return;
    _foregroundCallId = callId;
    _connectedAtMillis ??= DateTime.now().millisecondsSinceEpoch;
    await _showInCallService(call, connected: true);
  }

  Future<void> _showInCallService(
    StringeeCallModel call, {
    required bool connected,
  }) async {
    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    final caller = call.callee ?? call.call.from ?? call.call.to ?? 'Unknown';
    final details = AndroidNotificationDetails(
      inCallChannelId,
      inCallChannelName,
      channelDescription: inCallChannelDescription,
      importance: Importance.low,
      priority: Priority.low,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      ongoing: true,
      autoCancel: false,
      silent: true,
      playSound: false,
      enableVibration: false,
      onlyAlertOnce: true,
      usesChronometer: connected,
      when: connected ? _connectedAtMillis : null,
    );
    try {
      await androidPlugin.startForegroundService(
        inCallNotificationId,
        caller,
        connected ? 'Call in progress' : 'Connecting call…',
        notificationDetails: details,
        payload: call.call.callId ?? '',
        foregroundServiceTypes: const {
          AndroidServiceForegroundType.foregroundServiceTypeMicrophone,
        },
      );
    } catch (error) {
      debugPrint('Unable to start Android in-call service: $error');
    }
  }

  /// Stops the ongoing service when it belongs to [callId].
  Future<void> stopInCallService({String callId = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final persistedCallId =
        prefs.getString(_foregroundServiceCallIdKey) ?? _foregroundCallId;
    if (callId.isNotEmpty &&
        persistedCallId.isNotEmpty &&
        callId != persistedCallId) {
      return;
    }
    final androidPlugin =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidPlugin?.stopForegroundService();
    } catch (error) {
      debugPrint('Unable to stop Android in-call service: $error');
    } finally {
      _foregroundCallId = '';
      _connectedAtMillis = null;
      await prefs.remove(_foregroundServiceCallIdKey);
    }
  }

  /// Initializes notification channels and captures the app-launch action.
  Future<void> handleNotificationAction() async {
    if (_initialized) return;
    _initialized = true;
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleForegroundResponse,
      onDidReceiveBackgroundNotificationResponse:
          androidCallNotificationBackgroundAction,
    );

    final launchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      await _queueResponse(launchResponse);
    }
  }

  void _handleForegroundResponse(NotificationResponse response) {
    unawaited(_queueResponse(response));
  }

  Future<void> _queueResponse(NotificationResponse response) async {
    final action = _actionFromResponse(response);
    final event = AndroidCallNotificationAction(
      action: action,
      callId: response.payload ?? '',
    );
    if (action == actionAnswer || action == actionReject) {
      await _persistPendingAction(event);
    }
    selectNotificationStream.add(event);
  }

  /// Persists an action received while the Flutter UI isolate was unavailable.
  Future<void> handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) async {
    final event = AndroidCallNotificationAction(
      action: _actionFromResponse(response),
      callId: response.payload ?? '',
    );
    await _persistPendingAction(event);
    if (event.action == actionReject) {
      final rejected = await _rejectCallWithBackgroundClient(event.callId);
      if (rejected) {
        await cleanupCall(callId: event.callId);
      }
    }
  }

  /// Listens for notification actions and applies them to active calls.
  Future<void> listenNotificationSelect() async {
    if (_notificationActionSubscription != null) return;
    _notificationActionSubscription = selectNotificationStream.stream.listen((
      event,
    ) async {
      final call = StringeeCallManager().callWithCallId(event.callId);
      if (call == null) return;
      await _applyAction(call, event);
    });
  }

  /// Reconciles a notification action that arrived before the Stringee socket
  /// emitted its incoming-call object.
  /// Reconciles a pending Answer/Reject action with an incoming SDK [call].
  ///
  /// Returns whether the Flutter call UI should still be presented.
  Future<bool> reconcileIncomingCall(StringeeCallModel call) async {
    final pending = await _readPendingAction();
    if (pending == null ||
        !doesAndroidCallIdMatch(pending.callId, call.call.callId)) {
      return true;
    }
    await _clearPendingAction();
    if (pending.action == actionAnswer) {
      isAnswerFromPush = true;
      await cancelIncomingCallNotification(callId: call.call.callId ?? '');
      return true;
    }
    await _applyAction(call, pending);
    return pending.action != actionReject;
  }

  Future<void> _applyAction(
    StringeeCallModel call,
    AndroidCallNotificationAction event,
  ) async {
    if (event.action == actionReject) {
      isRejectFromPush = false;
      await call.rejectCall();
      await cleanupCall(callId: call.call.callId ?? '');
    } else if (event.action == actionAnswer) {
      await cancelIncomingCallNotification(callId: call.call.callId ?? '');
      final requestPermissions = callPermissionRequester;
      if (requestPermissions == null) {
        isAnswerFromPush = true;
        return;
      }
      final hasPermissions = await requestPermissions();
      isAnswerFromPush = false;
      if (hasPermissions) {
        await call.answerCall();
      } else {
        await call.rejectCall();
      }
    }
  }

  /// Clears notification, foreground-service, and pending-action state.
  Future<void> cleanupCall({String callId = ''}) async {
    await cancelIncomingCallNotification(callId: callId);
    await stopInCallService(callId: callId);
    final pending = await _readPendingAction();
    if (pending != null &&
        (callId.isEmpty || doesAndroidCallIdMatch(pending.callId, callId))) {
      await _clearPendingAction();
      isAnswerFromPush = false;
      isRejectFromPush = false;
    }
    if (callId.isEmpty) {
      isAnswerFromPush = false;
      isRejectFromPush = false;
    }
  }

  /// Clears all Android call state during disconnect or logout.
  Future<void> cleanupForDisconnect() async {
    await cleanupCall();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(androidStringeeAccessTokenKey);
  }

  Future<void> _persistPendingAction(
    AndroidCallNotificationAction event,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingActionKey, event.action);
    await prefs.setString(_pendingActionCallIdKey, event.callId);
    await prefs.setInt(
      _pendingActionCreatedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    isAnswerFromPush = event.action == actionAnswer;
    isRejectFromPush = event.action == actionReject;
  }

  Future<AndroidCallNotificationAction?> _readPendingAction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final action = prefs.getString(_pendingActionKey) ?? '';
    if (action.isEmpty) return null;
    final createdAt = prefs.getInt(_pendingActionCreatedAtKey) ?? 0;
    final isExpired = isPendingAndroidCallActionExpired(
      createdAtMillis: createdAt,
      now: DateTime.now(),
    );
    if (isExpired) {
      await _clearPendingAction();
      return null;
    }
    return AndroidCallNotificationAction(
      action: action,
      callId: prefs.getString(_pendingActionCallIdKey) ?? '',
    );
  }

  Future<void> _clearPendingAction() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingActionKey);
    await prefs.remove(_pendingActionCallIdKey);
    await prefs.remove(_pendingActionCreatedAtKey);
  }

  Future<bool> _rejectCallWithBackgroundClient(String targetCallId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final accessToken = prefs.getString(androidStringeeAccessTokenKey) ?? '';
    if (accessToken.isEmpty) return false;

    final client = StringeeClient();
    final result = Completer<bool>();
    late final StreamSubscription<dynamic> subscription;
    subscription = client.eventStreamController.stream.listen((rawEvent) async {
      final event = rawEvent as Map<dynamic, dynamic>;
      try {
        switch (event['eventType']) {
          case StringeeClientEvents.incomingCall:
            final call = event['body'] as StringeeCall;
            if (!doesAndroidCallIdMatch(targetCallId, call.id)) return;
            await call.initAnswer();
            final response = await call.reject();
            if (!result.isCompleted) {
              result.complete(response['status'] == true);
            }
            break;
          case StringeeClientEvents.incomingCall2:
            final call = event['body'] as StringeeCall2;
            if (!doesAndroidCallIdMatch(targetCallId, call.id)) return;
            await call.initAnswer();
            final response = await call.reject();
            if (!result.isCompleted) {
              result.complete(response['status'] == true);
            }
            break;
          case StringeeClientEvents.didFailWithError:
            if (!result.isCompleted) result.complete(false);
            break;
        }
      } catch (_) {
        if (!result.isCompleted) result.complete(false);
      }
    });

    try {
      await client.connect(accessToken);
      return await result.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    } finally {
      await client.disconnect();
      await subscription.cancel();
    }
  }

  String _actionFromResponse(NotificationResponse response) {
    if (response.notificationResponseType ==
        NotificationResponseType.selectedNotification) {
      return actionClickNotification;
    }
    return response.actionId ?? actionClickNotification;
  }

  Map<String, dynamic> _asStringMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  /// Cancels local subscriptions and closes the action stream.
  Future<void> release() async {
    await _notificationActionSubscription?.cancel();
    _notificationActionSubscription = null;
  }
}
