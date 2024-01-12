import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ios_call_notification_sample/managers/android_call_manager.dart';
import 'package:ios_call_notification_sample/managers/ios_call_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'managers/instance_manager.dart' as InstanceManager;
import 'screens/call_screen.dart';

var user1 = 'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZULTE3MDQ4NzA5NjUiLCJpc3MiOiJTS0UxUmRVdFVhWXhOYVFRNFdyMTVxRjF6VUp1UWRBYVZUIiwiZXhwIjoxNzA3NDYyOTY1LCJ1c2VySWQiOiJ1c2VyMiJ9.mwTaBHF587wsXiwThcNJ916ztkri2EW49AfSxr0Wraw';

String toUserId = "";
bool isAndroid = Platform.isAndroid;
bool showIncomingCall = false;
AndroidCallManager? _androidCallManager = AndroidCallManager.shared;
IOSCallManager? _iOSCallManager = IOSCallManager.shared;

/// Nhận và hiện notification khi app ở dưới background hoặc đã bị kill ở android
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage remoteMessage) async {
  await Firebase.initializeApp().whenComplete(() {
    print("Handling a background message: ${remoteMessage.data}");

    Map<dynamic, dynamic> _notiData = remoteMessage.data;
    Map<dynamic, dynamic> _data = json.decode(_notiData['data']);
    FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    if (_data['callStatus'] == 'started') {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@drawable/ic_noti');
      final InitializationSettings initializationSettings =
          InitializationSettings(android: androidSettings);

      flutterLocalNotificationsPlugin
          .initialize(initializationSettings)
          .then((value) async {
        if (value!) {
          /// Create channel for notification
          const AndroidNotificationDetails androidPlatformChannelSpecifics =
              AndroidNotificationDetails(
            'your channel id', 'your channel name',
            channelDescription: 'your channel description',
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.call,

            /// Set true for show App in lockScreen
            fullScreenIntent: true,
          );
          const NotificationDetails platformChannelSpecifics =
              NotificationDetails(android: androidPlatformChannelSpecifics);

          /// Show notification
          await flutterLocalNotificationsPlugin.show(
            1234,
            'Incoming Call from ${_data['from']['alias']}',
            _data['from']['number'],
            platformChannelSpecifics,
          );
        }
      });
    } else if (_data['callStatus'] == 'ended') {
      flutterLocalNotificationsPlugin.cancel(1234);
    }
  });
}

main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (isAndroid)
    Firebase.initializeApp().whenComplete(() {
      print("completed");
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
    });
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call Notification Sample',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String? myUserId = "";

  @override
  void initState() {
    super.initState();

    if (isAndroid) {
      _androidCallManager!.setContext(context);

      ///cấp quyền truy cập với android
      requestPermissions();
    } else {
      /// Cấu hình thư viện để nhận push notification và sử dụng Callkit để show giao diện call native của iOS
      _iOSCallManager!.configureCallKeep();
    }

    /// Lắng nghe sự kiện của StringeeClient(kết nối, cuộc gọi đến...)
    InstanceManager.client.eventStreamController.stream.listen((event) {
      Map<dynamic, dynamic> map = event;
      switch (map['eventType']) {
        case StringeeClientEvents.didConnect:
          handleDidConnectEvent();
          break;
        case StringeeClientEvents.didDisconnect:
          handleDiddisconnectEvent();
          break;
        case StringeeClientEvents.didFailWithError:
          handleDidFailWithErrorEvent(
              map['body']['code'], map['body']['message']);
          break;
        case StringeeClientEvents.requestAccessToken:
          handleRequestAccessTokenEvent();
          break;
        case StringeeClientEvents.didReceiveCustomMessage:
          handleDidReceiveCustomMessageEvent(map['body']);
          break;
        case StringeeClientEvents.incomingCall:
          StringeeCall? call = map['body'];
          if (isAndroid) {
            _androidCallManager!.handleIncomingCallEvent(call!, context);
          } else {
            _iOSCallManager!.handleIncomingCallEvent(call!, context);
          }
          break;
        case StringeeClientEvents.incomingCall2:
          StringeeCall2? call = map['body'];
          if (isAndroid) {
            _androidCallManager!.handleIncomingCall2Event(call!, context);
          } else {
            _iOSCallManager!.handleIncomingCall2Event(call!, context);
          }
          break;
        default:
          break;
      }
    });

    InstanceManager.client.connect(user1);
  }

  requestPermissions() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    List<Permission> permissions = [
      Permission.camera,
      Permission.microphone,
    ];
    if (androidInfo.version.sdkInt >= 31) {
      permissions.add(Permission.bluetoothConnect);
    }
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    print(statuses);

    if (androidInfo.version.sdkInt >= 33) {
      // Register permission for show notification in android 13
      FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()!
          .requestPermission();
    }
  }

  Future<void> registerPushWithStringeeServer() async {
    if (isAndroid) {
      Stream<String> tokenRefreshStream =
          FirebaseMessaging.instance.onTokenRefresh;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool? registered = (prefs.getBool("register") == null)
          ? false
          : prefs.getBool("register");

      ///kiểm tra đã register push chưa
      if (registered != null && !registered) {
        FirebaseMessaging.instance.getToken().then((token) {
          InstanceManager.client.registerPush(token!).then((value) {
            print('Register push ' + value['message']);
            if (value['status']) {
              prefs.setBool("register", true);
              prefs.setString("token", token);
            }
          });
        });
      }

      ///Nhận token mới từ firebase
      tokenRefreshStream.listen((token) {
        ///Xóa token cũ
        InstanceManager.client
            .unregisterPush(prefs.getString("token")!)
            .then((value) {
          print('Unregister push ' + value['message']);
          if (value['status']) {
            ///Register với token mới
            prefs.setBool("register", false);
            prefs.remove("token");
            InstanceManager.client.registerPush(token).then((value) {
              print('Register push ' + value['message']);
              if (value['status']) {
                prefs.setBool("register", true);
                prefs.setString("token", token);
              }
            });
          }
        });
      });
    } else {
      _iOSCallManager!.registerPushWithStringeeServer();
    }
  }

  /// StringeeClient Listeners
  ///
  void handleDidConnectEvent() {
    print("handleDidConnectEvent");
    if (!isAndroid) {
      _iOSCallManager!.startTimeoutForIncomingCall();
    }

    setState(() {
      myUserId = InstanceManager.client.userId;
    });

    registerPushWithStringeeServer();
  }

  void handleDiddisconnectEvent() {
    print("handleDiddisconnectEvent");
    if (!isAndroid) {
      _iOSCallManager!.stopTimeoutForIncomingCall();
    }

    setState(() {
      myUserId = 'Not connected';
    });
  }

  void handleDidFailWithErrorEvent(int? code, String message) {
    print('code: ' + code.toString() + ', message: ' + message);
  }

  void handleRequestAccessTokenEvent() {
    print('Request new access token');
  }

  void handleDidReceiveCustomMessageEvent(Map<dynamic, dynamic> map) {
    print('from: ' + map['fromUserId'] + '\nmessage: ' + map['message']);
  }

  @override
  Widget build(BuildContext context) {
    Widget topText = new Container(
      padding: EdgeInsets.only(left: 10.0, top: 10.0),
      child: new Text(
        'Connected as: $myUserId',
        style: new TextStyle(
          color: Colors.black,
          fontSize: 20.0,
        ),
      ),
    );

    return new Scaffold(
      appBar: new AppBar(
        title: new Text("OneToOneCallSample"),
        backgroundColor: Colors.indigo[600],
      ),
      body: new Stack(
        children: <Widget>[topText, new ActionForm()],
      ),
    );
  }
}

class ActionForm extends StatefulWidget {
  @override
  _ActionFormState createState() => _ActionFormState();
}

class _ActionFormState extends State<ActionForm> {
  @override
  Widget build(BuildContext context) {
    return new Form(
//      key: _formKey,
      child: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          new Container(
            padding: EdgeInsets.all(20.0),
            child: new TextField(
              onChanged: (String value) {
                toUserId = value;
              },
              decoration: InputDecoration(
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.red),
                  ),
                  hintText: 'to'),
            ),
          ),
          new Container(
              margin: EdgeInsets.only(top: 20.0),
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: [
                  new Container(
                    height: 40.0,
                    width: 150.0,
                    child: new ElevatedButton(
                      onPressed: () {
                        callTapped(false, false);
                      },
                      child: Text('CALL'),
                    ),
                  ),
                  new Container(
                    height: 40.0,
                    width: 150.0,
                    child: new ElevatedButton(
                      onPressed: () {
                        callTapped(true, false);
                      },
                      child: Text('VIDEOCALL'),
                    ),
                  ),
                ],
              )),
          new Container(
              margin: EdgeInsets.only(top: 20.0),
              child: new Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                mainAxisSize: MainAxisSize.max,
                children: [
                  new Container(
                    height: 40.0,
                    width: 150.0,
                    child: new ElevatedButton(
                      onPressed: () {
                        callTapped(false, true);
                      },
                      child: Text('CALL2'),
                    ),
                  ),
                  new Container(
                    height: 40.0,
                    width: 150.0,
                    child: new ElevatedButton(
                      onPressed: () {
                        callTapped(true, true);
                      },
                      child: Text('VIDEOCALL2'),
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  void callTapped(bool isVideo, bool useCall2) {
    if (toUserId.isEmpty || !InstanceManager.client.hasConnected) return;

    GlobalKey<CallScreenState> callScreenKey = GlobalKey<CallScreenState>();
    if (isAndroid) {
      _androidCallManager!.callScreenKey = callScreenKey;
    } else {
      _iOSCallManager!.callScreenKey = callScreenKey;
    }

    CallScreen callScreen = CallScreen(
      key: callScreenKey,
      fromUserId: InstanceManager.client.userId,
      toUserId: toUserId,
      isVideo: isVideo,
      useCall2: useCall2,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => callScreen),
    );
  }
}
