import 'package:flutter/material.dart';
import 'package:ios_call_notification_sample/call_manager.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';
import 'call_screen.dart';
import 'package:flutter_voip_push_notification/flutter_voip_push_notification.dart';
import 'package:flutter_call_kit/flutter_call_kit.dart';
import 'package:uuid/uuid.dart';
import 'sync_call.dart';

var user1 = 'YOUR_USER1_ACCESS_TOKEN';
var user2 = 'YOUR_USER2_ACCESS_TOKEN';

StringeeClient _client = StringeeClient();
String toUserId = "";

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iOS Call Notification Sample',
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
  void initState() {

    // TODO: implement initState
    super.initState();

    /// Cấu hình thư viện để nhận voip notification
    configureVoipNotificationLibrary();
    
    /// Cấu hình thư viện để xử dụng Callkit show giao diện call native của iOS
    CallManager.shared.configureCallkitLibrary();

    /// Lắng nghe sự kiện của StringeeClient(kết nối, cuộc gọi đến...)
    _client.eventStreamController.stream.listen((event) {
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
          StringeeCall call = map['body'];
          CallManager.shared.handleIncomingCallEvent(call, context);
          break;
        case StringeeClientEvents.incomingCall2:
          StringeeCall2 call = map['body'];
          CallManager.shared.handleIncomingCall2Event(call, context);
          break;
        case StringeeClientEvents.didReceiveObjectChange:
          StringeeObjectChange objectChange = map['body'];
          print(objectChange.objectType.toString() +
              '\t' +
              objectChange.type.toString());
          print(objectChange.objects.toString());
          break;
        default:
          break;
      }
    });

    _client.connect(user1);
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
    CallManager.shared.handleIncomingPushNotification(payload);
    return null;
  }

  // Called to receive notification when app is resuming from background
  //
  // [isLocal] is true if its a local notification or false otherwise (remote notification)
  // [payload] the notification payload to be processed. use this to present a local notification
  Future<dynamic> onResume(bool isLocal, Map<String, dynamic> payload) {
    // handle background notification
    print("received on background payload: $payload, isLocal=$isLocal");
    CallManager.shared.handleIncomingPushNotification(payload);
    return null;
  }

  void registerPushWithStringeeServer() {
    if (registeredPushWithStringeeServer) {
      return;
    }

    if (_pushToken == null || _pushToken == '') {
      print('Push token khong hop le');
      return;
    }

    _client.registerPush(_pushToken, isProduction: true).then((result) {
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

  /// StringeeClient Listeners
  ///
  void handleDidConnectEvent() {
    print("handleDidConnectEvent");
    CallManager.shared.startTimeoutForIncomingCall();

    setState(() {
      myUserId = _client.userId;
    });

    registerPushWithStringeeServer();
  }

  void handleDiddisconnectEvent() {
    print("handleDiddisconnectEvent");
    CallManager.shared.stopTimeoutForIncomingCall();

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
                hintText: 'to'
              ),
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
    if (toUserId.isEmpty || !_client.hasConnected) return;
    CallManager.shared.callScreenKey = GlobalKey<CallScreenState>();
    CallScreen callScreen = CallScreen(key: CallManager.shared.callScreenKey, fromUserId: _client.userId, toUserId: toUserId, isVideo: isVideo);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => callScreen),
    );
  }
}
