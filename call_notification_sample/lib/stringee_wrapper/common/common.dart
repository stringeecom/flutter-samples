import 'dart:io';

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
