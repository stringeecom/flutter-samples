import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'stringee_wrapper/common/common.dart';
import 'stringee_wrapper/push_manager/android_push_manager.dart';
import 'stringee_wrapper/stringee_wrapper.dart';

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

bool _initialized = false;
const accessToken = 'PUT_YOUR_TOKEN_HERE';

void main() async {
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
  // connect when app start
  StringeeWrapper().connect(accessToken);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call sample',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Call sample'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool isVideoCall = false;
  bool connected = false;
  bool connecting = false;
  bool isEnablePush = false;
  String connectStatus = 'Not connected...';

  String to = '';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("didChangeAppLifecycle - $state");
    if (state == AppLifecycleState.resumed) {
      AndroidPushManager().cancelIncomingCallNotification();
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
      StringeeWrapper().requestPermissions();
    }

    // add listener to listen event from StringeeWrapper
    StringeeWrapper().addListener(StringeeListener(
      onConnected: (userId) {
        debugPrint('Connected');
        setState(() {
          connected = true;
          connecting = false;
          connectStatus = 'Connected as $userId';
        });
      },
      onDisConnected: () {
        debugPrint('Disconnected');
        setState(() {
          connected = false;
          connecting = false;
          connectStatus = 'Disconnected';
        });
      },
      onRequestNewToken: () {
        // reconnect with latest token
        StringeeWrapper().connect(accessToken);
        setState(() {
          connectStatus = 'Request new token';
        });
      },
      onConnectError: (code, msg) {
        debugPrint('Connect error: $code - $msg');
        setState(() {
          connectStatus = 'Connect fail: $msg';
        });
      },
      onPresentCallWidget: (callWidget) {
        debugPrint('onPresentCallWidget: ${callWidget.hashCode}');
        showDialog(
          useSafeArea: false,
          context: context,
          builder: (context) => Dialog.fullscreen(child: callWidget),
          barrierDismissible: false,
        );
      },
      onDismissCallWidget: (msg) {
        debugPrint('onDismissCallWidget: $msg');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    ));

    _updateStateWithStringeeWrapper();
  }

  void _updateStateWithStringeeWrapper() async {
    setState(() {
      connected = StringeeWrapper().connected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: connected
            ? Theme.of(context).colorScheme.inversePrimary
            : Colors.grey,
        title: Text(widget.title),
        actions: [
          TextButton.icon(
            onPressed: () {
              // connect to stringee with token using StringeeWrapper
              if (connecting) {
                return;
              }
              connected
                  ? StringeeWrapper().disconnect()
                  : StringeeWrapper().connect(accessToken);
              setState(() {
                connecting = true;
              });
            },
            icon: const Icon(Icons.connect_without_contact_outlined),
            label: connecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(),
                  )
                : connected
                    ? const Text('Disconnect')
                    : const Text('Connect'),
          )
        ],
      ),
      body: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Switch.adaptive(
                value: isEnablePush,
                onChanged: (value) async {
                  if (!connected) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please connect to Stringee first'),
                      ),
                    );
                    return;
                  }

                  if (value) {
                    StringeeWrapper().enablePush(isVoip: true);
                  } else {
                    StringeeWrapper().unregisterPush();
                  }
                  setState(() {
                    isEnablePush = value;
                  });
                },
              ),
              const Text("Enable Push"),
              const SizedBox(width: 16),
            ],
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Center(
                  child: Text(
                    connectStatus,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Enter a callee id',
                    ),
                    onChanged: (value) {
                      to = value;
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Switch.adaptive(
                      value: isVideoCall,
                      onChanged: (value) {
                        setState(() {
                          isVideoCall = value;
                        });
                      },
                    ),
                    const Text("Video Call")
                  ],
                ),
              ],
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (!connected) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please connect to Stringee first'),
              ),
            );
            return;
          }
          if (to.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter a callee id'),
              ),
            );
            return;
          }
          StringeeWrapper().makeCall(
            to: to,
            isVideoCall: isVideoCall,
            videoQuality: VideoQuality.fullHd,
          );
        },
        tooltip: 'Call',
        child: const Icon(Icons.call),
      ),
    );
  }
}
