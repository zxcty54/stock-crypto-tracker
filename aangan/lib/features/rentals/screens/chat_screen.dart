import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/aangan_app.dart';
import '../services/app_backend.dart';
import '../widgets/common_widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.listingTitle,
  });

  final String conversationId;
  final String listingTitle;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  bool _sending = false;
  String? _sendError;

  Stream<List<Map<String, dynamic>>> get _messageStream => AppBackend.client
      .from('messages')
      .stream(primaryKey: <String>['id'])
      .eq('conversation_id', widget.conversationId)
      .order('created_at', ascending: true);

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AppBackend.currentUser;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Aangan chat',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            Text(
              widget.listingTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AanganColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            color: AanganColors.paleGreen,
            child: const Text(
              'Private text chat · phone hidden by default · never send a token before visiting.',
              style: TextStyle(
                color: AanganColors.forest,
                fontSize: 10,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: user == null
                ? const EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Sign in to view messages',
                    message: 'Your conversations are visible only to you and the listing host.',
                  )
                : StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _messageStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const EmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: 'Chat could not connect',
                          message: 'Check the Supabase messages setup and try again.',
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AanganColors.forest,
                          ),
                        );
                      }
                      final messages = snapshot.data!;
                      if (messages.isEmpty) {
                        return const EmptyState(
                          icon: Icons.waving_hand_outlined,
                          title: 'Start with a friendly hello',
                          message: 'Ask about availability, the deposit or a safe time to view the home.',
                        );
                      }
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(15, 18, 15, 18),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[messages.length - 1 - index];
                          final mine = message['sender_id'] == user.id;
                          return _MessageBubble(
                            body: message['body']?.toString() ?? '',
                            sentAt: DateTime.tryParse(
                              message['created_at']?.toString() ?? '',
                            ),
                            mine: mine,
                          );
                        },
                      );
                    },
                  ),
          ),
          if (_sendError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _sendError!,
                style: const TextStyle(color: AanganColors.danger, fontSize: 11),
              ),
            ),
          _composer(),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AanganColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Write a message…',
                  counterText: '',
                  filled: true,
                  fillColor: AanganColors.canvas,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 47,
              height: 47,
              child: IconButton.filled(
                tooltip: 'Send',
                onPressed: _sending ? null : _sendMessage,
                style: IconButton.styleFrom(
                  backgroundColor: AanganColors.forest,
                  foregroundColor: Colors.white,
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 21),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final user = AppBackend.currentUser;
    final body = _messageController.text.trim();
    if (user == null || body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await AppBackend.client.from('messages').insert(<String, dynamic>{
        'conversation_id': widget.conversationId,
        'sender_id': user.id,
        'body': body,
      });
      _messageController.clear();
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _sendError = error.message);
    } catch (_) {
      if (mounted) setState(() => _sendError = 'Message send nahi hua. Phir try karein.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.body,
    required this.sentAt,
    required this.mine,
  });

  final String body;
  final DateTime? sentAt;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final timestamp = sentAt == null
        ? ''
        : '${sentAt!.hour.toString().padLeft(2, '0')}:${sentAt!.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(13, 10, 13, 7),
        decoration: BoxDecoration(
          color: mine ? AanganColors.forest : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: AanganColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                body,
                style: TextStyle(
                  color: mine ? Colors.white : AanganColors.ink,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            if (timestamp.isNotEmpty) ...<Widget>[
              const SizedBox(height: 3),
              Text(
                timestamp,
                style: TextStyle(
                  color: mine ? Colors.white70 : AanganColors.muted,
                  fontSize: 9,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
