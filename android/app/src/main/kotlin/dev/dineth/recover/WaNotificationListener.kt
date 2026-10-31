package dev.dineth.recover

import android.app.Notification
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class WaNotificationListener : NotificationListenerService() {

    private val executor = Executors.newSingleThreadExecutor()

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in WA_PACKAGES) return
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        if (n.flags and Notification.FLAG_ONGOING_EVENT != 0) return
        if (n.category == Notification.CATEGORY_CALL) return

        // Resolve icons on the binder thread (needs a Context); DB work goes to the executor.
        val parsed = try {
            parse(sbn)
        } catch (e: Exception) {
            Log.w(TAG, "Failed to parse notification", e)
            null
        } ?: return

        executor.execute {
            try {
                store(parsed)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to store notification", e)
            }
        }
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        requestRebind(android.content.ComponentName(this, WaNotificationListener::class.java))
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    private class Msg(val sender: String, val text: String, val ts: Long)

    private class Parsed(
        val key: String, val title: String, val isGroup: Boolean, val pkg: String,
        val messages: List<Msg>, val avatar: Bitmap?,
    )

    private fun parse(sbn: StatusBarNotification): Parsed? {
        val n = sbn.notification
        val extras = n.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val style = NotificationCompat.MessagingStyle.extractMessagingStyleFromNotification(n)

        val convTitle = style?.conversationTitle?.toString()?.trim()?.takeIf { it.isNotEmpty() }
        val chatTitle = convTitle ?: title
        if (chatTitle.isEmpty() || isSummaryTitle(chatTitle)) return null

        val isGroup = style?.isGroupConversation ?: false
        val messages = mutableListOf<Msg>()
        if (style != null && style.messages.isNotEmpty()) {
            for (m in style.messages) {
                val text = m.text?.toString()?.trim().orEmpty()
                if (text.isEmpty()) continue
                val sender = m.person?.name?.toString()?.trim()?.takeIf { it.isNotEmpty() }
                    ?: chatTitle
                messages += Msg(sender, text, m.timestamp)
            }
        } else {
            val text = (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT))?.toString()?.trim().orEmpty()
            if (text.isEmpty() || isSummaryText(text)) return null
            messages += Msg(chatTitle, text, sbn.postTime)
        }
        if (messages.isEmpty()) return null

        val key = sbn.notification.shortcutId?.takeIf { it.isNotEmpty() }
            ?.let { "${sbn.packageName}|$it" } ?: "${sbn.packageName}|$chatTitle"

        val avatar = loadAvatar(n, style, isGroup)
        return Parsed(key, chatTitle, isGroup, sbn.packageName, messages, avatar)
    }

    private fun loadAvatar(
        n: Notification, style: NotificationCompat.MessagingStyle?, isGroup: Boolean,
    ): Bitmap? = try {
        val icon = n.getLargeIcon()
            ?: if (!isGroup) style?.messages?.lastOrNull()?.person?.icon?.toIcon(this) else null
        icon?.loadDrawable(this)?.toBitmap()
    } catch (e: Exception) {
        null
    }

    private fun Drawable.toBitmap(): Bitmap {
        val w = intrinsicWidth.coerceIn(1, 256)
        val h = intrinsicHeight.coerceIn(1, 256)
        return Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).also {
            setBounds(0, 0, w, h)
            draw(Canvas(it))
        }
    }

    private fun store(p: Parsed) {
        val db = NotificationDb.get(this)
        val lastTs = p.messages.maxOf { it.ts }
        val chatId = db.upsertChat(p.key, p.title, p.isGroup, p.pkg, lastTs)

        var inserted = false
        for (m in p.messages) {
            val deleted = m.text.equals(DELETED_TEXT, ignoreCase = true)
            if (db.insertMessage(chatId, m.sender, m.text, m.ts, deleted)) inserted = true
        }
        p.avatar?.let { saveAvatar(db, chatId, it) }

        if (inserted) {
            sendBroadcast(Intent(ACTION_NEW_MESSAGE).setPackage(packageName))
        }
    }

    private fun saveAvatar(db: NotificationDb, chatId: Long, bmp: Bitmap) {
        val dir = File(filesDir, "avatars").apply { mkdirs() }
        val file = File(dir, "$chatId.png")
        val tmp = File(dir, "$chatId.png.tmp")
        FileOutputStream(tmp).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        if (!tmp.renameTo(file)) return
        db.setAvatar(chatId, file.absolutePath)
    }

    private fun isSummaryTitle(t: String) =
        t.equals("WhatsApp", true) || t.equals("WhatsApp Business", true)

    private val summaryRegex =
        Regex("""^\d+ (new )?messages?( from \d+ chats?)?$""", RegexOption.IGNORE_CASE)

    private fun isSummaryText(t: String) =
        summaryRegex.matches(t) ||
            t.equals("Checking for new messages", true) ||
            t.startsWith("Backup in progress", true)

    companion object {
        const val ACTION_NEW_MESSAGE = "dev.dineth.recover.NEW_MESSAGE"
        private const val TAG = "WaNotificationListener"
        private const val DELETED_TEXT = "This message was deleted"
        private val WA_PACKAGES = setOf("com.whatsapp", "com.whatsapp.w4b")
    }
}
