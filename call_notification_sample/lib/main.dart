import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    await AndroidPushManager().handleStringeePush(data);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!isIOS) {
    AndroidPushManager().handleNotificationAction();
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
  String _token = 'PUT_YOUR_TOKEN_HERE';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("didChangeAppLifecycle - $state");
    if (state == AppLifecycleState.resumed) {
      AndroidPushManager().cancelIncomingCallNotification();
      isAppInBackground = false;
    } else if (state == AppLifecycleState.inactive) {
      isAppInBackground = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AndroidPushManager().release();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!isIOS) {
      AndroidPushManager().listenNotificationSelect();
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
          if (!CallkeepManager.shared!.isPushRegistered) {
            CallkeepManager.shared!.isPushRegistered = true;
            StringeeWrapper().registerPush(
                CallkeepManager.shared?.pushToken ?? '',
                isVoip: true,
                isProduction: false);
          }
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
      onNeedShowCallWidget: (callWidget) {
        debugPrint('onShowCallWidget');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => callWidget,
          ),
        );
      },
      onNeedDismissCallWidget: (message) {
        debugPrint('onCallWidgetDismiss - $message');
        Navigator.popUntil(context, (route) {
          return route.isFirst;
        });
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
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    StringeeWrapper().makeCall(
        _userId,
        _to,
        isVideoCall,
        new CallBackListener(
          onSuccess: () {
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
