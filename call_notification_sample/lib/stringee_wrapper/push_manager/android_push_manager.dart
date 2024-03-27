import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../wrapper/call_wrapper.dart';

class AndroidPushManager {
  late final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  late final StreamController<String?> selectNotificationStream;
  late final AndroidInitializationSettings androidSettings;
  late final InitializationSettings initializationSettings;

  AndroidPushManager._privateConstructor() {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    selectNotificationStream = StreamController<String?>.broadcast();
    androidSettings = AndroidInitializationSettings('ic_noti');
    initializationSettings = InitializationSettings(android: androidSettings);
  }

  static AndroidPushManager? _instance;

  factory AndroidPushManager() {
    _instance ??= AndroidPushManager._privateConstructor();
    return _instance!;
  }

  int notificationId = 123456;
  String channelId = 'channel_id';
  String channelName = 'Channel name';
  String channelDescription = 'Channel description';
  String actionAnswer = 'action_answer';
  String actionReject = 'action_reject';
  String actionClickNotification = 'com.stringee.click_notification';
  String actionAnswerFromNotification = 'com.stringee.answer_from_notification';
  String actionRejectFromNotification = 'com.stringee.reject_from_notification';

  bool isAnswerFromPush = false;
  bool isRejectFromPush = false;

  Future<void> showIncomingCallNotification(Map<dynamic, dynamic> data) async {
    /// Create channel for notification
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId, channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
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
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ],

      /// Set true for show App in lockScreen
      fullScreenIntent: true,
    );
    NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    /// Show notification
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      'Incoming Call from ${data['from']['alias']}',
      data['from']['number'],
      platformChannelSpecifics,
    );
  }

  Future<void> cancelIncomingCallNotification() async {
    flutterLocalNotificationsPlugin.cancel(notificationId);
  }

  void handleNotificationAction() async {
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails != null) {
      if (notificationAppLaunchDetails.notificationResponse != null) {
        if (notificationAppLaunchDetails.didNotificationLaunchApp) {
          debugPrint(
              'notificationAppLaunchDetails - ${notificationAppLaunchDetails.notificationResponse!.notificationResponseType.name}');
          switch (notificationAppLaunchDetails
              .notificationResponse!.notificationResponseType) {
            case NotificationResponseType.selectedNotification:
              debugPrint(
                  'selectedNotification - ${notificationAppLaunchDetails.notificationResponse!.id}');
              break;
            case NotificationResponseType.selectedNotificationAction:
              debugPrint(
                  'selectedNotificationAction - ${notificationAppLaunchDetails.notificationResponse!.actionId}');
              // Handle click button answer notification when app killed
              if (notificationAppLaunchDetails.notificationResponse!.actionId ==
                  actionAnswer) {
                isAnswerFromPush = true;
              }
              if (notificationAppLaunchDetails.notificationResponse!.actionId ==
                  actionReject) {
                isRejectFromPush = true;
              }
              break;
          }
        } else {
          debugPrint(
              'selectedNotificationAction - ${notificationAppLaunchDetails.notificationResponse!.actionId}');
        }
      }
    }

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
        debugPrint('onDidReceiveNotificationResponse');
        switch (notificationResponse.notificationResponseType) {
          case NotificationResponseType.selectedNotification:
            // handle click on notification when app in background
            selectNotificationStream.add(actionClickNotification);
            break;
          case NotificationResponseType.selectedNotificationAction:
            // handle click button answer on notification when app in background
            debugPrint(
                'onDidReceiveNotificationResponse - selectedNotificationAction - ${notificationResponse.actionId}');
            if (notificationResponse.actionId == actionAnswer) {
              selectNotificationStream.add(actionAnswerFromNotification);
            }
            if (notificationResponse.actionId == actionReject) {
              selectNotificationStream.add(actionRejectFromNotification);
            }
            break;
        }
      },
    );
  }

  Future<void> listenNotificationSelect() async {
    selectNotificationStream.stream.listen((String? action) async {
      debugPrint('selectNotificationStream: action - $action');
      if (action == actionRejectFromNotification) {
        CallWrapper().endCall(false);
      } else if (action == actionAnswerFromNotification) {
        CallWrapper().answer();
      }
    });
  }

  void release() {
    selectNotificationStream.close();
  }
}
