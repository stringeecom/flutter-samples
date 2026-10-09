import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

import 'conversation.dart';

/// SharedPreferences key used to restore the last Stringee access token.
///
/// The sample keeps the token locally to demonstrate automatic reconnect.
/// Production applications should consider platform-secure storage according
/// to their security requirements.
const stringeeChatTokenKey = 'stringee_chat_access_token';
const _stringeeChatPushTokenKey = 'stringee_chat_push_token';

/// Connection, push and conversation API playground for Stringee Chat.
class ChatScreen extends StatefulWidget {
  /// Creates the Stringee Chat connection and conversation playground.
  ///
  /// Set [enableNotifications] to `false` in widget tests or when demonstrating
  /// chat APIs without configuring Firebase Messaging.
  const ChatScreen({super.key, this.enableNotifications = true});

  /// Whether this screen should request permission and register FCM/APNs.
  final bool enableNotifications;

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

/// Coordinates Stringee connection, push registration, and conversation APIs.
class ChatScreenState extends State<ChatScreen> {
  /// Stringee client owned by this screen.
  final StringeeClient client = StringeeClient();

  /// Chat API instance bound to [client].
  late final StringeeChat chat = StringeeChat(client);

  /// Input controller for the Stringee access token.
  final tokenController = TextEditingController();

  /// Input controller for the participant user ID.
  final participantController = TextEditingController();

  /// Input controller for the conversation ID.
  final conversationController = TextEditingController();

  final List<String> _logs = <String>[];
  final List<StringeeConversation> _conversations = <StringeeConversation>[];
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Whether the Stringee client is connected.
  bool connected = false;

  /// Whether a connect or logout operation is in progress.
  bool connecting = false;

  /// Human-readable connection state displayed by the status banner.
  String status = 'Not connected';

  @override
  void initState() {
    super.initState();
    _listenStringeeEvents();
    _configureNotifications();
    _restoreSession();
  }

  void _listenStringeeEvents() {
    _subscriptions.add(
      client.eventStreamController.stream.listen((dynamic rawEvent) {
        final event = rawEvent as Map<dynamic, dynamic>;
        switch (event['eventType']) {
          case StringeeClientEvents.didConnect:
            _onConnected();
            break;
          case StringeeClientEvents.didDisconnect:
            _updateConnection(false, 'Disconnected');
            break;
          case StringeeClientEvents.didFailWithError:
            final body = event['body'] as Map<dynamic, dynamic>;
            _updateConnection(
              false,
              'Connect failed: ${body['message'] ?? 'Unknown error'}',
            );
            _appendLog('SDK error ${body['code']}: ${body['message']}');
            break;
          case StringeeClientEvents.requestAccessToken:
            _clearSavedToken();
            _updateConnection(false, 'Token expired. Enter a new token');
            break;
          case StringeeClientEvents.tokenWillExpire:
            final body = event['body'] as Map<dynamic, dynamic>;
            _appendLog('Token expires in ${body['expireInSeconds']}s');
            // This sample has no token server. In your app, fetch a new token
            // for the same user and renew it on the open connection:
            //   await client.updateToken(await fetchTokenFromYourServer());
            // Then save it for the next launch, as the token entry flow does.
            break;
        }
      }),
    );
    _subscriptions.add(
      chat.eventStreamController.stream.listen((dynamic rawEvent) {
        final event = rawEvent as Map<dynamic, dynamic>;
        if (event['eventType'] != StringeeChatEvents.didReceiveObjectChange) {
          return;
        }
        final change = event['body'] as StringeeObjectChange;
        _appendLog(
          '${change.objectType?.name ?? 'object'}: ${change.type?.name ?? 'change'}',
        );
        if (change.objectType == ObjectType.conversation &&
            change.objects?.isNotEmpty == true) {
          final conversation = change.objects!.first as StringeeConversation;
          _upsertConversation(conversation);
        }
      }),
    );
  }

  Future<void> _configureNotifications() async {
    if (!widget.enableNotifications || kIsWeb) return;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    _appendLog('Notification permission: ${settings.authorizationStatus.name}');
    _subscriptions.add(
      FirebaseMessaging.onMessage.listen(
        (message) => _appendLog('Foreground push: ${message.messageId}'),
      ),
    );
    _subscriptions.add(
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _appendLog('Opened push: ${message.messageId}'),
      ),
    );
    _subscriptions.add(
      FirebaseMessaging.instance.onTokenRefresh.listen((_) {
        if (connected) _registerPush();
      }),
    );
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(stringeeChatTokenKey) ?? '';
    if (!mounted) return;
    tokenController.text = token;
    if (token.isNotEmpty) await _connect(token);
  }

  /// Connects using [tokenController] and persists the normalized token.
  Future<void> connect() => _connect(tokenController.text);

  Future<void> _connect(String rawToken) async {
    final token = rawToken.trim();
    if (token.isEmpty || connecting) return;
    setState(() {
      connecting = true;
      status = 'Connecting…';
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(stringeeChatTokenKey, token);
      final result = await client.connect(token);
      if (!mounted) return;
      if (result['status'] != true) {
        setState(() {
          connecting = false;
          status = result['message']?.toString() ?? 'Connect failed';
        });
      }
    } catch (error) {
      _updateConnection(false, 'Connect failed: $error');
    }
  }

  /// Unregisters push, disconnects Stringee, and clears the saved session.
  Future<void> logout() async {
    if (connecting) return;
    setState(() {
      connecting = true;
      status = 'Logging out…';
    });
    final prefs = await SharedPreferences.getInstance();
    try {
      final pushToken = prefs.getString(_stringeeChatPushTokenKey) ?? '';
      if (pushToken.isNotEmpty) await client.unregisterPush(pushToken);
    } catch (error) {
      _appendLog('Unable to unregister push: $error');
    } finally {
      try {
        await client.disconnect();
      } finally {
        await prefs.remove(stringeeChatTokenKey);
        await prefs.remove(_stringeeChatPushTokenKey);
        tokenController.clear();
        if (mounted) {
          setState(() {
            connected = false;
            connecting = false;
            status = 'Logged out';
            _conversations.clear();
          });
        }
      }
    }
  }

  Future<void> _onConnected() async {
    _updateConnection(true, 'Connected as ${client.userId ?? 'unknown'}');
    _appendLog('Connected to Stringee');
    await _registerPush();
    await loadLatestConversations();
  }

  void _updateConnection(bool value, String message) {
    if (!mounted) return;
    setState(() {
      connected = value;
      connecting = false;
      status = message;
    });
  }

  Future<void> _registerPush() async {
    if (!widget.enableNotifications || !connected || kIsWeb) return;
    try {
      final token = defaultTargetPlatform == TargetPlatform.iOS
          ? await FirebaseMessaging.instance.getAPNSToken()
          : await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        _appendLog('Push token is not available yet');
        return;
      }
      final result = await client.registerPush(
        token,
        isProduction: kReleaseMode,
        isVoip: false,
      );
      _appendResult('Register push', result);
      if (result['status'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_stringeeChatPushTokenKey, token);
      }
    } catch (error) {
      _appendLog('Register push failed: $error');
    }
  }

  Future<void> _clearSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(stringeeChatTokenKey);
  }

  /// Creates a distinct one-to-one conversation with the entered participant.
  Future<void> createConversation() async {
    final userId = participantController.text.trim();
    if (userId.isEmpty) return _showInputError('Enter a participant ID');
    final result = await chat.createConversation(
      StringeeConversationOption(
        name: 'Chat with $userId',
        isGroup: false,
        isDistinct: true,
      ),
      <StringeeUser>[StringeeUser(userId: userId, name: userId)],
    );
    _consumeConversationResult('Create conversation', result);
  }

  /// Loads one conversation using the entered conversation ID.
  Future<void> getConversationById() async {
    final id = conversationController.text.trim();
    if (id.isEmpty) return _showInputError('Enter a conversation ID');
    _consumeConversationResult(
      'Get conversation by ID',
      await chat.getConversationById(id),
    );
  }

  /// Loads a one-to-one conversation using the entered participant ID.
  Future<void> getConversationByUserId() async {
    final userId = participantController.text.trim();
    if (userId.isEmpty) return _showInputError('Enter a participant ID');
    _consumeConversationResult(
      'Get conversation by user',
      await chat.getConversationByUserId(userId),
    );
  }

  /// Loads conversations from the local Stringee database.
  Future<void> loadLocalConversations() async {
    _consumeConversationResult(
      'Load local conversations',
      await chat.getLocalConversations(),
    );
  }

  /// Loads the latest conversations from the Stringee server.
  Future<void> loadLatestConversations() async {
    _consumeConversationResult(
      'Load latest conversations',
      await chat.getLastConversation(50),
    );
  }

  /// Loads a page of conversations preceding the current time.
  Future<void> loadBefore() async {
    _consumeConversationResult(
      'Load conversations before',
      await chat.getConversationsBefore(
        20,
        DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Loads conversations updated after the last displayed conversation.
  Future<void> loadAfter() async {
    final timestamp = _conversations.isEmpty
        ? DateTime.now()
            .subtract(const Duration(days: 30))
            .millisecondsSinceEpoch
        : (_conversations.last.updatedAt ?? 1);
    _consumeConversationResult(
      'Load conversations after',
      await chat.getConversationsAfter(20, timestamp),
    );
  }

  /// Requests the total unread count and writes the result to the event log.
  Future<void> getTotalUnread() async {
    _appendResult('Total unread', await chat.getTotalUnread());
  }

  /// Clears Stringee's local chat database and the displayed conversation list.
  Future<void> clearDatabase() async {
    _appendResult('Clear local database', await chat.clearDb());
    if (mounted) setState(_conversations.clear);
  }

  void _consumeConversationResult(
    String operation,
    Map<dynamic, dynamic> result,
  ) {
    _appendResult(operation, result);
    if (result['status'] != true || !mounted) return;
    final body = result['body'];
    setState(() {
      if (body is StringeeConversation) {
        _upsertConversation(body, notify: false);
      } else if (body is List<StringeeConversation>) {
        _conversations
          ..clear()
          ..addAll(body);
      }
    });
  }

  void _upsertConversation(
    StringeeConversation conversation, {
    bool notify = true,
  }) {
    void update() {
      _conversations.removeWhere((item) => item.id == conversation.id);
      _conversations.insert(0, conversation);
    }

    if (!mounted) return;
    if (notify) {
      setState(update);
    } else {
      update();
    }
  }

  void _appendResult(String operation, Map<dynamic, dynamic> result) {
    _appendLog(
      '$operation: ${result['status'] == true ? 'success' : result['message'] ?? 'failed'}',
    );
  }

  void _appendLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, message);
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  void _showInputError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    chat.destroy();
    tokenController.dispose();
    participantController.dispose();
    conversationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const _BrandTitle(),
        actions: [
          if (connected)
            TextButton.icon(
              onPressed: connecting ? null : logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Logout'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusBanner(
                    connected: connected,
                    loading: connecting,
                    message: status,
                  ),
                  const SizedBox(height: 16),
                  if (!connected) _buildConnectCard() else _buildChatContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnectCard() {
    return _SurfaceCard(
      title: 'Connect to Stringee',
      subtitle: 'Use an access token issued by your trusted server.',
      child: Column(
        children: [
          TextField(
            key: const Key('tokenField'),
            controller: tokenController,
            enabled: !connecting,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Access token',
              prefixIcon: Icon(Icons.key_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              key: const Key('connectButton'),
              onPressed: connecting ? null : connect,
              icon: const Icon(Icons.login_rounded),
              label: Text(connecting ? 'Connecting…' : 'Connect'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatContent() {
    return Column(
      children: [
        _SurfaceCard(
          title: 'Conversation input',
          subtitle: 'IDs are intentionally entered at runtime in this sample.',
          child: Column(
            children: [
              TextField(
                controller: participantController,
                decoration: const InputDecoration(
                  labelText: 'Participant user ID',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: conversationController,
                decoration: const InputDecoration(
                  labelText: 'Conversation ID',
                  prefixIcon: Icon(Icons.forum_outlined),
                ),
              ),
              const SizedBox(height: 16),
              _ActionGrid(
                actions: <_ApiAction>[
                  _ApiAction('Create', Icons.add_comment, createConversation),
                  _ApiAction('Get by ID', Icons.tag, getConversationById),
                  _ApiAction(
                    'Get by user',
                    Icons.person_search,
                    getConversationByUserId,
                  ),
                  _ApiAction('Local', Icons.storage, loadLocalConversations),
                  _ApiAction('Latest', Icons.refresh, loadLatestConversations),
                  _ApiAction('Before', Icons.arrow_back, loadBefore),
                  _ApiAction('After', Icons.arrow_forward, loadAfter),
                  _ApiAction('Unread', Icons.mark_chat_unread, getTotalUnread),
                  _ApiAction('Clear DB', Icons.delete_sweep, clearDatabase),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SurfaceCard(
          title: 'Conversations (${_conversations.length})',
          subtitle: 'Tap an item to open message and participant APIs.',
          child: _conversations.isEmpty
              ? const _EmptyState('No conversations loaded')
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final conversation = _conversations[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.chat_bubble_outline),
                      ),
                      title: Text(conversation.name ?? 'Unnamed conversation'),
                      subtitle: Text(conversation.id ?? 'No conversation ID'),
                      trailing: Badge(
                        isLabelVisible: (conversation.totalUnread ?? 0) > 0,
                        label: Text('${conversation.totalUnread ?? 0}'),
                        child: const Icon(Icons.chevron_right),
                      ),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => Conversation(
                            client: client,
                            chat: chat,
                            conversation: conversation,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        _SurfaceCard(
          title: 'Event log',
          subtitle: 'Latest SDK and notification events.',
          child: _logs.isEmpty
              ? const _EmptyState('No events yet')
              : Column(
                  children: _logs
                      .take(20)
                      .map(
                        (log) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.terminal, size: 18),
                          title: Text(log),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }
}

class _ApiAction {
  const _ApiAction(this.label, this.icon, this.callback);

  final String label;
  final IconData icon;
  final FutureOr<void> Function() callback;
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_ApiAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: actions
              .map(
                (action) => OutlinedButton.icon(
                  onPressed: action.callback,
                  icon: Icon(action.icon, size: 19),
                  label: Text(action.label),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.connected,
    required this.loading,
    required this.message,
  });

  final bool connected;
  final bool loading;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = connected ? const Color(0xFF159447) : const Color(0xFF0FACF3);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(55)),
      ),
      child: Row(
        children: [
          if (loading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(connected ? Icons.cloud_done : Icons.cloud_off, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFFEE2333),
          child: Icon(Icons.forum_rounded, size: 19, color: Colors.white),
        ),
        SizedBox(width: 10),
        Text('Stringee Chat Sample'),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }
}
