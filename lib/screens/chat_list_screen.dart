import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../platform/listener_bridge.dart';
import '../util.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  List<Chat> _chats = const [];
  bool _loaded = false;
  bool _searching = false;
  String _query = '';
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = ListenerBridge.onNewMessage.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final chats = await AppDb.instance.chats();
    imageCache.clear(); // avatar files may have been rewritten in place
    if (mounted) {
      setState(() {
        _chats = chats;
        _loaded = true;
      });
    }
  }

  Future<void> _open(Chat chat) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => ChatScreen(chat: chat)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? _chats
        : _chats.where((c) => c.title.toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : const Text('Recover', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _query = '';
            }),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : shown.isEmpty
              ? _Empty(searching: q.isNotEmpty)
              : ListView.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 76),
                  itemBuilder: (_, i) => _ChatTile(
                    chat: shown[i],
                    onTap: () => _open(shown[i]),
                  ),
                ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.searching});
  final bool searching;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            searching
                ? 'No chats match your search.'
                : 'No messages captured yet.\nNew WhatsApp messages will '
                    'appear here as soon as their notifications arrive.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.chat, this.radius = 24});
  final Chat chat;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = chat.avatarPath;
    final file = path == null ? null : File(path);
    final hasImage = file != null && file.existsSync();
    return CircleAvatar(
      radius: radius,
      backgroundColor: senderColor(chat.title).withValues(alpha: 0.85),
      foregroundImage: hasImage ? FileImage(file) : null,
      child: Text(initials(chat.title),
          style: TextStyle(color: Colors.white, fontSize: radius * 0.75)),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.onTap});
  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = chat.lastText == null
        ? ''
        : chat.isGroup && chat.lastSender != null
            ? '${chat.lastSender}: ${chat.lastText}'
            : chat.lastText!;
    return ListTile(
      onTap: onTap,
      leading: ChatAvatar(chat: chat),
      title: Text(chat.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        formatListTime(DateTime.fromMillisecondsSinceEpoch(chat.lastTs)),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
