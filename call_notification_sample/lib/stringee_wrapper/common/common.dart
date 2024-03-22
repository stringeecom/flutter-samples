import 'dart:io';

const int notificationId = 123456;
const String channelId = 'channel_id';
const String channelName = 'Channel name';
const String channelDescription = 'Channel description';
const String actionAnswer = 'action_answer';
const String actionReject = 'action_reject';

const String serverClientName = 'com.stringee.client';
const String serverPushName = 'com.stringee.firebase';
const String actionClickNotification = 'com.stringee.click_notification';
const String actionAnswerFromNotification = 'com.stringee.answer_from_notification';
const String actionRejectFromNotification = 'com.stringee.reject_from_notification';
const String actionRelease = 'release_client';

bool isInCall = false;
bool isAppInBackground = false;
bool isIOS = Platform.isIOS;

bool isStringEmpty(String? s) {
  if (s == null) {
    return true;
  } else {
    return s.isEmpty;
  }
}
