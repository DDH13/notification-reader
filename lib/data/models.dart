class Chat {
  const Chat({
    required this.id,
    required this.title,
    required this.isGroup,
    required this.lastTs,
    this.avatarPath,
    this.lastText,
    this.lastSender,
  });

  final int id;
  final String title;
  final bool isGroup;
  final int lastTs;
  final String? avatarPath;
  final String? lastText;
  final String? lastSender;

  factory Chat.fromMap(Map<String, Object?> m) => Chat(
        id: m['id'] as int,
        title: m['title'] as String,
        isGroup: (m['is_group'] as int) == 1,
        lastTs: m['last_ts'] as int,
        avatarPath: m['avatar_path'] as String?,
        lastText: m['last_text'] as String?,
        lastSender: m['last_sender'] as String?,
      );
}

class Message {
  const Message({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    required this.isDeletedNotice,
  });

  final int id;
  final String sender;
  final String text;
  final int timestamp;
  final bool isDeletedNotice;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timestamp);

  factory Message.fromMap(Map<String, Object?> m) => Message(
        id: m['id'] as int,
        sender: m['sender'] as String,
        text: m['text'] as String,
        timestamp: m['timestamp'] as int,
        isDeletedNotice: (m['is_deleted_notice'] as int) == 1,
      );
}
