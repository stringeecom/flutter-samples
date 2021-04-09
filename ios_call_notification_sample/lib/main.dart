import 'package:flutter/material.dart';
import 'package:ios_call_notification_sample/call_manager.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';
import 'call_screen.dart';
import 'package:flutter_voip_push_notification/flutter_voip_push_notification.dart';
import 'package:flutter_call_kit/flutter_call_kit.dart';
import 'package:uuid/uuid.dart';
import 'sync_call.dart';

var user1 =
    'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0xIb2NCdDl6Qk5qc1pLeThZaUVkSzRsU3NBZjhCSHpyLTE2MTc1ODgxNjciLCJpc3MiOiJTS0xIb2NCdDl6Qk5qc1pLeThZaUVkSzRsU3NBZjhCSHpyIiwiZXhwIjoxNjIwMTgwMTY3LCJ1c2VySWQiOiJ1c2VyMSJ9.14F0sVgv11z5ICSXIHGTCS78ZagZUee9XEvp3QTgdEI';
var user2 =
    'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS0xIb2NCdDl6Qk5qc1pLeThZaUVkSzRsU3NBZjhCSHpyLTE2MTc1ODgxNzkiLCJpc3MiOiJTS0xIb2NCdDl6Qk5qc1pLeThZaUVkSzRsU3NBZjhCSHpyIiwiZXhwIjoxNjIwMTgwMTc5LCJ1c2VySWQiOiJ1c2VyMiJ9.aUofeiaQ4BuCKVa_J0QPG2NEOT3jz-x7UvOcoG8SS_I';

StringeeClient _client = StringeeClient();
// StringeeCall _call;
String toUserId = "";

// SyncCall _syncCall = null;
// List<String> _fakeCallUuids = new List(); // mảng các uuid của các call được show từ callkit mà cần end ngay sau khi show thành công (xử lý cho rule mới trên iOS 13)
// List<SyncCall> _oldSyncCalls = new List(); // mảng các syncCall đã xử lý rồi, sẽ không xử lý lại nữa (xử lý cho StringeeX)

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
  // FlutterCallKit _callKit = FlutterCallKit();

  @override
  void dispose() {
    // WidgetsBinding.instance.removeObserver(this);
    // TODO: implement dispose
    super.dispose();
  }

  @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   // TODO: implement didChangeAppLifecycleState
  //   super.didChangeAppLifecycleState(state);
  //   print('didChangeAppLifecycleState = $state');
  // }

  @override
  void initState() {
    // WidgetsBinding.instance.addObserver(this);

    // TODO: implement initState
    super.initState();

    /// Cấu hình thư viện để nhận voip notification
    configureVoipNotificationLibrary();
    
    /// Cấu hình thư viện để xử dụng Callkit show giao diện call native của iOS
    // configureCallkitLibrary();
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
          print("==== incomingCall: " + CallManager.shared.syncCall.toString());
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

    _client.registerPush(_pushToken).then((result) {
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

  // /// Cac ham xu ly Callkit
  // ///
  //
  // Future<void> configureCallkitLibrary() async {
  //   _callKit.configure(
  //     IOSOptions("Stringee",
  //         imageName: '',
  //         supportsVideo: false,
  //         maximumCallGroups: 1,
  //         maximumCallsPerCallGroup: 1),
  //     didReceiveStartCallAction: didReceiveStartCallAction,
  //     performAnswerCallAction: performAnswerCallAction,
  //     performEndCallAction: performEndCallAction,
  //     didActivateAudioSession: didActivateAudioSession,
  //     didDisplayIncomingCall: didDisplayIncomingCall,
  //     didPerformSetMutedCallAction: didPerformSetMutedCallAction,
  //     didPerformDTMFAction: didPerformDTMFAction,
  //     didToggleHoldAction: didToggleHoldAction,
  //   );
  // }
  //
  // Future<void> didReceiveStartCallAction(String uuid, String handle) async {
  //   // Get this event after the system decides you can start a call
  //   // You can now start a call from within your app
  // }
  //
  // Future<void> performAnswerCallAction(String uuid) async {
  //   // Called when the user answers an incoming call
  //   print("performAnswerCallAction");
  //   if (_syncCall == null || _syncCall.uuid.isEmpty || _syncCall.uuid != uuid) {
  //     return;
  //   }
  //   _syncCall.userAnswered = true;
  //   _syncCall.answerIfConditionPassed();
  // }
  //
  // Future<void> performEndCallAction(String uuid) async {
  //   /*
  //    Được gọi khi người dùng reject (ngắt ở màn hình cuộc gọi đến) hoặc hangup (ngắt ở màn hình cuộc gọi đang diễn ra) cuộc gọi từ màn hỉnh callkit
  //    => Cần kiểm tra điều kiện để biết nên gọi hàm reject hay hangup của StringeeCall object. 2 hàm này có ý nghĩa khác nhau.
  //    **/
  //   if (_syncCall == null || _syncCall.uuid.isEmpty || _syncCall.uuid != uuid) {
  //     return;
  //   }
  //
  //   _syncCall.endedCallkit = true;
  //   _syncCall.userRejected = true;
  //
  //   if (_syncCall.stringeeCall == null || _syncCall.callStatusCode == StringeeSignalingState.busy || _syncCall.callStatusCode == StringeeSignalingState.ended) {
  //     return;
  //   }
  //
  //   // Nếu StringeeCall đã được answer thì gọi hàm hangup() nếu chưa thì reject()
  //   if (_syncCall.callAnswered) {
  //     _syncCall.stringeeCall.hangup().then((result) {
  //       String message = result['message'];
  //       print("performEndCallAction - hangup, message: " + message);
  //     });
  //   } else {
  //     _syncCall.stringeeCall.reject().then((result) {
  //       String message = result['message'];
  //       print("performEndCallAction - reject, message: " + message);
  //     });
  //   }
  //
  //   deleteSyncCallIfNeed();
  // }
  //
  // Future<void> didActivateAudioSession() async {
  //   // you might want to do following things when receiving this event:
  //   // - Start playing ringback if it is an outgoing call
  //   print("===== didActivateAudioSession");
  //   if (_syncCall == null) {
  //     return;
  //   }
  //   _syncCall.audioSessionActived = true;
  //   _syncCall.answerIfConditionPassed();
  // }
  //
  // Future<void> didDisplayIncomingCall(String error, String uuid, String handle,
  //     String localizedCallerName, bool fromPushKit) async {
  //   // You will get this event after RNCallKeep finishes showing incoming call UI
  //   // You can check if there was an error while displaying
  //   print("didDisplayIncomingCall: " + uuid);
  //   endFakeCall(uuid);
  //   deleteSyncCallIfNeed();
  // }
  //
  // Future<void> didPerformSetMutedCallAction(bool mute, String uuid) async {
  //   // Called when the system or user mutes a call
  // }
  //
  // Future<void> didPerformDTMFAction(String digit, String uuid) async {
  //   // Called when the system or user performs a DTMF action
  // }
  //
  // Future<void> didToggleHoldAction(bool hold, String uuid) async {
  //   // Called when the system or user holds a call
  // }

  // void handleIncomingPushNotification(Map<String, dynamic> payload) {
  //   String callId = payload["callId"];
  //   String callStatus = payload["callStatus"];
  //   String uuid = payload["uuid"];
  //   int serial = payload["serial"];
  //
  //   // call khong hop le => can end o day
  //   if (callId.isEmpty || callStatus != "started") {
  //     _fakeCallUuids.add(uuid);
  //     endFakeCall(uuid);
  //     return;
  //   }
  //
  //   // call da duoc xu ly roi thi ko xu ly lai => can end callkit da duoc show ben native
  //   if (checkIfCallIsHandledOrNot(callId, serial)) {
  //     _callKit.endCall(uuid);
  //     removeSyncCallFromHandledCallList(callId, serial);
  //     deleteSyncCallIfNeed();
  //     return;
  //   }
  //
  //   // Chưa có sync call (Trường hợp cuộc gọi mới) => tạo sync call và lưu lại thông tin
  //   if (_syncCall == null) {
  //     _syncCall = new SyncCall();
  //     _syncCall.callId = callId;
  //     _syncCall.serial = serial;
  //     _syncCall.uuid = uuid;
  //     return;
  //   }
  //
  //   // Đã có sync call nhưng là của cuộc gọi khác => end callkit này (callkit vừa được show bên native)
  //   if (!_syncCall.isThisCall(callId, serial)) {
  //     print('END CALLKIT KHI NHAN DUOC PUSH, PUSH MOI KHONG PHAI SYNC CALL');
  //     _callKit.endCall(uuid);
  //     return;
  //   }
  //
  //   // Đã có sync call, thông tin cuộc gọi là trùng khớp, nhưng đã show callkit rồi => end callkit vừa show
  //   if (_syncCall.showedCallkit() && _syncCall.uuid != uuid) {
  //     print('END CALLKIT KHI NHAN DUOC PUSH, SYNC CALL DA SHOW CALLKIT');
  //     _callKit.endCall(uuid);
  //   }
  // }
  //
  // void handleIncomingCallEvent(StringeeCall call) {
  //   // Chưa có sync call thì tạo mới
  //   if (_syncCall == null) {
  //     _syncCall = SyncCall();
  //     _syncCall.attachCall(call);
  //     _syncCall.uuid = genUUID();
  //
  //     // Show callkit
  //     _callKit.displayIncomingCall(_syncCall.uuid, call.from, call.fromAlias);
  //
  //     // Show callScreen
  //     CallScreen callScreen = CallScreen(fromUserId: call.from, toUserId: call.to, call: call, isVideo: call.isVideoCall);
  //     Navigator.push(
  //       context,
  //       MaterialPageRoute(builder: (context) => callScreen),
  //     );
  //
  //     call.initAnswer().then((result) {
  //       String message = result['message'];
  //       print("initAnswer: " + message);
  //     });
  //     _syncCall.answerIfConditionPassed();
  //
  //     return;
  //   }
  //
  //   // Cuộc gọi mới không phải là cuộc gọi đang xử lý thì reject
  //   if (!_syncCall.isThisCall(call.id, call.serial)) {
  //     call.reject();
  //     return;
  //   }
  //
  //   // Người dùng đã click reject cuộc gọi thì reject
  //   if (_syncCall.userRejected) {
  //     call.reject();
  //     return;
  //   }
  //
  //   // Chưa show callkit thì show không thì update thông tin người gọi lên giao diện
  //   _syncCall.attachCall(call);
  //   if (_syncCall.uuid.isEmpty) {
  //     _syncCall.uuid = genUUID();
  //     _callKit.displayIncomingCall(_syncCall.uuid, call.from, call.fromAlias);
  //   } else {
  //     _callKit.updateDisplay(_syncCall.uuid, call.from, call.fromAlias);
  //   }
  //   call.initAnswer();
  //   _syncCall.answerIfConditionPassed();
  // }
  //
  // void showFakeCall() {
  //   /*
  //     Rule mới của Apple trên iOS 13 là bắt buộc show Callkit khi nhận được push từ Pushkit.
  //     Trong một số trường hợp call không hợp lệ lẽ ra không xử lý nhưng vẫn cần show callkit.
  //     => Phương án: show lên 1 call đến callkit show đó end call luôn.
  //     Note: Thực hiện end fake call trong callback 'didDisplayIncomingCall'
  //   **/
  //   String fakeCallUuid = genUUID();
  //   _callKit.displayIncomingCall(fakeCallUuid, "Stringee", "CallEnded");
  //   _fakeCallUuids.add(fakeCallUuid);
  // }
  //
  // void endFakeCall(String uuid) {
  //   if (_fakeCallUuids.contains(uuid)) {
  //     _callKit.endCall(uuid);
  //     _fakeCallUuids.remove(uuid);
  //     print("End fake call voi uuid: " + uuid);
  //   }
  // }
  //
  // void saveSyncCallToHandledCallList(SyncCall call) {
  //   _oldSyncCalls.removeWhere((element) => element.callId == call.callId && element.serial == call.serial);
  //   _oldSyncCalls.add(call);
  // }
  //
  // void removeSyncCallFromHandledCallList(String callId, int serial) {
  //   _oldSyncCalls.removeWhere((element) => element.callId == callId && element.serial == serial);
  // }
  //
  // bool checkIfCallIsHandledOrNot(String callId, int serial) {
  //   for (SyncCall loopCall in _oldSyncCalls) {
  //     if (loopCall.callId == callId && loopCall.serial == serial) {
  //       return true;
  //     }
  //   }
  //
  //   return false;
  // }
  //
  // void deleteSyncCallIfNeed() {
  //   if (_syncCall == null) {
  //     print("SyncCall is deleted");
  //     return;
  //   }
  //
  //   if (_syncCall.ended()) {
  //     saveSyncCallToHandledCallList(_syncCall);
  //     _syncCall = null;
  //   } else {
  //     print("deleteSyncCallIfNeed failed, endedCallkit: " + _syncCall.endedCallkit.toString() + " endedStringeeCall: " + _syncCall.endedStringeeCall.toString());
  //   }
  // }

  /// StringeeClient Listeners
  ///
  void handleDidConnectEvent() {
    setState(() {
      myUserId = _client.userId;
    });
    registerPushWithStringeeServer();
  }

  void handleDiddisconnectEvent() {
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
    print("callTapped, isVideo: " + isVideo.toString());
    if (toUserId.isEmpty || !_client.hasConnected) return;
    CallScreen callScreen = CallScreen(fromUserId: _client.userId, toUserId: toUserId, isVideo: isVideo);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => callScreen),
    );
  }
}
