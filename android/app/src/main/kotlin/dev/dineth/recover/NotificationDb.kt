package dev.dineth.recover

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Writer side of the DB shared with Flutter (sqflite opens the same file). */
class NotificationDb private constructor(context: Context) :
    SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {

    override fun onConfigure(db: SQLiteDatabase) {
        db.enableWriteAheadLogging()
    }

    override fun onCreate(db: SQLiteDatabase) = createSchema(db)

    override fun onOpen(db: SQLiteDatabase) = createSchema(db)

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit

    private fun createSchema(db: SQLiteDatabase) {
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS chats(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                chat_key TEXT UNIQUE NOT NULL,
                title TEXT NOT NULL,
                is_group INTEGER NOT NULL DEFAULT 0,
                package TEXT NOT NULL,
                avatar_path TEXT,
                last_ts INTEGER NOT NULL DEFAULT 0)"""
        )
        db.execSQL(
            """CREATE TABLE IF NOT EXISTS messages(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                chat_id INTEGER NOT NULL REFERENCES chats(id) ON DELETE CASCADE,
                sender TEXT NOT NULL,
                text TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                received_at INTEGER NOT NULL,
                is_deleted_notice INTEGER NOT NULL DEFAULT 0)"""
        )
        db.execSQL(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_unique " +
                "ON messages(chat_id, sender, timestamp, text)"
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_chats_last_ts ON chats(last_ts DESC)")
    }

    /** Inserts or updates the chat row and returns its id. */
    fun upsertChat(
        key: String, title: String, isGroup: Boolean, pkg: String, lastTs: Long,
    ): Long {
        val db = writableDatabase
        db.execSQL(
            """INSERT INTO chats(chat_key, title, is_group, package, last_ts)
               VALUES(?,?,?,?,?)
               ON CONFLICT(chat_key) DO UPDATE SET
                 title = excluded.title,
                 is_group = excluded.is_group,
                 last_ts = MAX(last_ts, excluded.last_ts)""",
            arrayOf<Any>(key, title, if (isGroup) 1 else 0, pkg, lastTs),
        )
        db.rawQuery("SELECT id FROM chats WHERE chat_key = ?", arrayOf(key)).use {
            it.moveToFirst()
            return it.getLong(0)
        }
    }

    fun setAvatar(chatId: Long, path: String) {
        writableDatabase.execSQL(
            "UPDATE chats SET avatar_path = ? WHERE id = ?", arrayOf<Any>(path, chatId)
        )
    }

    /** Returns true if a new row was inserted (false for duplicates). */
    fun insertMessage(
        chatId: Long, sender: String, text: String, timestamp: Long, isDeletedNotice: Boolean,
    ): Boolean {
        val values = ContentValues().apply {
            put("chat_id", chatId)
            put("sender", sender)
            put("text", text)
            put("timestamp", timestamp)
            put("received_at", System.currentTimeMillis())
            put("is_deleted_notice", if (isDeletedNotice) 1 else 0)
        }
        return writableDatabase.insertWithOnConflict(
            "messages", null, values, SQLiteDatabase.CONFLICT_IGNORE
        ) != -1L
    }

    companion object {
        const val DB_NAME = "wa_notifications.db"
        private const val DB_VERSION = 1

        @Volatile private var instance: NotificationDb? = null

        fun get(context: Context): NotificationDb =
            instance ?: synchronized(this) {
                instance ?: NotificationDb(context.applicationContext).also { instance = it }
            }
    }
}
