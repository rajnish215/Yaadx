package com.example.yaadx

import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingReminder: String? = null
    private var remindersChannel: MethodChannel? = null
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        pendingReminder = intent.getStringExtra("reminderId")
        remindersChannel?.invokeMethod("openReminder", pendingReminder)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingReminder = intent?.getStringExtra("reminderId")
        remindersChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yaadx/reminders")
        remindersChannel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "schedule" -> { ReminderAlarms.save(this, org.json.JSONObject(call.argument<String>("record")!!)); result.success(null) }
                    "cancel" -> { ReminderAlarms.cancel(this, call.argument<String>("id")!!); result.success(null) }
                    "cancelAll" -> { ReminderAlarms.cancelAll(this); result.success(null) }
                    "canScheduleExact" -> result.success(ReminderAlarms.exact(this))
                    "requestExact" -> {
                        if (android.os.Build.VERSION.SDK_INT >= 31 && !ReminderAlarms.exact(this)) {
                            startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                        }
                        result.success(null)
                    }
                    "prepareVoice" -> VoiceRenderer.prepare(this, call.argument<String>("text")!!, result)
                    "takeLaunchReminder" -> { result.success(pendingReminder); pendingReminder = null }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) { result.error("reminder_error", error.message, null) }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yaadx/settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openNotificationSettings") {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"))
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("settings_unavailable", "Could not open phone settings", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
