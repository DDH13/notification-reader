package dev.dineth.recover

import android.content.Context
import android.os.Environment
import android.os.FileObserver
import android.util.Log
import android.webkit.MimeTypeMap
import java.io.File
import java.io.IOException
import java.util.concurrent.ExecutorService

/**
 * Watches WhatsApp's media folders, copies new incoming files into private storage
 * and links them to the notification message they belong to.
 */
class MediaWatcher(
    private val context: Context,
    private val executor: ExecutorService,
    private val onChanged: () -> Unit,
) {
    private val db = NotificationDb.get(context)
    private val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // Strong references: FileObserver stops delivering events once collected.
    private val observers = mutableListOf<FileObserver>()
    private val watched = mutableSetOf<String>()

    /** (Re)starts watching and runs the catch-up scan. No-op without All files access. */
    fun start() {
        try {
            executor.execute { startNow() }
        } catch (_: java.util.concurrent.RejectedExecutionException) {
        }
    }

    private fun startNow() {
        if (!Environment.isExternalStorageManager()) return
        val scanStart = System.currentTimeMillis()
        synchronized(this) {
            stop()
            refresh(scan = false)
        }
        catchUp(prefs.getLong(KEY_LAST_SCAN, installTime()))
        // Overlap a little; orig_name dedupes anything seen twice.
        prefs.edit().putLong(KEY_LAST_SCAN, scanStart - 60_000).apply()
    }

    @Synchronized
    fun stop() {
        observers.forEach { it.stopWatching() }
        observers.clear()
        watched.clear()
    }

    private fun installTime() =
        context.packageManager.getPackageInfo(context.packageName, 0).firstInstallTime

    private fun roots(): List<File> = WA_PACKAGES.flatMap { (pkg, name) ->
        listOf(File("$STORAGE/Android/media/$pkg/$name/Media"))
    }.filter { it.isDirectory }

    private fun mediaDirs(root: File): List<File> {
        val out = mutableListOf<File>()
        for (d in root.listFiles { f -> f.isDirectory && !f.name.startsWith(".") }.orEmpty()) {
            val kind = MediaKind.fromFolder(d.name) ?: continue
            out += d
            if (kind == MediaKind.VOICE) {
                out += d.listFiles { f -> f.isDirectory && f.name !in SKIPPED }.orEmpty()
            }
        }
        return out
    }

    /** Starts observers for any folder not watched yet. */
    @Synchronized
    private fun refresh(scan: Boolean) {
        for (root in roots()) {
            watch(root)
            for (dir in mediaDirs(root)) {
                if (watch(dir) && scan) scanDir(dir, System.currentTimeMillis() - 60_000)
            }
        }
    }

    private fun watch(dir: File): Boolean {
        if (!watched.add(dir.path)) return false
        val observer = object : FileObserver(listOf(dir), MASK) {
            override fun onEvent(event: Int, path: String?) = onFileEvent(dir, event, path)
        }
        observer.startWatching()
        observers += observer
        return true
    }

    // Runs on FileObserver's thread: only hands work to the executor.
    private fun onFileEvent(dir: File, event: Int, path: String?) {
        if (path == null) return
        val file = File(dir, path)
        val type = event and FileObserver.ALL_EVENTS
        try {
            if (file.isDirectory) {
                // New folder (e.g. the weekly voice-note folder): watch it too.
                if (type == FileObserver.CREATE || type == FileObserver.MOVED_TO) executor.execute { refresh(scan = true) }
            } else if (type == FileObserver.CLOSE_WRITE || type == FileObserver.MOVED_TO) {
                // CREATE is ignored for files: WhatsApp may still be writing them.
                executor.execute { handle(file) }
            }
        } catch (_: java.util.concurrent.RejectedExecutionException) {
        }
    }

    private fun handle(file: File) {
        try {
            if (process(file)) onChanged()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process ${file.name}", e)
        }
    }

    private fun catchUp(since: Long) {
        var changed = false
        for (root in roots()) {
            for (dir in mediaDirs(root)) changed = scanDir(dir, since) || changed
        }
        if (changed) onChanged()
    }

    private fun scanDir(dir: File, since: Long): Boolean {
        var changed = false
        for (f in dir.listFiles { f -> f.isFile && f.lastModified() > since }.orEmpty()) {
            try {
                changed = process(f) || changed
            } catch (e: Exception) {
                Log.e(TAG, "Failed to process ${f.name}", e)
            }
        }
        return changed
    }

    /** Copies the file privately and stores it. Returns true if a new row was added. */
    private fun process(file: File): Boolean {
        val kind = MediaKind.fromFile(file) ?: return false
        if (!file.isFile || file.length() == 0L || db.hasMedia(file.name)) return false

        val dir = File(context.filesDir, "media/${kind.key}").apply { mkdirs() }
        val dest = File(dir, file.name)
        val tmp = File(dir, "${file.name}.tmp")
        try {
            file.inputStream().use { i -> tmp.outputStream().use { o -> i.copyTo(o) } }
            if (!tmp.renameTo(dest)) {
                tmp.delete()
                return false
            }
        } catch (e: IOException) {
            tmp.delete()
            Log.w(TAG, "Failed to copy ${file.name}", e)
            return false
        }

        val ext = file.extension.lowercase()
        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: when (kind) {
            MediaKind.VOICE, MediaKind.AUDIO -> "audio/ogg"
            MediaKind.IMAGE -> "image/jpeg"
            MediaKind.VIDEO, MediaKind.GIF -> "video/mp4"
            MediaKind.STICKER -> "image/webp"
            MediaKind.DOCUMENT -> "application/octet-stream"
        }
        val id = db.insertMedia(
            kind.key, dest.absolutePath, file.name, mime, dest.length(), file.lastModified(),
        )
        if (id == -1L) return false
        tryMatch()
        return true
    }

    /**
     * Pairs unmatched files with pending messages of the same kind, oldest first,
     * when their timestamps are within [MATCH_WINDOW]. Works for either arrival order.
     */
    fun tryMatch() {
        val now = System.currentTimeMillis()
        var linked = false
        for (kind in MediaKind.entries) {
            val msgs = db.pendingMediaMessages(kind, now - MSG_LOOKBACK)
            if (msgs.isEmpty()) continue
            val files = db.unmatchedMedia(kind, now - MSG_LOOKBACK - MATCH_WINDOW)
            var mi = 0
            var fi = 0
            while (mi < msgs.size && fi < files.size) {
                val diff = files[fi].fileTs - msgs[mi].timestamp
                when {
                    diff < -MATCH_WINDOW -> fi++
                    diff > MATCH_WINDOW -> mi++
                    else -> {
                        db.linkMedia(files[fi].id, msgs[mi].id)
                        linked = true
                        mi++
                        fi++
                    }
                }
            }
        }
        if (linked) onChanged()
    }

    companion object {
        private const val TAG = "MediaWatcher"
        private const val PREFS = "media_watcher"
        private const val KEY_LAST_SCAN = "last_scan"
        private const val STORAGE = "/storage/emulated/0"
        private const val MASK = FileObserver.CLOSE_WRITE or FileObserver.MOVED_TO or
            FileObserver.CREATE
        private const val MATCH_WINDOW = 5 * 60_000L
        private const val MSG_LOOKBACK = 10 * 60_000L
        private val SKIPPED = setOf("Sent", "Private")
        private val WA_PACKAGES = listOf(
            "com.whatsapp" to "WhatsApp",
            "com.whatsapp.w4b" to "WhatsApp Business",
        )
    }
}
