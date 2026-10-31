import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../platform/listener_bridge.dart';
import '../util.dart';
import '../widgets/media_content.dart';
import 'chat_list_screen.dart' show ChatAvatar;

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.chat});
  final Chat chat;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  List<Message> _messages = const [];
  bool _loaded = false;
  StreamSubscription<void>? _sub;
  final _scroll = ScrollController();

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
    _scroll.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final msgs = await AppDb.instance.messages(widget.chat.id);
    if (!mounted) return;
    final atBottom = !_scroll.hasClients ||
        _scroll.position.maxScrollExtent - _scroll.offset < 80;
    final first = !_loaded;
    setState(() {
      _messages = msgs;
      _loaded = true;
    });
    if (first || atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          ChatAvatar(chat: chat, radius: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
      body: ColoredBox(
        color: const Color(0xFFECE5DD),
        child: Column(children: [
          Expanded(
            child: !_loaded
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet.'))
                    : _buildList(),
          ),
          const _OutgoingHint(),
        ]),
      ),
    );
  }

  Widget _buildList() {
    final items = <Widget>[];
    DateTime? prev;
    for (final m in _messages) {
      if (prev == null || !sameDay(prev, m.time)) {
        items.add(_DayChip(label: formatDayChip(m.time)));
      }
      items.add(_Bubble(message: m, showSender: widget.chat.isGroup));
      prev = m.time;
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: items,
    );
  }
}

class _OutgoingHint extends StatelessWidget {
  const _OutgoingHint();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SafeArea(
          top: false,
          child: Text(
            'Only incoming messages are captured. Messages you send do not '
            'create notifications, so they are not shown here.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.black54),
          ),
        ),
      );
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFE1F2FB),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.showSender});
  final Message message;
  final bool showSender;

  @override
  Widget build(BuildContext context) {
    final deleted = message.isDeletedNotice;
    final time = DateFormat.jm().format(message.time);
    final width = MediaQuery.sizeOf(context).width * 0.78;
    final kind = message.mediaKind;
    final path = message.mediaPath;
    final hasMedia = !deleted && kind != null && path != null;
    final caption = hasMedia ? mediaCaption(message.text) : message.text;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: width),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
        decoration: BoxDecoration(
          color: deleted ? const Color(0xFFEFEFEF) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 1, offset: Offset(0, 1)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSender)
              Text(message.sender,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: senderColor(message.sender),
                  )),
            if (hasMedia)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: MediaContent(kind: kind, path: path, mime: message.mediaMime),
              ),
            if (caption.isNotEmpty)
              Text(
                deleted ? '\u{1F6AB} $caption' : caption,
                style: TextStyle(
                  fontSize: 15,
                  fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
                  color: deleted ? Colors.black45 : Colors.black87,
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(time,
                  style: const TextStyle(fontSize: 11, color: Colors.black45)),
            ),
          ],
        ),
      ),
    );
  }
}
