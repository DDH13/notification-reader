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
    this.mediaKind,
    this.mediaPath,
    this.mediaMime,
  });

  final int id;
  final String sender;
  final String text;
  final int timestamp;
  final bool isDeletedNotice;
  final String? mediaKind;
  final String? mediaPath;
  final String? mediaMime;

  DateTime get time => DateTime.fromMillisecondsSinceEpoch(timestamp);

  factory Message.fromMap(Map<String, Object?> m) => Message(
        id: m['id'] as int,
        sender: m['sender'] as String,
        text: m['text'] as String,
        timestamp: m['timestamp'] as int,
        isDeletedNotice: (m['is_deleted_notice'] as int) == 1,
        mediaKind: m['media_kind'] as String?,
        mediaPath: m['media_path'] as String?,
        mediaMime: m['media_mime'] as String?,
      );
}

/// A captured media file that has no message (see AppDb.unlinkedMedia).
class MediaItem {
  const MediaItem({
    required this.kind,
    required this.path,
    required this.origName,
    this.mime,
    this.fileTs,
  });

  final String kind;
  final String path;
  final String origName;
  final String? mime;
  final int? fileTs;

  factory MediaItem.fromMap(Map<String, Object?> m) => MediaItem(
        kind: m['kind'] as String,
        path: m['path'] as String,
        origName: m['orig_name'] as String,
        mime: m['mime'] as String?,
        fileTs: m['file_ts'] as int?,
      );
}
