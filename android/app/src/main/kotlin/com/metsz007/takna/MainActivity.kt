package com.metsz007.takna

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "takna/settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "openAlarmChannelSettings") {
                    startActivity(Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                        putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        putExtra(Settings.EXTRA_CHANNEL_ID, "takna_alarms")
                    })
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
