import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'environment_config.dart';
import 'stringee_wrapper/common/common.dart';
import 'stringee_wrapper/push_manager/android_push_manager.dart';
import 'stringee_wrapper/stringee_wrapper.dart';

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage remoteMessage) async {
  if (!_initialized) {
    await Firebase.initializeApp();
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!isIOS) {
    await AndroidPushManager().handleNotificationAction();
    if (!_initialized) {
      await Firebase.initializeApp();
      _initialized = true;
    }
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
  }
  // connect when app start
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId') ?? '';
  if (userId.isNotEmpty) {
    debugPrint('Connect with userId: $userId when app start');
    String accessToken = getAccessToken(userId: userId, ttl: 36000);
    StringeeWrapper().initialize();
    StringeeWrapper().connect(accessToken);
  }

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
  late SharedPreferences _prefs;

  TextEditingController userIdController = TextEditingController();
  String to = '';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("didChangeAppLifecycle - $state");
    if (state == AppLifecycleState.resumed && !isIOS) {
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
      StringeeWrapper().requestNotificationPermissions();
    }
    StringeeWrapper().initialize();
    // add listener to listen event from StringeeWrapper
    StringeeWrapper().addListener(StringeeListener(
      onConnected: (userId) async {
        debugPrint('Connected');
        setState(() {
          connected = true;
          connecting = false;
          connectStatus = 'Connected as $userId';
        });
        _prefs = await SharedPreferences.getInstance();
        bool isPushRegistered = _prefs.getBool('isPushRegistered') ?? false;
        if (!isPushRegistered) {
          StringeeWrapper().registerPush(isVoip: true);
        }
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
        if (userIdController.text.isNotEmpty) {
          debugPrint('Connect when request new token...');
          String accessToken =
              getAccessToken(userId: userIdController.text, ttl: 36000);
          StringeeWrapper().connect(accessToken);
        }

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

    // get userId from SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      final userId = prefs.getString('userId') ?? '';
      if (userId.isNotEmpty) {
        userIdController.text = userId;
      }
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
      ),
      body: Stack(
        children: [
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
                  child: !connected
                      ? TextFormField(
                          onChanged: (value) => setState(() {}),
                          controller: userIdController,
                          enabled: !connected,
                          decoration: const InputDecoration(
                              hintText: 'Enter a user ID'),
                        )
                      : TextField(
                          decoration: const InputDecoration(
                            hintText: 'Enter a callee id',
                          ),
                          controller: null,
                          onChanged: (value) {
                            to = value;
                          },
                        ),
                ),
                Column(
                  children: [
                    if (connected)
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
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: connected
                            ? Theme.of(context).colorScheme.inversePrimary
                            : Colors.grey,
                      ),
                      onPressed: () {
                        if (userIdController.text.isEmpty) {
                          return;
                        }
                        // connect to stringee with token using StringeeWrapper
                        if (connecting) {
                          return;
                        }
                        setState(() {
                          connecting = true;
                        });
                        if (connected) {
                          StringeeWrapper().disconnect();
                          // clear userId in SharedPreferences
                          SharedPreferences.getInstance().then((prefs) {
                            prefs.remove('userId');
                          });
                          return;
                        }
                        String accessToken = getAccessToken(
                            userId: userIdController.text, ttl: 36000);
                        StringeeWrapper().connect(accessToken);

                        // save userId to SharedPreferences
                        SharedPreferences.getInstance().then((prefs) {
                          prefs.setString('userId', userIdController.text);
                        });
                      },
                      icon: Icon(
                        Icons.connect_without_contact_outlined,
                        color: connected
                            ? Theme.of(context).colorScheme.secondary
                            : Colors.white,
                      ),
                      label: connecting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(),
                            )
                          : Text(
                              connected ? 'Disconnect' : 'Connect',
                              style: TextStyle(
                                color: connected
                                    ? Theme.of(context).colorScheme.secondary
                                    : Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
      floatingActionButton: connected
          ? FloatingActionButton(
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
            )
          : null,
    );
  }
}
