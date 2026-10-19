package com.example.yaadx

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import android.media.MediaPlayer
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.time.LocalDate
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(AndroidJUnit4::class)
class ReminderDeviceTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext
    private fun record(id: String): JSONObject {
        val date = LocalDate.now().plusDays(12)
        return JSONObject().put("id", id).put("name", "QA Test").put("eventType", "Birthday")
            .put("year", date.year).put("month", date.monthValue).put("day", date.dayOfMonth)
            .put("hour", 18).put("minute", 30).put("yearly", true).put("advanceDays", 10)
    }
    private fun pending(id: String, offset: Int): PendingIntent? = PendingIntent.getBroadcast(context, 0,
        Intent(context, ReminderAlarmReceiver::class.java).setData(Uri.parse("yaadx://alarm/${Uri.encode(id)}/$offset")),
        PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)

    @Test fun saveEditAndCancelEveryAdvanceAlarm() {
        val id = "qa-device-alarm-test"
        try {
            val r = record(id)
            ReminderAlarms.save(context, r)
            for (offset in 0..10) assertNotNull("Missing offset $offset", pending(id, offset))
            ReminderAlarms.save(context, r.put("advanceDays", 1))
            assertNotNull(pending(id, 0)); assertNotNull(pending(id, 1))
            for (offset in 2..10) assertNull("Stale offset $offset", pending(id, offset))
        } finally { ReminderAlarms.cancel(context, id) }
        for (offset in 0..10) assertNull(pending(id, offset))
    }

    @Test fun spokenAudioIsPreparedAndUsedByNotification() {
        val id = "qa-device-voice-test"
        val latch = CountDownLatch(1)
        var uri: String? = null
        var error: String? = null
        instrumentation.runOnMainSync {
            VoiceRenderer.prepare(context, "This is a YaadX voice alert test.", object : MethodChannel.Result {
                override fun success(value: Any?) { uri = value as? String; latch.countDown() }
                override fun error(code: String, message: String?, details: Any?) { error = message; latch.countDown() }
                override fun notImplemented() { error = "Not implemented"; latch.countDown() }
            })
        }
        assertTrue("Voice preparation timed out", latch.await(25, TimeUnit.SECONDS))
        assertNull(error)
        assertNotNull(uri)
        context.contentResolver.openInputStream(Uri.parse(uri)).use { assertTrue(it!!.available() > 44) }
        // Decode and play the generated speech through Android, waiting for completion.
        val playback = CountDownLatch(1)
        var playbackError: String? = null
        var player: MediaPlayer? = null
        try {
            instrumentation.runOnMainSync {
                player = MediaPlayer().apply {
                    setDataSource(context, Uri.parse(uri))
                    setOnCompletionListener { playback.countDown() }
                    setOnErrorListener { _, what, extra ->
                        playbackError = "$what:$extra"
                        playback.countDown()
                        true
                    }
                    prepare()
                    assertTrue("Speech has no playable duration", duration > 0)
                    start()
                }
            }
            assertTrue("Speech playback did not complete", playback.await(20, TimeUnit.SECONDS))
            assertNull("Speech playback failed", playbackError)
        } finally {
            instrumentation.runOnMainSync { player?.release() }
        }
        try {
            ReminderAlarms.save(context, record(id).put("voiceUri", uri))
            ReminderAlarms.deliver(context, id, 0)
            val manager = context.getSystemService(NotificationManager::class.java)
            val channel = manager.getNotificationChannel("yaadx_voice_${uri!!.hashCode()}")
            assertEquals(Uri.parse(uri), channel.sound)
            if (manager.areNotificationsEnabled()) {
                assertTrue(manager.activeNotifications.any { it.id == ("$id:0".hashCode() and 0x7fffffff) })
            }
        } finally { ReminderAlarms.cancel(context, id) }
    }
}
