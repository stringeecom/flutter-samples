import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'firebase_options.dart';
import 'stringee_wrapper/wrapper/stringee_wrapper.dart';

bool _initialized = false;

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage remoteMessage) async {
  if (!_initialized) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
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
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      /// Show notification
      await flutterLocalNotificationsPlugin.show(
        notificationId,
        'Incoming Call from ${data['from']['alias']}',
        data['from']['number'],
        platformChannelSpecifics,
      );
    } else if (data['callStatus'] == 'ended') {
      flutterLocalNotificationsPlugin.cancel(notificationId);
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
  if (!isIOS) {
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
    if (!_initialized) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
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
  String _to = "";
  String _userId = "";
  String _token =
      'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZULTE3MTA5ODgyMzI3NjAiLCJpc3MiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZUIiwidXNlcklkIjoidXNlcjQiLCJleHAiOjE3NDI1MjQyMzJ9.YJ3-FrSIEajmt6cVayrUOCJQiN3tNXO7A38LE-0IiPY';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("didChangeAppLifecycle - $state");
    if (state == AppLifecycleState.resumed) {
      flutterLocalNotificationsPlugin.cancel(notificationId);
      isAppInBackground = false;
    } else if (state == AppLifecycleState.inactive) {
      isAppInBackground = true;
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

    if (!isIOS) {
      selectNotificationStream.stream.listen((String? action) async {
        debugPrint('selectNotificationStream: action - $action');
        if (action == actionRejectFromNotification) {
          CallWrapper().endCall(false);
        } else if (action == actionAnswerFromNotification) {
          CallWrapper().answer();
        }
      });
    }
    initAndConnectClient();
  }

  void initAndConnectClient() async {
    if (!isIOS) {
      await StringeeWrapper().requestPermissions();
    }
    StringeeWrapper().registerEvent(StringeeListener(
      onConnected: (userId) {
        setState(() {
          _connectStatus = 'Connected as $userId';
          _userId = userId;
        });
        if (isIOS) {
          StringeeWrapper().registerPush(
              CallkeepManager.shared?.pushToken ?? '',
              isVoip: true,
              isProduction: false);
        } else {
          FirebaseMessaging.instance.getToken().then((token) {
            StringeeWrapper().registerPush(token!);
          });
        }
      },
      onDisconnected: () {
        setState(() {
          _connectStatus = 'Disconnected';
        });
      },
      onConnectError: (code, message) {
        setState(() {
          _connectStatus = 'Connect fail: $message';
        });
      },
      onRequestNewToken: () {
        /// Get new token from server
        /// After that, call method connect again
        /// Example:
        /// String newToken = await getNewToken();
        /// StringeeWrapper().connect(newToken);
      },
      onCallSignalingStateChange: (StringeeSignalingState signalingState) {
        debugPrint('onCallSignalingStateChange: $signalingState');
      },
      onCallMediaStateChane: (StringeeMediaState mediaState) {
        debugPrint('onCallMediaStateChane: $mediaState');
      },
      onShowCallWidget: () {
        debugPrint('onShowCallWidget');
        if (isIOS) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => new CallWidget(),
            ),
          );
        } else {
          StringeeWrapper().requestPermissions().then((value) {
            if (value) {
              if (isRejectFromPush) {
                CallWrapper().endCall(false);
                isRejectFromPush = false;
              } else if (isAnswerFromPush) {
                CallWrapper().answer();
                isAnswerFromPush = false;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => new CallWidget(),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => new CallWidget(),
                  ),
                );
              }
            } else {
              CallWrapper().endCall(false);
            }
          });
        }
      },
      onCallWidgetDismiss: () {
        debugPrint('onCallWidgetDismiss');
      },
    ));
    StringeeWrapper().connect(_token);
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
                        CustomButton(
                          text: 'Voice call',
                          onPressed: () {
                            _callTapped(false);
                          },
                        ),
                        CustomButton(
                          text: 'Video call',
                          onPressed: () {
                            _callTapped(true);
                          },
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

  void _callTapped(bool isVideoCall) {
    if (_to.isEmpty || !StringeeWrapper().hasConnected()) {
      return;
    }
    StringeeWrapper().makeCall(
        _userId,
        _to,
        isVideoCall,
        new CallBackListener(
          onSuccess: ({result}) {
            debugPrint('makeCall success');
          },
          onError: (String error) {
            debugPrint('makeCall error: $error');
          },
        ));
  }
}

class CustomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final EdgeInsetsGeometry? margin;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40.0,
      width: 175.0,
      margin: margin,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }
}
