import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ios_call_notification_sample/managers/call_manager.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call.dart';
import 'constants/constants.dart';
import 'firebase_options.dart';
import 'listener/connection_listener.dart';
import 'managers/client_manager.dart';
import 'view/main_button.dart';

bool _initialized = false;

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage remoteMessage) async {
  if (!_initialized) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    _initialized = true;
  }
  debugPrint("Handling a background message: ${remoteMessage.data}");

  Map<dynamic, dynamic> notiData = remoteMessage.data;
  Map<dynamic, dynamic> data = json.decode(notiData['data']);
  bool isStringeePush = notiData['stringeePushNotification'] == '1.0';
  if (isStringeePush) {
    if (data['callStatus'] == 'started') {
      /// Create channel for notification
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        Constants.channelId, Constants.channelName,
        channelDescription: Constants.channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.call,
        ongoing: true,
        autoCancel: false,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            Constants.actionAnswer,
            'Answer',
            titleColor: Colors.green,
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            Constants.actionReject,
            'Reject',
            titleColor: Colors.redAccent,
            cancelNotification: true,
            showsUserInterface: true,
          ),
        ],

        /// Set true for show App in lockScreen
        fullScreenIntent: true,
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      /// Show notification
      await flutterLocalNotificationsPlugin.show(
        Constants.notificationId,
        'Incoming Call from ${data['from']['alias']}',
        data['from']['number'],
        platformChannelSpecifics,
      );
    } else if (data['callStatus'] == 'ended') {
      flutterLocalNotificationsPlugin.cancel(Constants.notificationId);
    }
  }
}

@pragma('vm:entry-point')
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

final StreamController<String?> selectNotificationStream =
    StreamController<String?>.broadcast();

bool isAnswerFromPush = false;
bool isRejectFromPush = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
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
                  Constants.actionAnswer) {
                isAnswerFromPush = true;
              }
              if (notificationAppLaunchDetails.notificationResponse!.actionId ==
                  Constants.actionReject) {
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

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('ic_noti');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) {
        debugPrint('onDidReceiveNotificationResponse');
        switch (notificationResponse.notificationResponseType) {
          case NotificationResponseType.selectedNotification:
            // handle click on notification when app in background
            selectNotificationStream.add(Constants.actionClickNotification);
            break;
          case NotificationResponseType.selectedNotificationAction:
            // handle click button answer on notification when app in background
            debugPrint(
                'onDidReceiveNotificationResponse - selectedNotificationAction - ${notificationResponse.actionId}');
            if (notificationResponse.actionId == Constants.actionAnswer) {
              selectNotificationStream
                  .add(Constants.actionAnswerFromNotification);
            }
            if (notificationResponse.actionId == Constants.actionReject) {
              selectNotificationStream
                  .add(Constants.actionRejectFromNotification);
            }
            break;
        }
      },
    );
    if (!_initialized) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _initialized = true;
    }
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
        title: "OneToOneCallSample",
        debugShowCheckedModeBanner: false,
        home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  static String routeName = 'homePage';

  const MyHomePage({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  String _connectStatus = 'Not connected...';
  bool _isPermissionGranted = false;
  String _to = "";

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("didChangeAppLifecycle - $state");
    if (state == AppLifecycleState.resumed) {
      flutterLocalNotificationsPlugin.cancel(Constants.notificationId);
      ClientManager().isAppInBackground = false;
    } else if (state == AppLifecycleState.inactive) {
      ClientManager().isAppInBackground = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    selectNotificationStream.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (Platform.isAndroid) {
      selectNotificationStream.stream.listen((String? action) async {
        debugPrint('selectNotificationStream: action - $action');
        if (action == Constants.actionRejectFromNotification) {
          ClientManager().callManager!.endCall(false);
        } else {
          if (action == Constants.actionAnswerFromNotification) {
            ClientManager().callManager!.answer();
          }

          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (BuildContext context) => Call(
              isIncomingCall: true,
              isStringeeCall: ClientManager().callManager!.isStringeeCall,
            ),
          ));
        }
      });
      initAndConnectClient();
    } else {
      initAndConnectClient();
    }
  }

  void initAndConnectClient() async {
    if (Platform.isAndroid) {
      if (!_isPermissionGranted) {
        _isPermissionGranted = await requestPermissions();
      }
    }
    ClientManager().registerEvent(ConnectionListener(onConnect: (status) {
      setState(() {
        _connectStatus = status;
      });
    }, onIncomingCall: () {
      if (Platform.isIOS ||
          (_isPermissionGranted && !ClientManager().isAppInBackground)) {
        if (isRejectFromPush) {
          ClientManager().callManager!.endCall(false);
          isRejectFromPush = false;
        } else {
          if (isAnswerFromPush) {
            ClientManager().callManager!.answer();
            isAnswerFromPush = false;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Call(
                isIncomingCall: true,
                isStringeeCall: true,
              ),
            ),
          );
        }
      }
    }, onIncomingCall2: () {
      if (Platform.isIOS ||
          (_isPermissionGranted && !ClientManager().isAppInBackground)) {
        if (isRejectFromPush) {
          ClientManager().callManager!.endCall(false);
          isRejectFromPush = false;
        } else {
          if (isAnswerFromPush) {
            ClientManager().callManager!.answer();
            isAnswerFromPush = false;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Call(
                isIncomingCall: true,
                isStringeeCall: false,
              ),
            ),
          );
        }
      }
    }));
    ClientManager().connect();
  }

  Future<bool> requestPermissions() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    List<Permission> permissions = [
      Permission.camera,
      Permission.microphone,
    ];
    if (androidInfo.version.sdkInt >= 31) {
      permissions.add(Permission.bluetoothConnect);
    }
    if (androidInfo.version.sdkInt >= 33) {
      permissions.add(Permission.notification);
    }

    Map<Permission, PermissionStatus> permissionsStatus =
        await permissions.request();
    debugPrint('Permission statuses - $permissionsStatus');
    bool isAllGranted = true;
    permissionsStatus.forEach((key, value) {
      if (value != PermissionStatus.granted) {
        setState(() {
          isAllGranted = false;
        });
      }
    });
    return isAllGranted;
  }

  @override
  Widget build(BuildContext context) {
    Widget topText = Container(
      padding: const EdgeInsets.only(left: 10.0, top: 10.0),
      child: Text(
        _connectStatus,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 20.0,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Call Sample"),
        backgroundColor: Colors.indigo[600],
      ),
      body: Stack(
        children: <Widget>[
          topText,
          Form(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(20.0),
                  child: TextField(
                    onChanged: (String value) {
                      setState(() {
                        _to = value;
                      });
                    },
                    decoration: const InputDecoration(
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                      hintText: 'To',
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MainButton(
                              text: 'Call',
                              onPressed: () {
                                _callTapped(true, false);
                              },
                            ),
                            MainButton(
                              text: 'Video call',
                              margin: const EdgeInsets.only(top: 20.0),
                              onPressed: () {
                                _callTapped(true, true);
                              },
                            ),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MainButton(
                              text: 'Call 2',
                              onPressed: () {
                                _callTapped(false, false);
                              },
                            ),
                            MainButton(
                              text: 'Video call 2',
                              margin: const EdgeInsets.only(top: 20.0),
                              onPressed: () {
                                _callTapped(false, true);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _callTapped(bool isStringeeCall, bool isVideoCall) {
    if (_to.isEmpty || !ClientManager().stringeeClient!.hasConnected) return;
    if (_isPermissionGranted || Platform.isIOS) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Call(
            to: _to,
            isVideoCall: isVideoCall,
            isIncomingCall: false,
            isStringeeCall: isStringeeCall,
          ),
        ),
      );
    }
  }
}
