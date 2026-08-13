import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

/// Message and participant API playground for one Stringee conversation.
class Conversation extends StatefulWidget {
  /// Creates an API playground for [conversation].
  const Conversation({
    super.key,
    required this.client,
    required this.chat,
    required this.conversation,
  });

  /// Connected Stringee client used to construct messages.
  final StringeeClient client;

  /// Chat event source used to receive message changes.
  final StringeeChat chat;

  /// Conversation whose messages and participants are managed.
  final StringeeConversation conversation;

  @override
  State<Conversation> createState() => ConversationState();
}

/// Coordinates message, participant, typing, and conversation operations.
class ConversationState extends State<Conversation> {
  /// Input controller for outgoing text messages.
  final messageController = TextEditingController(text: 'Hello from Stringee');

  /// Input controller for participant operations.
  final participantController = TextEditingController();

  /// Input controller for renaming the conversation.
  final nameController = TextEditingController();
  final List<String> _logs = <String>[];
  final List<StringeeMessage> _messages = <StringeeMessage>[];
  StreamSubscription<dynamic>? _chatSubscription;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    nameController.text = widget.conversation.name ?? '';
    _chatSubscription = widget.chat.eventStreamController.stream.listen(
      _handleChatEvent,
    );
    loadLastMessages();
  }

  void _handleChatEvent(dynamic rawEvent) {
    final event = rawEvent as Map<dynamic, dynamic>;
    if (event['eventType'] != StringeeChatEvents.didReceiveObjectChange) return;
    final change = event['body'] as StringeeObjectChange;
    if (change.objectType != ObjectType.message ||
        change.objects?.isNotEmpty != true) {
      return;
    }
    final message = change.objects!.first as StringeeMessage;
    if (message.convId != widget.conversation.id) return;
    _upsertMessage(message);
    _appendLog(
      'Message ${change.type?.name ?? 'change'}: ${message.id ?? message.localId}',
    );
  }

  /// Sends a text message with sample custom data.
  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty) return _showInputError('Enter a message');
    final message = StringeeMessage.typeText(
      widget.client,
      text,
      customData: const {'source': 'flutter-chat-sample'},
    );
    await _run('Send message', () => widget.conversation.sendMessage(message));
  }

  /// Loads the latest messages from the Stringee server.
  Future<void> loadLastMessages() async {
    await _loadMessages(
      'Load latest messages',
      () => widget.conversation.getLastMessages(50),
    );
  }

  /// Loads cached messages from the local Stringee database.
  Future<void> loadLocalMessages() async {
    await _loadMessages(
      'Load local messages',
      () => widget.conversation.getLocalMessages(50),
    );
  }

  /// Loads messages preceding the oldest displayed sequence.
  Future<void> loadBefore() async {
    final sequence = _messages.isEmpty ? 1 : (_messages.last.sequence ?? 1);
    await _loadMessages(
      'Load messages before',
      () => widget.conversation.getMessagesBefore(30, sequence),
    );
  }

  /// Loads messages following the newest displayed sequence.
  Future<void> loadAfter() async {
    final sequence = _messages.isEmpty ? 0 : (_messages.first.sequence ?? 0);
    await _loadMessages(
      'Load messages after',
      () => widget.conversation.getMessagesAfter(30, sequence),
    );
  }

  /// Reloads up to two displayed server messages by ID.
  Future<void> getSelectedMessages() async {
    final ids = _messages
        .map((message) => message.id)
        .whereType<String>()
        .take(2)
        .toList();
    if (ids.isEmpty) return _showInputError('Load a server message first');
    await _loadMessages(
      'Get selected messages',
      () => widget.conversation.getMessages(ids),
    );
  }

  /// Adds the entered participant to the conversation.
  Future<void> addParticipant() async {
    final user = _participant();
    if (user == null) return;
    await _run(
      'Add participant',
      () => widget.conversation.addParticipants(<StringeeUser>[user]),
    );
  }

  /// Removes the entered participant from the conversation.
  Future<void> removeParticipant() async {
    final user = _participant();
    if (user == null) return;
    await _run(
      'Remove participant',
      () => widget.conversation.removeParticipants(<StringeeUser>[user]),
    );
  }

  StringeeUser? _participant() {
    final userId = participantController.text.trim();
    if (userId.isEmpty) {
      _showInputError('Enter a participant ID');
      return null;
    }
    return StringeeUser(userId: userId, name: userId);
  }

  /// Updates the conversation with the entered display name.
  Future<void> updateName() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return _showInputError('Enter a conversation name');
    await _run(
      'Update conversation',
      () => widget.conversation.updateConversation(name),
    );
  }

  /// Assigns the member role to the entered participant.
  Future<void> setMemberRole() async {
    final userId = participantController.text.trim();
    if (userId.isEmpty) return _showInputError('Enter a participant ID');
    await _run(
      'Set member role',
      () => widget.conversation.setRole(userId, UserRole.member),
    );
  }

  /// Marks all current conversation messages as read.
  Future<void> markAsRead() async {
    await _run('Mark as read', widget.conversation.markAsRead);
  }

  /// Sends a begin-typing event.
  Future<void> beginTyping() async {
    await _run('Begin typing', widget.conversation.beginTyping);
  }

  /// Sends an end-typing event.
  Future<void> endTyping() async {
    await _run('End typing', widget.conversation.endTyping);
  }

  /// Deletes up to two displayed server messages locally.
  Future<void> deleteMessages() async {
    final ids = _serverMessageIds();
    if (ids.isEmpty) return _showInputError('Load a server message first');
    await _run(
      'Delete messages',
      () => widget.conversation.deleteMessages(ids),
    );
  }

  /// Revokes up to two displayed server messages for all participants.
  Future<void> revokeMessages() async {
    final ids = _serverMessageIds();
    if (ids.isEmpty) return _showInputError('Load a server message first');
    await _run(
      'Revoke messages',
      () => widget.conversation.revokeMessages(ids, true),
    );
  }

  List<String> _serverMessageIds() => _messages
      .map((message) => message.id)
      .whereType<String>()
      .take(2)
      .toList();

  /// Deletes the current conversation and closes this screen on success.
  Future<void> deleteConversation() async {
    final result =
        await _run('Delete conversation', widget.conversation.delete);
    if (result['status'] == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _loadMessages(
    String operation,
    Future<Map<dynamic, dynamic>> Function() action,
  ) async {
    final result = await _run(operation, action);
    if (result['status'] != true || !mounted) return;
    final body = result['body'];
    if (body is List<StringeeMessage>) {
      setState(() {
        _messages
          ..clear()
          ..addAll(body);
      });
    }
  }

  Future<Map<dynamic, dynamic>> _run(
    String operation,
    Future<Map<dynamic, dynamic>> Function() action,
  ) async {
    if (mounted) setState(() => _loading = true);
    try {
      final result = await action();
      _appendLog(
        '$operation: ${result['status'] == true ? 'success' : result['message'] ?? 'failed'}',
      );
      return result;
    } catch (error) {
      _appendLog('$operation: $error');
      return <String, dynamic>{'status': false, 'message': '$error'};
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _upsertMessage(StringeeMessage message) {
    if (!mounted) return;
    setState(() {
      _messages.removeWhere(
        (item) => item.id == message.id && message.id != null,
      );
      _messages.insert(0, message);
    });
  }

  void _appendLog(String message) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, message);
      if (_logs.length > 50) _logs.removeLast();
    });
  }

  void _showInputError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showMessageActions(StringeeMessage message) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit message'),
              onTap: () async {
                Navigator.pop(context);
                await _run(
                    'Edit message', () => message.edit('Edited message'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: const Text('Pin / unpin message'),
              onTap: () async {
                Navigator.pop(context);
                await _run('Pin message', () => message.pinOrUnPin(true));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    messageController.dispose();
    participantController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversation.name ?? 'Conversation'),
            Text(
              widget.conversation.id ?? 'No conversation ID',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reload messages',
            onPressed: _loading ? null : loadLastMessages,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final messages = _buildMessages();
            final tools = _buildTools();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: messages),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: tools),
                      ],
                    )
                  : Column(
                      children: [messages, const SizedBox(height: 16), tools],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Messages (${_messages.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 180, maxHeight: 430),
              child: _messages.isEmpty
                  ? const Center(child: Text('No messages loaded'))
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _messages.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Text(
                              (message.senderId?.isNotEmpty == true
                                      ? message.senderId![0]
                                      : '?')
                                  .toUpperCase(),
                            ),
                          ),
                          title: Text(
                              message.text ?? message.type?.name ?? 'Message'),
                          subtitle: Text(
                            '${message.id ?? message.localId ?? 'pending'} • ${message.state?.name ?? 'unknown'}',
                          ),
                          trailing: const Icon(Icons.more_vert),
                          onTap: () => _showMessageActions(message),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('messageField'),
                    controller: messageController,
                    onSubmitted: (_) => sendMessage(),
                    decoration: const InputDecoration(
                      labelText: 'Text message',
                      prefixIcon: Icon(Icons.message_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  key: const Key('sendMessageButton'),
                  tooltip: 'Send message',
                  onPressed: _loading ? null : sendMessage,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTools() {
    final actions = <_ConversationAction>[
      _ConversationAction('Last messages', Icons.refresh, loadLastMessages),
      _ConversationAction('Local messages', Icons.storage, loadLocalMessages),
      _ConversationAction('Messages before', Icons.arrow_back, loadBefore),
      _ConversationAction('Messages after', Icons.arrow_forward, loadAfter),
      _ConversationAction(
          'Get selected', Icons.manage_search, getSelectedMessages),
      _ConversationAction('Add participant', Icons.person_add, addParticipant),
      _ConversationAction(
          'Remove participant', Icons.person_remove, removeParticipant),
      _ConversationAction(
          'Set member role', Icons.admin_panel_settings, setMemberRole),
      _ConversationAction(
          'Update name', Icons.drive_file_rename_outline, updateName),
      _ConversationAction('Begin typing', Icons.keyboard, beginTyping),
      _ConversationAction('End typing', Icons.keyboard_hide, endTyping),
      _ConversationAction('Mark as read', Icons.done_all, markAsRead),
      _ConversationAction(
          'Delete messages', Icons.delete_outline, deleteMessages),
      _ConversationAction('Revoke messages', Icons.undo, revokeMessages),
      _ConversationAction(
          'Delete conversation', Icons.delete_forever, deleteConversation),
    ];
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Conversation APIs',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: participantController,
              decoration: const InputDecoration(
                labelText: 'Participant user ID',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Conversation name',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
            const SizedBox(height: 14),
            ...actions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : action.callback,
                  icon: Icon(action.icon, size: 19),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(action.label),
                  ),
                ),
              ),
            ),
            const Divider(height: 24),
            Text('Event log', style: Theme.of(context).textTheme.titleMedium),
            if (_logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('No events yet'),
              )
            else
              ..._logs.take(12).map(
                    (log) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('• $log'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _ConversationAction {
  const _ConversationAction(this.label, this.icon, this.callback);

  final String label;
  final IconData icon;
  final FutureOr<void> Function() callback;
}
