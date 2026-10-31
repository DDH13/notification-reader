import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

/// Read access to the database written by the native listener service.
///
/// The schema is created with IF NOT EXISTS (identical to NotificationDb.kt)
/// so the UI can open the file before the service has ever written to it.
class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'wa_notifications.db');
    return openDatabase(
      path,
      version: 1,
      onOpen: (db) async {
        await db.execute('''CREATE TABLE IF NOT EXISTS chats(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          chat_key TEXT UNIQUE NOT NULL,
          title TEXT NOT NULL,
          is_group INTEGER NOT NULL DEFAULT 0,
          package TEXT NOT NULL,
          avatar_path TEXT,
          last_ts INTEGER NOT NULL DEFAULT 0)''');
        await db.execute('''CREATE TABLE IF NOT EXISTS messages(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          chat_id INTEGER NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
          sender TEXT NOT NULL,
          text TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          received_at INTEGER NOT NULL,
          is_deleted_notice INTEGER NOT NULL DEFAULT 0)''');
        await db.execute('''CREATE TABLE IF NOT EXISTS media(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          message_id INTEGER UNIQUE REFERENCES messages(id) ON DELETE SET NULL,
          kind TEXT NOT NULL,
          path TEXT NOT NULL,
          orig_name TEXT UNIQUE NOT NULL,
          mime TEXT,
          size INTEGER,
          file_ts INTEGER,
          captured_at INTEGER)''');
        await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_unique '
            'ON messages(chat_id, sender, timestamp, text)');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_chats_last_ts ON chats(last_ts DESC)');
      },
    );
  }

  Future<List<Chat>> chats() async {
    final db = await _database;
    const last = 'FROM messages WHERE chat_id = c.id '
        'ORDER BY timestamp DESC, id DESC LIMIT 1';
    final rows = await db.rawQuery('''
      SELECT c.*,
        (SELECT text $last) AS last_text,
        (SELECT sender $last) AS last_sender
      FROM chats c
      ORDER BY c.last_ts DESC''');
    return rows.map(Chat.fromMap).toList();
  }

  Future<List<Message>> messages(int chatId) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT messages.*, m.kind AS media_kind, m.path AS media_path,
        m.mime AS media_mime
      FROM messages LEFT JOIN media m ON m.message_id = messages.id
      WHERE messages.chat_id = ?
      ORDER BY messages.timestamp ASC, messages.id ASC''', [chatId]);
    return rows.map(Message.fromMap).toList();
  }

  /// Captured files that never matched a notification message.
  Future<List<MediaItem>> unlinkedMedia() async {
    final db = await _database;
    final rows = await db.query(
      'media',
      where: 'message_id IS NULL',
      orderBy: 'file_ts DESC, id DESC',
    );
    return rows.map(MediaItem.fromMap).toList();
  }
}
