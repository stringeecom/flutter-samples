import 'package:flutter/material.dart';

import 'stringee_wrapper/stringee_wrapper.dart';

const accessToken =
    'eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTSy4wLkFCMmFIeUpVNkVwakEyMHN6MWw2NG1WRklhVzRaQ1YyLTE3MTU5MzA3MDMiLCJpc3MiOiJTSy4wLkFCMmFIeUpVNkVwakEyMHN6MWw2NG1WRklhVzRaQ1YyIiwiZXhwIjoxNzE4NTIyNzAzLCJ1c2VySWQiOiJ0YWlwdiJ9.WLhteT-xDFBN2icAnSVRE4wwiNabuSbIdZKJFCS7lJo';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool isVideoCall = false;
  bool connected = false;

  String to = '';
  @override
  void initState() {
    super.initState();

    // add listner to listen event from StringeeWrapper
    StringeeWrapper().addListener(StringeeListener(
      onConnected: () {
        debugPrint('Connected');
        setState(() {
          connected = true;
        });
      },
      onDisConnected: () {
        debugPrint('Disconnected');
        setState(() {
          connected = false;
        });
      },
      onRequestNewToken: () {
        // reconnect with latest token
        StringeeWrapper().connect(accessToken);
      },
      onConnectError: (code, msg) {
        debugPrint('Connect error: $code - $msg');
      },
      onPresentCallWidget: (callWidget) {
        debugPrint('Call widget presented');
        showDialog(
          useSafeArea: false,
          context: context,
          builder: (context) => Dialog.fullscreen(child: callWidget),
          barrierDismissible: false,
        );
      },
      onDismissCallWidget: (msg) {
        debugPrint('Call ended: $msg');
        Navigator.of(context).pop();
      },
    ));
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
              connected
                  ? StringeeWrapper().disconnect()
                  : StringeeWrapper().connect(accessToken);
            },
            icon: const Icon(Icons.connect_without_contact_outlined),
            label: connected ? const Text('Disconnect') : const Text('Connect'),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
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
            from: 'taipv',
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
