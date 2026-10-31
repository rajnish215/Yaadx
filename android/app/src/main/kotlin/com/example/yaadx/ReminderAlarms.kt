package com.example.yaadx

import android.app.*
import android.content.*
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import org.json.JSONObject
import java.time.*

// One calculation for initial alarms, yearly recurrence and reboot recovery.
object EventDates {
    fun occurrence(year: Int, month: Int, day: Int, hour: Int, minute: Int, zone: ZoneId): ZonedDateTime {
        val first = LocalDate.of(year, month, 1)
        return first.withDayOfMonth(minOf(day, first.lengthOfMonth())).atTime(hour, minute).atZone(zone)
    }
    fun next(startYear: Int, month: Int, day: Int, hour: Int, minute: Int,
             yearly: Boolean, daysBefore: Int, after: Instant, zone: ZoneId): Instant? {
        val year = if (yearly) maxOf(startYear, after.atZone(zone).year) else startYear
        for (candidate in year..if (yearly) year + 2 else year) {
            val time = occurrence(candidate, month, day, hour, minute, zone).minusDays(daysBefore.toLong()).toInstant()
            if (time.isAfter(after)) return time
        }
        return null
    }
}

object ReminderAlarms {
    private const val STORE = "yaadx_alarm_records"
    private fun prefs(c: Context) = c.getSharedPreferences(STORE, Context.MODE_PRIVATE)
    private fun alarm(c: Context) = c.getSystemService(AlarmManager::class.java)
    fun exact(c: Context) = Build.VERSION.SDK_INT < 31 || alarm(c).canScheduleExactAlarms()
    private fun notificationId(id: String, offset: Int) = ("$id:$offset".hashCode() and 0x7fffffff)
    private fun pending(c: Context, id: String, offset: Int): PendingIntent {
        val intent = Intent(c, ReminderAlarmReceiver::class.java)
            .setData(Uri.parse("yaadx://alarm/${Uri.encode(id)}/$offset"))
            .putExtra("id", id).putExtra("offset", offset)
        return PendingIntent.getBroadcast(c, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    fun save(c: Context, record: JSONObject) {
        val id = record.getString("id")
        cancel(c, id)
        check(prefs(c).edit().putString(id, record.toString()).commit()) { "Could not store alert" }
        scheduleRecord(c, record)
    }
    fun cancel(c: Context, id: String) {
        for (offset in 0..10) {
            val p = pending(c, id, offset)
            alarm(c).cancel(p)
            p.cancel()
            c.getSystemService(NotificationManager::class.java).cancel(notificationId(id, offset))
        }
        prefs(c).edit().remove(id).commit()
    }
    fun cancelAll(c: Context) {
        prefs(c).all.keys.toList().forEach { cancel(c, it) }
    }
    fun restore(c: Context) {
        prefs(c).all.values.toList().forEach { raw ->
            try { scheduleRecord(c, JSONObject(raw as String)) } catch (_: Exception) { /* Keep record for next retry. */ }
        }
    }
    private fun scheduleRecord(c: Context, record: JSONObject) {
        val advance = maxOf(record.optInt("advanceDays", 10).coerceIn(0, 10),
            if (record.optString("tomorrowVoiceUri").isNotEmpty()) 1 else 0)
        for (offset in 0..advance) schedule(c, record, offset)
    }
    private fun schedule(c: Context, r: JSONObject, offset: Int) {
        val time = EventDates.next(r.getInt("year"), r.getInt("month"), r.getInt("day"),
            r.getInt("hour"), r.getInt("minute"), r.optBoolean("yearly"), offset,
            Instant.now(), ZoneId.systemDefault()) ?: return
        val p = pending(c, r.getString("id"), offset)
        try {
            if (exact(c)) alarm(c).setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time.toEpochMilli(), p)
            else alarm(c).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time.toEpochMilli(), p)
        } catch (_: SecurityException) {
            // Permission may be revoked between checking and scheduling.
            alarm(c).setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, time.toEpochMilli(), p)
        }
    }
    fun deliver(c: Context, id: String, offset: Int) {
        val raw = prefs(c).getString(id, null) ?: return
        val r = JSONObject(raw)
        // Schedule the following year's occurrence even if notification permission is off.
        if (r.optBoolean("yearly")) schedule(c, r, offset)
        val manager = c.getSystemService(NotificationManager::class.java)
        val name = r.getString("name")
        val type = r.getString("eventType")
        val title = if (offset == 0) "$type: $name" else "$name's $type in $offset day${if (offset == 1) "" else "s"}"
        val body = when {
            offset == 1 -> "Tomorrow is the special day. Prepare your wish, gift or call."
            offset > 1 -> "Plan a gift, message or celebration before the special day."
            r.optString("note").isNotBlank() -> r.getString("note")
            else -> "Remember to call or wish $name today."
        }
        val voice = if (offset == 1) r.optString("tomorrowVoiceUri") else ""
        val channelId = if (voice.isEmpty()) "yaadx_event_alerts_v2" else "yaadx_voice_${voice.hashCode()}"
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(channelId, if (voice.isEmpty()) "Event reminders" else "Spoken event reminder", NotificationManager.IMPORTANCE_HIGH)
            if (voice.isNotEmpty()) channel.setSound(Uri.parse(voice), AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT).setContentType(AudioAttributes.CONTENT_TYPE_SPEECH).build())
            manager.createNotificationChannel(channel)
        }
        val open = Intent(c, MainActivity::class.java).putExtra("reminderId", id)
            .setData(Uri.parse("yaadx://event/${Uri.encode(id)}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val tap = PendingIntent.getActivity(c, 0, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, channelId) else Notification.Builder(c)
        builder.setSmallIcon(android.R.drawable.ic_popup_reminder).setContentTitle(title).setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body)).setContentIntent(tap).setAutoCancel(true)
        if (Build.VERSION.SDK_INT < 26 && voice.isNotEmpty()) builder.setSound(Uri.parse(voice))
        try { manager.notify(notificationId(id, offset), builder.build()) } catch (_: SecurityException) { /* OS permission disabled. */ }
    }
}

class ReminderAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra("id") ?: return
        ReminderAlarms.deliver(context, id, intent.getIntExtra("offset", 0))
    }
}
class ReminderRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) { ReminderAlarms.restore(context) }
}
