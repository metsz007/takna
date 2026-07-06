package com.metsz007.takna

import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ponytail: THE calibration knob. Hardware/OEM alarm-stream volume curves
// vary — a value that's a gentle wake on a Pixel can be too soft on some
// skins. Tune these three, nothing else. Guardrails that must hold:
// START must stay clearly audible (never near 0) and the ramp must reach
// full (1.0) within ~60s — a too-quiet/too-slow ramp is a slept-through
// alarm, which attacks the app's core promise.
private const val RAMP_START = 0.4f        // initial per-ring volume (0..1)
private const val RAMP_END = 1.0f          // full volume
private const val RAMP_DURATION_MS = 45_000L
private const val RAMP_STEP_MS = 3_000L    // step cadence (~15 steps)

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null
    private val rampHandler = Handler(Looper.getMainLooper())

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
                        rampHandler.removeCallbacksAndMessages(null) // clear any prior ramp
                        // Resolve the reminder's soundKey to a bundled raw resource
                        // by name; null/unknown key → the default alarm tone.
                        val key = call.argument<String>("sound")
                        val uri = if (key != null &&
                            resources.getIdentifier(key, "raw", packageName) != 0) {
                            android.net.Uri.parse("android.resource://$packageName/raw/$key")
                        } else {
                            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        }
                        ringtone = RingtoneManager.getRingtone(this, uri).apply {
                            audioAttributes = AudioAttributes.Builder()
                                .setUsage(AudioAttributes.USAGE_ALARM)
                                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                .build()
                            isLooping = true
                            play()
                        }
                        // Ringtone.volume (setVolume) is API 28+ — below that the
                        // alarm rings at full stream volume, exactly as before.
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            ringtone?.volume = RAMP_START
                            val steps = (RAMP_DURATION_MS / RAMP_STEP_MS).toInt()
                            for (i in 1..steps) {
                                rampHandler.postDelayed({
                                    // linear climb RAMP_START -> RAMP_END across the window
                                    val v = RAMP_START + (RAMP_END - RAMP_START) * i / steps
                                    ringtone?.let { if (it.isPlaying) it.volume = v.coerceAtMost(RAMP_END) }
                                }, RAMP_STEP_MS * i)
                            }
                        }
                        result.success(null)
                    }
                    "stopAlarm" -> {
                        rampHandler.removeCallbacksAndMessages(null)
                        ringtone?.stop()
                        ringtone = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        rampHandler.removeCallbacksAndMessages(null)
        ringtone?.stop()
        super.onDestroy()
    }
}
