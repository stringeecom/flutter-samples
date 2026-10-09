import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'stringee_wrapper/call/stringee_call_manager.dart';
import 'stringee_wrapper/common/common.dart';
import 'stringee_wrapper/push_manager/android_push_manager.dart';
import 'stringee_wrapper/stringee_wrapper.dart';

@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage remoteMessage) async {
  if (!_initialized) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _initialized = true;
  }
  debugPrint('Handling a background message: ${remoteMessage.data}');
  await AndroidPushManager().handleRemoteMessage(remoteMessage);
}

bool _initialized = false;

abstract final class _StringeeColors {
  static const red = Color(0xFFFF4954);
  static const redStrong = Color(0xFFEE2333);
  static const green = Color(0xFF46DA60);
  static const greenDark = Color(0xFF159447);
  static const blue = Color(0xFF0FACF3);
  static const navy = Color(0xFF0D112B);
  static const navyLight = Color(0xFF233659);
  static const text = Color(0xFF535353);
  static const background = Color(0xFFF8F8F8);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!isIOS) {
    await AndroidPushManager().handleNotificationAction();
    if (!_initialized) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _initialized = true;
    }
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
    FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
      if (StringeeWrapper().connected) {
        await StringeeWrapper().registerPush();
      }
    });
  }
  runApp(const MyApp());
}

/// Root Material application for the call sample.
class MyApp extends StatelessWidget {
  /// Creates the sample application.
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Call sample',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _StringeeColors.red,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: _StringeeColors.background,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: _StringeeColors.red,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Call sample'),
    );
  }
}

/// Main connection and outgoing-call screen.
class MyHomePage extends StatefulWidget {
  /// Creates the home screen with an app-bar [title].
  const MyHomePage({super.key, required this.title});

  /// Title displayed by the home screen.
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  bool connected = false;
  bool connecting = false;
  String connectStatus = 'Not connected...';
  late final StringeeListener _stringeeListener;
  bool _isCallDialogVisible = false;

  final TextEditingController tokenController = TextEditingController();
  final TextEditingController calleeController = TextEditingController();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("didChangeAppLifecycle - $state");
    if (isIOS) return;
    if (state == AppLifecycleState.resumed) {
      AndroidPushManager().cancelIncomingCallNotification();
      return;
    }
    if (state == AppLifecycleState.paused) {
      final calls = StringeeCallManager().calls;
      final call = calls.isEmpty ? null : calls.last;
      if (call != null && call.callState == CallState.incoming) {
        AndroidPushManager().showIncomingCallNotification(
          call.callee ?? call.call.from ?? 'Unknown caller',
          call.call.from ?? '',
          callId: call.call.callId ?? '',
          isVideo: call.isVideoCall,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    StringeeWrapper().removeListener(_stringeeListener);
    AndroidPushManager().release();
    tokenController.dispose();
    calleeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!isIOS) {
      AndroidPushManager().callPermissionRequester =
          StringeeWrapper().requestCallPermissions;
      AndroidPushManager().listenNotificationSelect();
      StringeeWrapper().requestNotificationPermissions().then((_) {
        AndroidPushManager().requestFullScreenIntentPermissionIfNeeded();
      });
    }
    StringeeWrapper().initialize();
    // add listener to listen event from StringeeWrapper
    _stringeeListener = StringeeListener(
      onConnected: (userId) async {
        debugPrint('Connected');
        if (!mounted) return;
        setState(() {
          connected = true;
          connecting = false;
          connectStatus = 'Connected as $userId';
        });
        final prefs = await SharedPreferences.getInstance();
        bool isPushRegistered = prefs.getBool('isPushRegistered') ?? false;
        if (!isPushRegistered) {
          StringeeWrapper().registerPush(isVoip: true);
        }
      },
      onDisConnected: () {
        debugPrint('Disconnected');
        if (!mounted) return;
        setState(() {
          connected = false;
          connecting = false;
          connectStatus = 'Disconnected';
        });
      },
      onRequestNewToken: () async {
        debugPrint('Stringee requested a new access token');
        await StringeeWrapper().clearSavedAccessToken();
        if (!mounted) return;
        setState(() {
          connected = false;
          connecting = false;
          connectStatus = 'Token expired. Enter a new token';
        });
      },
      onTokenWillExpire: (exp, expireInSeconds) {
        debugPrint('Access token expires in ${expireInSeconds}s (exp: $exp)');
        // This sample has no token server. In your app, fetch a new token for
        // the same user from your server and renew it on the open connection:
        //   final newToken = await fetchTokenFromYourServer();
        //   await StringeeWrapper().updateToken(newToken);
        // Without renewal the server disconnects when the token expires and
        // onRequestNewToken is called.
      },
      onConnectError: (code, msg) {
        debugPrint('Connect error: $code - $msg');
        if (!mounted) return;
        setState(() {
          connecting = false;
          connectStatus = 'Connect fail: $msg';
        });
      },
      onPresentCallWidget: (callWidget) {
        debugPrint('onPresentCallWidget: ${callWidget.hashCode}');
        if (!mounted || _isCallDialogVisible) return;
        _isCallDialogVisible = true;
        showDialog(
          useSafeArea: false,
          context: context,
          builder: (context) => Dialog.fullscreen(child: callWidget),
          barrierDismissible: false,
        ).whenComplete(() => _isCallDialogVisible = false);
      },
      onDismissCallWidget: (msg) {
        debugPrint('onDismissCallWidget: $msg');
        if (mounted && _isCallDialogVisible && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    );
    StringeeWrapper().addListener(_stringeeListener);

    _restoreConnection();
  }

  Future<void> _restoreConnection() async {
    final accessToken = await StringeeWrapper().getSavedAccessToken();
    if (!mounted) return;

    setState(() {
      connected = StringeeWrapper().connected;
      tokenController.text = accessToken;
      if (!connected && accessToken.isNotEmpty) {
        connecting = true;
        connectStatus = 'Connecting...';
      }
    });

    if (!connected && accessToken.isNotEmpty) {
      debugPrint('Connecting with saved access token');
      try {
        await StringeeWrapper().connect(accessToken);
      } catch (error) {
        if (!mounted) return;
        setState(() {
          connecting = false;
          connectStatus = 'Connect failed: $error';
        });
      }
    }
  }

  Future<void> _connect() async {
    final accessToken = tokenController.text.trim();
    if (accessToken.isEmpty || connecting) return;
    setState(() {
      connecting = true;
      connectStatus = 'Connecting...';
    });
    try {
      await StringeeWrapper().connect(accessToken);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        connecting = false;
        connectStatus = 'Connect failed: $error';
      });
    }
  }

  Future<void> _logout() async {
    if (connecting) return;
    setState(() {
      connecting = true;
      connectStatus = 'Logging out...';
    });
    try {
      await StringeeWrapper().logout();
      tokenController.clear();
      if (!mounted) return;
      setState(() {
        connected = false;
        connecting = false;
        connectStatus = 'Logged out';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        connecting = false;
        connectStatus = 'Logout failed: $error';
      });
    }
  }

  String? _validatedCallee() {
    final callee = calleeController.text.trim();
    if (callee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a callee id')),
      );
      return null;
    }
    return callee;
  }

  void _makeVoiceCall() {
    final callee = _validatedCallee();
    if (callee == null) return;
    StringeeWrapper().makeVoiceCall(to: callee);
  }

  void _makeVideoCall() {
    final callee = _validatedCallee();
    if (callee == null) return;
    StringeeWrapper().makeVideoCall(
      to: callee,
      videoQuality: VideoQuality.fullHd,
    );
  }

  void _makeVoiceCall2() {
    final callee = _validatedCallee();
    if (callee == null) return;
    StringeeWrapper().makeVoiceCall2(to: callee);
  }

  void _makeVideoCall2() {
    final callee = _validatedCallee();
    if (callee == null) return;
    StringeeWrapper().makeVideoCall2(
      to: callee,
      videoQuality: VideoQuality.fullHd,
    );
  }

  Widget _buildSdkCallActions({
    required String sdkClass,
    required VoidCallback onVoiceCall,
    required VoidCallback onVideoCall,
  }) {
    final enabled = calleeController.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sdkClass,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _StringeeColors.navy,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 58,
                child: FilledButton.icon(
                  onPressed: enabled ? onVoiceCall : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _StringeeColors.redStrong,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.call_rounded),
                  label: const Text('Voice'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 58,
                child: FilledButton.icon(
                  onPressed: enabled ? onVideoCall : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: _StringeeColors.green,
                    foregroundColor: _StringeeColors.navy,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.videocam_rounded),
                  label: const Text('Video'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_StringeeColors.navy, _StringeeColors.navyLight],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x330D112B),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _StringeeColors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.call_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 18),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stringee Call Sample',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Connect once, then start clear voice and video calls.',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(ColorScheme colors) {
    final hasError = connectStatus.toLowerCase().contains('fail') ||
        connectStatus.toLowerCase().contains('expired');
    final statusColor = hasError
        ? colors.error
        : connected
            ? _StringeeColors.greenDark
            : _StringeeColors.blue;
    final statusIcon = hasError
        ? Icons.error_outline_rounded
        : connected
            ? Icons.check_circle_outline_rounded
            : Icons.cloud_off_outlined;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(45)),
      ),
      child: Row(
        children: [
          if (connecting)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.3,
                color: statusColor,
              ),
            )
          else
            Icon(statusIcon, color: statusColor, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              connectStatus,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectCard(ColorScheme colors) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.key_rounded,
            title: 'Connect to Stringee',
            description:
                'Paste an access token generated by your trusted server.',
          ),
          const SizedBox(height: 22),
          TextFormField(
            onChanged: (_) => setState(() {}),
            controller: tokenController,
            enabled: !connecting,
            keyboardType: TextInputType.visiblePassword,
            autocorrect: false,
            enableSuggestions: false,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Access token',
              hintText: 'Enter a Stringee access token',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 28),
                child: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: connecting || tokenController.text.trim().isEmpty
                  ? null
                  : _connect,
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              icon: connecting
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login_rounded),
              label: Text(connecting ? 'Connecting...' : 'Connect'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallCard() {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading(
            icon: Icons.add_call,
            title: 'Start a new call',
            description: 'Enter the Stringee user ID you want to reach.',
          ),
          const SizedBox(height: 22),
          TextField(
            controller: calleeController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (calleeController.text.trim().isNotEmpty) _makeVoiceCall();
            },
            decoration: const InputDecoration(
              labelText: 'Callee ID',
              hintText: 'Enter a callee id',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Call type',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          _buildSdkCallActions(
            sdkClass: 'StringeeCall',
            onVoiceCall: _makeVoiceCall,
            onVideoCall: _makeVideoCall,
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),
          _buildSdkCallActions(
            sdkClass: 'StringeeCall2',
            onVoiceCall: _makeVoiceCall2,
            onVideoCall: _makeVideoCall2,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _StringeeColors.redStrong,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STRINGEE',
                  style: TextStyle(
                    color: _StringeeColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: _StringeeColors.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (connected)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton.icon(
                onPressed: connecting ? null : _logout,
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: const Text('Logout'),
                style: TextButton.styleFrom(foregroundColor: colors.error),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, _StringeeColors.background],
          ),
        ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHero(),
                      const SizedBox(height: 22),
                      _buildConnectionStatus(colors),
                      const SizedBox(height: 14),
                      if (connected)
                        _buildCallCard()
                      else
                        _buildConnectCard(colors),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EAEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0D112B),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _StringeeColors.redStrong),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
