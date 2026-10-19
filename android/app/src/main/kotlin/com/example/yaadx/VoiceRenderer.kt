package com.example.yaadx

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.Locale

object VoiceRenderer {
    fun prepare(context: Context, text: String, result: MethodChannel.Result) {
        val hash = MessageDigest.getInstance("SHA-256").digest(text.toByteArray()).joinToString("") { "%02x".format(it) }
        val folder = File(context.filesDir, "voice_alerts").apply { mkdirs() }
        val file = File(folder, "$hash.wav")
        fun uri(): String {
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.voice", file)
            context.grantUriPermission("com.android.systemui", uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            context.grantUriPermission("android", uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            return uri.toString()
        }
        if (file.exists() && file.length() > 44) { result.success(uri()); return }
        val handler = Handler(Looper.getMainLooper())
        var engine: TextToSpeech? = null
        var finished = false
        fun finish(ok: Boolean) {
            handler.post {
                if (!finished) {
                    finished = true
                    engine?.shutdown()
                    if (ok && file.exists() && file.length() > 44) result.success(uri())
                    else {
                        file.delete()
                        result.error("voice_unavailable", "Voice could not be prepared. Check your phone's text-to-speech engine or turn off voice alert.", null)
                    }
                }
            }
        }
        engine = TextToSpeech(context.applicationContext) { status ->
            handler.post {
                if (finished) return@post
                val tts = engine
                if (status != TextToSpeech.SUCCESS || tts == null || tts.setLanguage(Locale.ENGLISH) < 0) {
                    finish(false)
                } else {
                    tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(id: String?) {}
                        override fun onDone(id: String?) { finish(true) }
                        @Deprecated("Deprecated in Java")
                        override fun onError(id: String?) { finish(false) }
                    })
                    if (tts.synthesizeToFile(text, null, file, hash) != TextToSpeech.SUCCESS) finish(false)
                }
            }
        }
        handler.postDelayed({ finish(false) }, 20000)
    }
}
