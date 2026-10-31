package dev.dineth.recover

import java.io.File

/** Kinds of WhatsApp media; [key] is the value stored in media.kind. */
enum class MediaKind(val key: String) {
    VOICE("voice"), IMAGE("image"), VIDEO("video"), AUDIO("audio"),
    DOCUMENT("document"), STICKER("sticker"), GIF("gif");

    companion object {
        // Subfolders holding outgoing or non-incoming files.
        private val SKIPPED_DIRS = setOf("Sent", "Private")

        /** Maps notification text to the kind of media it announces, if any. */
        fun fromText(text: String): MediaKind? {
            val t = text.trim()
            return when {
                t.startsWith("🎤") || t.startsWith("Voice message", true) -> VOICE
                t.startsWith("📷") -> IMAGE
                t.startsWith("🎥") -> VIDEO
                t.startsWith("🎵") -> AUDIO
                t.startsWith("📄") -> DOCUMENT
                t.startsWith("Sticker", true) -> STICKER
                t.startsWith("GIF", true) -> GIF
                else -> null
            }
        }

        /** Maps a media folder name (also the WhatsApp Business variants) to a kind. */
        fun fromFolder(name: String): MediaKind? {
            val n = name.lowercase()
            return when {
                "voice notes" in n -> VOICE
                "animated gifs" in n -> GIF
                "images" in n -> IMAGE
                "video" in n -> VIDEO
                "audio" in n -> AUDIO
                "documents" in n -> DOCUMENT
                "stickers" in n -> STICKER
                else -> null
            }
        }

        private fun fromPrefix(name: String): MediaKind? = when {
            name.startsWith("PTT-") -> VOICE
            name.startsWith("IMG-") -> IMAGE
            name.startsWith("VID-") -> VIDEO
            name.startsWith("AUD-") -> AUDIO
            name.startsWith("DOC-") -> DOCUMENT
            name.startsWith("STK-") -> STICKER
            else -> null
        }

        /**
         * Maps a file under .../Media/ to a kind by its top-level folder, falling back
         * to WhatsApp's file-name prefix. Null for Sent/Private and hidden files.
         */
        fun fromFile(file: File): MediaKind? {
            if (file.name.startsWith(".")) return null
            // Ancestor folder names below Media/, innermost first.
            val chain = generateSequence(file.parentFile) { it.parentFile }
                .takeWhile { it.name != "Media" }
                .map { it.name }
                .toList()
            if (chain.isEmpty() || chain.any { it in SKIPPED_DIRS || it.startsWith(".") }) {
                return null
            }
            return fromFolder(chain.last()) ?: fromPrefix(file.name)
        }
    }
}
