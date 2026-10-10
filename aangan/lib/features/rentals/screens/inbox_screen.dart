import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/aangan_app.dart';
import '../services/app_backend.dart';
import '../services/rental_repository.dart';
import '../widgets/common_widgets.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  Future<List<Map<String, dynamic>>>? _threads;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _refresh();
    if (AppBackend.isReady) {
      _authSubscription = AppBackend.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(_refresh);
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (AppBackend.currentUser == null) {
      _threads = null;
    } else {
      _threads = RentalRepository.instance.getMyConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AppBackend.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your conversations',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3),
        ),
        actions: <Widget>[
          if (user != null)
            IconButton(
              tooltip: 'Refresh messages',
              onPressed: () => setState(_refresh),
              icon: const Icon(Icons.refresh_rounded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !AppBackend.isReady
            ? _previewState()
            : user == null
                ? _signedOutState()
                : _threadList(),
      ),
    );
  }

  Widget _previewState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: <Widget>[
          const BackendNotice(),
          const Expanded(
            child: EmptyState(
              icon: Icons.forum_outlined,
              title: 'A private inbox, just for you',
              message:
                  'Ask about rent, move-in dates or house rules without sharing your mobile number.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _signedOutState() {
    return EmptyState(
      icon: Icons.mark_email_read_outlined,
      title: 'Sign in to see your chats',
      message:
          'Message a host privately. Your phone number stays hidden unless you choose to reveal it.',
      action: PrimaryButton(
        label: 'Sign in with email',
        icon: Icons.lock_open_rounded,
        expand: false,
        onPressed: _signIn,
      ),
    );
  }

  Widget _threadList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _threads,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load your inbox',
            message: 'Pull down or tap refresh to try again.',
          );
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AanganColors.forest),
          );
        }
        final conversations = snapshot.data!;
        if (conversations.isEmpty) {
          return const EmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No messages yet',
            message:
                'Open a home you like and tap “Message host”. Your conversations will appear here.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => setState(_refresh),
          color: AanganColors.forest,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              final latest = conversation['latest_message'] as Map<String, dynamic>?;
              final message = latest?['body']?.toString() ?? 'Say hello to the host';
              final mine = latest?['sender_id'] == AppBackend.currentUser?.id;
              final sentAt = DateTime.tryParse(
                latest?['created_at']?.toString() ?? '',
              );
              final date = sentAt == null ? '' : DateFormat('d MMM').format(sentAt);
              final title = conversation['listing_title']?.toString() ?? 'Bihar rental home';
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                child: InkWell(
                  borderRadius: BorderRadius.circular(17),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(
                        conversationId: conversation['id'].toString(),
                        listingTitle: title,
                      ),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: AanganColors.line),
                    ),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: AanganColors.paleGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.home_work_outlined,
                            color: AanganColors.forest,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AanganColors.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${mine ? 'You: ' : ''}$message',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AanganColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            if (date.isNotEmpty)
                              Text(
                                date,
                                style: const TextStyle(
                                  color: AanganColors.muted,
                                  fontSize: 9,
                                ),
                              ),
                            const SizedBox(height: 6),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: AanganColors.leaf,
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _signIn() async {
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const AuthScreen()),
    );
    if (!mounted) return;
    if (success == true) setState(_refresh);
  }
}
