import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_voip_push_notification/flutter_voip_push_notification.dart';
import 'package:ios_call_notification_sample/android_call_manager.dart';
import 'package:ios_call_notification_sample/ios_call_manager.dart';
import 'package:permission/permission.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'call_screen.dart';
import 'common.dart' as common;

var user1 = 'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0xIb2NCdDl6Qk5qc1pLeThZaUVkSzRsU3NBZjhCSHpyLTE2MjQ5NDkyMzYiLCJpc3MiOiJTS0xIb2NCdDl6Qk5qc1pLeThZaUVkSzRsU3NBZjhCSHpyIiwiZXhwIjoxNjI3NTQxMjM2LCJ1c2VySWQiOiJ1c2VyMSJ9.EEovOrSqsy5v026Ejc-jSu-2kFB_qSKmEJxTt3ch32E';
var user2 = 'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0xIb2NCdDl6Qk5qc1pLeThZaUVkSzRsU3NBZjhCSHpyLTE2MjQ5NDkyNTIiLCJpc3MiOiJTS0xIb2NCdDl6Qk5qc1pLeThZaUVkSzRsU3NBZjhCSHpyIiwiZXhwIjoxNjI3NTQxMjUyLCJ1c2VySWQiOiJ1c2VyMiJ9.nZQkYar8IiIYZlUvLxeOkw8rWRbjUtPkDZm68xzaAQE';

String toUserId = "";
bool isAndroid = Platform.isAndroid;
AndroidCallManager _androidCallManager = AndroidCallManager.shared;
IOsCallManager _iOsCallManager = IOsCallManager.shared;

///Nhận và hiện notification khi app ở dưới background hoặc đã bị kill ở android
Future<void> _backgroundMessageHandler(RemoteMessage remoteMessage) async {
  print("Handling a background message: ${remoteMessage.data}");

  Map<dynamic, dynamic> _notiData = remoteMessage.data;
  Map<dynamic, dynamic> _data = json.decode(_notiData['data']);

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@drawable/ic_noti');
  final IOSInitializationSettings iOSSettings = IOSInitializationSettings();
  final MacOSInitializationSettings macOSSettings = MacOSInitializationSettings();
  final InitializationSettings initializationSettings =
      InitializationSettings(android: androidSettings, iOS: iOSSettings, macOS: macOSSettings);
  await common.localNotifications
      .initialize(
    initializationSettings,
    onSelectNotification: null,
  )
      .then((value) async {
    if (value) {
      print("Stringee notification:" + _data.toString());
      if (_data['callStatus'] == 'started') {
        /// Create channel for notification
        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'your channel id',
          'your channel name',
          'your channel description',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,

          /// Set true for show App in lockScreen
        );
        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);

        /// Show notification
        await common.localNotifications.show(
          0,
          'Incoming Call',
          'from ' + _data['from']['alias'],
          platformChannelSpecifics,
        );
      } else if (_data['callStatus'] == 'ended') {
        common.localNotifications.cancel(0);
      }
    }
  });
}

Future<void> main() async {
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
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String myUserId = "";
  String _pushToken = "";
  bool registeredPushWithStringeeServer = false;
  FlutterVoipPushNotification _voipPush = FlutterVoipPushNotification();

  @override
  Future<void> initState() {
    // TODO: implement initState
    super.initState();

    if (isAndroid) {
      _androidCallManager.setContext(context);

      ///cấp quyền truy cập với android
      requestPermissions();
    } else {
      /// Cấu hình thư viện để nhận voip notification
      configureVoipNotificationLibrary();

      /// Cấu hình thư viện để xử dụng Callkit show giao diện call native của iOS
      _iOsCallManager.configureCallkitLibrary();
    }

    /// Lắng nghe sự kiện của StringeeClient(kết nối, cuộc gọi đến...)
    common.client.eventStreamController.stream.listen((event) {
      Map<dynamic, dynamic> map = event;
      switch (map['eventType']) {
        case StringeeClientEvents.didConnect:
          handleDidConnectEvent();
          break;
        case StringeeClientEvents.didDisconnect:
          handleDiddisconnectEvent();
          break;
        case StringeeClientEvents.didFailWithError:
          handleDidFailWithErrorEvent(map['body']['code'], map['body']['message']);
          break;
        case StringeeClientEvents.requestAccessToken:
          handleRequestAccessTokenEvent();
          break;
        case StringeeClientEvents.didReceiveCustomMessage:
          handleDidReceiveCustomMessageEvent(map['body']);
          break;
        case StringeeClientEvents.incomingCall:
          StringeeCall call = map['body'];
          if (isAndroid) {
            _androidCallManager.handleIncomingCallEvent(call, context);
          } else {
            _iOsCallManager.handleIncomingCallEvent(call, context);
          }
          break;
        case StringeeClientEvents.incomingCall2:
          break;
        case StringeeClientEvents.didReceiveObjectChange:
          StringeeObjectChange objectChange = map['body'];
          print(objectChange.objectType.toString() + '\t' + objectChange.type.toString());
          print(objectChange.objects.toString());
          break;
        default:
          break;
      }
    });

    common.client.connect(user1);
  }

  requestPermissions() async {
    List<PermissionName> permissionNames = [];
    permissionNames.add(PermissionName.Camera);
    permissionNames.add(PermissionName.Contacts);
    permissionNames.add(PermissionName.Microphone);
    permissionNames.add(PermissionName.Location);
    permissionNames.add(PermissionName.Storage);
    permissionNames.add(PermissionName.State);
    permissionNames.add(PermissionName.Internet);
    var permissions = await Permission.requestPermissions(permissionNames);
    permissions.forEach((permission) {});
  }

  Future<void> registerPushWithStringeeServer() async {
    if (isAndroid) {
      Stream<String> tokenRefreshStream = FirebaseMessaging.instance.onTokenRefresh;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      bool registered = (prefs.getBool("register") == null) ? false : prefs.getBool("register");

      ///kiểm tra đã register push chưa
      if (registered != null && !registered) {
        FirebaseMessaging.instance.getToken().then((token) {
          common.client.registerPush(token).then((value) {
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
        common.client.unregisterPush(prefs.getString("token")).then((value) {
          print('Unregister push ' + value['message']);
          if (value['status']) {
            ///Register với token mới
            prefs.setBool("register", false);
            prefs.remove("token");
            common.client.registerPush(token).then((value) {
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
      if (registeredPushWithStringeeServer) {
        return;
      }

      if (_pushToken == null || _pushToken == '') {
        print('Push token khong hop le');
        return;
      }

      common.client.registerPush(_pushToken, isProduction: false).then((result) {
        bool status = result['status'];
        String message = result['message'];
        print('Result for resgister push: ' + message);
        if (status) {
          setState(() {
            registeredPushWithStringeeServer = true;
          });
        }
      });
    }
  }

  /// StringeeClient Listeners
  ///
  void handleDidConnectEvent() {
    print("handleDidConnectEvent");
    if (!isAndroid) {
      _iOsCallManager.startTimeoutForIncomingCall();
    }

    setState(() {
      myUserId = common.client.userId;
    });

    registerPushWithStringeeServer();
  }

  void handleDiddisconnectEvent() {
    print("handleDiddisconnectEvent");
    if (!isAndroid) {
      _iOsCallManager.stopTimeoutForIncomingCall();
    }

    setState(() {
      myUserId = 'Not connected';
    });
  }

  void handleDidFailWithErrorEvent(int code, String message) {
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

  /// Cac ham xu ly Push, Pushkit
  ///
  // Configures a voip push notification
  Future<void> configureVoipNotificationLibrary() async {
    // request permission (required)
    await _voipPush.requestNotificationPermissions();

    // listen to voip device token changes
    _voipPush.onTokenRefresh.listen(onToken);

    // do configure voip push
    _voipPush.configure(onMessage: onMessage, onResume: onResume);
  }

  // Called when the device token changes
  void onToken(String token) {
    // nhan duoc token tu apple thi can register voi Stringee Server
    print('onToken: ' + token);
    setState(() {
      _pushToken = token;
    });
    registerPushWithStringeeServer();
  }

  // Called to receive notification when app is in foreground
  //
  // [isLocal] is true if its a local notification or false otherwise (remote notification)
  // [payload] the notification payload to be processed. use this to present a local notification
  Future<dynamic> onMessage(bool isLocal, Map<String, dynamic> payload) {
    // handle foreground notification
    print("received on foreground payload: $payload, isLocal=$isLocal");
    _iOsCallManager.handleIncomingPushNotification(payload);
    return null;
  }

  // Called to receive notification when app is resuming from background
  //
  // [isLocal] is true if its a local notification or false otherwise (remote notification)
  // [payload] the notification payload to be processed. use this to present a local notification
  Future<dynamic> onResume(bool isLocal, Map<String, dynamic> payload) {
    // handle background notification
    print("received on background payload: $payload, isLocal=$isLocal");
    _iOsCallManager.handleIncomingPushNotification(payload);
    return null;
  }
}

class ActionForm extends StatefulWidget {
  @override
  _ActionFormState createState() => _ActionFormState();
}

class _ActionFormState extends State<ActionForm> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
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
                    child: new RaisedButton(
                      color: Colors.grey[300],
                      textColor: Colors.black,
                      onPressed: () {
                        callTapped(false);
                      },
                      child: Text('CALL'),
                    ),
                  ),
                  new Container(
                    height: 40.0,
                    width: 150.0,
                    child: new RaisedButton(
                      color: Colors.grey[300],
                      textColor: Colors.black,
                      onPressed: () {
                        callTapped(true);
                      },
                      child: Text('VIDEOCALL'),
                    ),
                  ),
                ],
              )),
        ],
      ),
    );
  }

  void callTapped(bool isVideo) {
    if (toUserId.isEmpty || !common.client.hasConnected) return;

    GlobalKey<CallScreenState> callScreenKey = GlobalKey<CallScreenState>();
    if (isAndroid) {
      _androidCallManager.callScreenKey = callScreenKey;
    } else {
      _iOsCallManager.callScreenKey = callScreenKey;
    }

    CallScreen callScreen = CallScreen(
      key: callScreenKey,
      fromUserId: common.client.userId,
      toUserId: toUserId,
      isVideo: isVideo,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => callScreen),
    );
  }
}
