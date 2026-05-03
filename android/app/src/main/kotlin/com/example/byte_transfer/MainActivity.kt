package com.example.byte_transfer

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "com.example.byte_transfer/background"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startForegroundService" -> {
                        val title = call.argument<String>("title") ?: "Libre-Send"
                        val body = call.argument<String>("body") ?: "Sharing files..."
                        startForegroundServiceInternal(title, body)
                        result.success(true)
                    }
                    "stopForegroundService" -> {
                        stopForegroundServiceInternal()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun startForegroundServiceInternal(title: String, body: String) {
        val intent = Intent(this, LibreSendForegroundService::class.java)
        intent.putExtra("title", title)
        intent.putExtra("body", body)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopForegroundServiceInternal() {
        val intent = Intent(this, LibreSendForegroundService::class.java)
        stopService(intent)
    }
}
