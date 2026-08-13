import 'package:chat_notification_sample/chat_screen.dart';
import 'package:chat_notification_sample/conversation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stringee_plugin/stringee_plugin.dart';

Map<String, dynamic> _conversationJson({
  String id = 'conv-1',
  String name = 'Test conversation',
}) =>
    <String, dynamic>{
      'id': id,
      'name': name,
      'isGroup': false,
      'updatedAt': 1000,
      'participants': <dynamic>[],
    };

Map<String, dynamic> _messageJson({
  String id = 'msg-1',
  String convId = 'conv-1',
  String text = 'Hello from server',
}) =>
    <String, dynamic>{
      'id': id,
      'localId': 'local-$id',
      'convId': convId,
      'senderId': 'alice',
      'createdAt': 1000,
      'sequence': 2,
      'type': MsgType.text.index,
      'state': MsgState.sent.index,
      'content': <String, dynamic>{'content': text},
    };

Map<String, dynamic> _successFor(MethodCall call) {
  dynamic body = <dynamic>[];
  switch (call.method) {
    case 'createConversation':
    case 'getConversationById':
    case 'getConversationByUserId':
      body = _conversationJson();
    case 'getLocalConversations':
    case 'getLastConversation':
    case 'getConversationsBefore':
    case 'getConversationsAfter':
      body = <dynamic>[_conversationJson()];
    case 'getLastMessages':
    case 'getLocalMessages':
    case 'getMessagesBefore':
    case 'getMessagesAfter':
    case 'getMessages':
      body = <dynamic>[_messageJson()];
    case 'addParticipants':
    case 'removeParticipants':
      body = <dynamic>[
        <String, dynamic>{'userId': 'bob', 'name': 'Bob'},
      ];
  }
  return <String, dynamic>{
    'status': true,
    'code': 0,
    'message': 'Success',
    'body': body,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  String? failingMethod;

  setUpAll(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.stringee.flutter.eventchannel'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(StringeeClient.methodChannel,
        (call) async {
      calls.add(call);
      if (call.method == failingMethod) {
        throw PlatformException(code: 'test_error', message: 'Test failure');
      }
      return _successFor(call);
    });
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    calls.clear();
    failingMethod = null;
  });

  testWidgets('shows token-based disconnected state without bundled token',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatScreen(enableNotifications: false)),
    );
    await tester.pump();

    expect(find.text('Stringee Chat Sample'), findsOneWidget);
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Connect to Stringee'), findsOneWidget);
    expect(find.byKey(const Key('tokenField')), findsOneWidget);
    expect(find.text('Logout'), findsNothing);
  });

  testWidgets('connects with entered token and persists it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatScreen(enableNotifications: false)),
    );
    await tester.pump();
    await tester.enterText(find.byKey(const Key('tokenField')), ' token-123 ');
    await tester.tap(find.byKey(const Key('connectButton')));
    await tester.pump();

    expect(find.text('Connecting…'), findsWidgets);
    expect(calls.any((call) => call.method == 'connect'), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(stringeeChatTokenKey), 'token-123');
  });

  testWidgets('renders connected API playground and logs SDK changes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatScreen(enableNotifications: false)),
    );
    await tester.pump();
    final state = tester.state<ChatScreenState>(find.byType(ChatScreen));
    state.client.eventStreamController.add(<dynamic, dynamic>{
      'eventType': StringeeClientEvents.didConnect,
      'body': null,
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.textContaining('Connected as'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Conversation input'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('Unread'), findsOneWidget);

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Logged out'), findsOneWidget);
  });

  testWidgets('handles connection failures, token expiry and chat changes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatScreen(enableNotifications: false)),
    );
    await tester.pumpAndSettle();
    final state = tester.state<ChatScreenState>(find.byType(ChatScreen));

    state.client.eventStreamController.add(<dynamic, dynamic>{
      'eventType': StringeeClientEvents.didDisconnect,
      'body': null,
    });
    await tester.pumpAndSettle();
    expect(state.status, 'Disconnected');

    state.client.eventStreamController.add(<dynamic, dynamic>{
      'eventType': StringeeClientEvents.didFailWithError,
      'body': <dynamic, dynamic>{'code': 7, 'message': 'Invalid token'},
    });
    await tester.pumpAndSettle();
    expect(state.status, 'Connect failed: Invalid token');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(stringeeChatTokenKey, 'expired-token');
    state.client.eventStreamController.add(<dynamic, dynamic>{
      'eventType': StringeeClientEvents.requestAccessToken,
      'body': null,
    });
    await tester.pumpAndSettle();
    expect(prefs.getString(stringeeChatTokenKey), isNull);
    expect(find.textContaining('Token expired'), findsOneWidget);

    state.chat.eventStreamController.add(<dynamic, dynamic>{
      'eventType': StringeeChatEvents.didReceiveObjectChange,
      'body': StringeeObjectChange(
        ChangeType.update,
        ObjectType.conversation,
        <dynamic>[
          StringeeConversation.fromJson(
            _conversationJson(name: 'Updated conversation'),
            state.client,
          ),
        ],
      ),
    });
    await tester.pump();
  });

  testWidgets('chat playground invokes all conversation query APIs',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ChatScreen(enableNotifications: false)),
    );
    await tester.pumpAndSettle();
    final state = tester.state<ChatScreenState>(find.byType(ChatScreen));

    state.participantController.text = 'bob';
    state.conversationController.text = 'conv-1';
    await state.createConversation();
    await state.getConversationById();
    await state.getConversationByUserId();
    await state.loadLocalConversations();
    await state.loadLatestConversations();
    await state.loadBefore();
    await state.loadAfter();
    await state.getTotalUnread();
    await state.clearDatabase();
    await state.loadAfter();
    await tester.pump();

    expect(
      calls.map((call) => call.method),
      containsAll(<String>[
        'createConversation',
        'getConversationById',
        'getConversationByUserId',
        'getLocalConversations',
        'getLastConversation',
        'getConversationsBefore',
        'getConversationsAfter',
        'getTotalUnread',
        'clearDb',
      ]),
    );

    state.participantController.clear();
    state.conversationController.clear();
    await state.createConversation();
    await state.getConversationById();
    await state.getConversationByUserId();
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('conversation screen exposes message and participant APIs',
      (tester) async {
    final client = StringeeClient();
    final chat = StringeeChat(client);
    final conversation = StringeeConversation.fromJson(
      <String, dynamic>{
        'id': 'conv-1',
        'name': 'Test conversation',
        'isGroup': false,
        'participants': <dynamic>[],
      },
      client,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Conversation(
          client: client,
          chat: chat,
          conversation: conversation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test conversation'), findsWidgets);
    expect(find.text('Messages (1)'), findsOneWidget);
    expect(find.byKey(const Key('messageField')), findsOneWidget);
    expect(find.text('Add participant'), findsOneWidget);
    expect(find.text('Mark as read'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('messageField')),
      'Hello Stringee',
    );
    final state = tester.state<ConversationState>(find.byType(Conversation));
    await state.sendMessage();
    await state.loadLocalMessages();
    await state.loadBefore();
    await state.loadAfter();
    await state.getSelectedMessages();

    state.participantController.text = 'bob';
    state.nameController.text = 'Renamed conversation';
    await state.addParticipant();
    await state.removeParticipant();
    await state.updateName();
    await state.setMemberRole();
    await state.markAsRead();
    await state.beginTyping();
    await state.endTyping();
    await state.deleteMessages();
    await state.revokeMessages();
    await tester.pump();

    expect(calls.any((call) => call.method == 'sendMessage'), isTrue);
    expect(
      calls.map((call) => call.method),
      containsAll(<String>[
        'getLocalMessages',
        'getMessagesBefore',
        'getMessagesAfter',
        'getMessages',
        'addParticipants',
        'removeParticipants',
        'updateConversation',
        'setRole',
        'markAsRead',
        'beginTyping',
        'endTyping',
        'deleteMessages',
        'revokeMessages',
      ]),
    );

    state.messageController.clear();
    state.participantController.clear();
    state.nameController.clear();
    await state.sendMessage();
    await state.addParticipant();
    await state.removeParticipant();
    await state.updateName();
    await state.setMemberRole();
    await tester.pump();

    failingMethod = 'beginTyping';
    await state.beginTyping();
    failingMethod = null;
    await tester.pump();
    expect(find.textContaining('Test failure'), findsOneWidget);

    final incomingMessage = StringeeMessage.fromJson(
      _messageJson(id: 'msg-2', text: 'Incoming message'),
      client,
    );
    chat.eventStreamController.add(<dynamic, dynamic>{
      'eventType': StringeeChatEvents.didReceiveObjectChange,
      'body': StringeeObjectChange(
        ChangeType.insert,
        ObjectType.message,
        <dynamic>[incomingMessage],
      ),
    });
    await tester.pump();
    expect(find.text('Incoming message'), findsOneWidget);

    await tester.tap(find.text('Incoming message'));
    await tester.pumpAndSettle();
    expect(find.text('Edit message'), findsOneWidget);
    await tester.tap(find.text('Edit message'));
    await tester.pumpAndSettle();
    expect(calls.any((call) => call.method == 'editMsg'), isTrue);

    chat.destroy();
  });
}
