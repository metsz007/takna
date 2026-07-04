package com.metsz007.takna

import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "takna/settings")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAlarmChannelSettings" -> {
                        startActivity(Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            putExtra(Settings.EXTRA_CHANNEL_ID, "takna_alarms")
                        })
                        result.success(null)
                    }
                    "playAlarm" -> {
                        ringtone?.stop()
                        ringtone = RingtoneManager.getRingtone(
                            this,
                            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ).apply {
                            audioAttributes = AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                            isLooping = true
                            play()
                        }
                        result.success(null)
                    }
                    "stopAlarm" -> {
                        ringtone?.stop()
                        ringtone = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        ringtone?.stop()
        super.onDestroy()
    }
}
