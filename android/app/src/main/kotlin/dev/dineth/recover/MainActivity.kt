package dev.dineth.recover

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var receiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> result.success(isListenerEnabled())
                "openPermissionSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val r = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) {
                        events.success("new_message")
                    }
                }
                receiver = r
                // NOT_EXPORTED is required on Android 14+ for non-system broadcasts.
                registerReceiver(
                    r, IntentFilter(WaNotificationListener.ACTION_NEW_MESSAGE),
                    Context.RECEIVER_NOT_EXPORTED,
                )
            }

            override fun onCancel(arguments: Any?) = unregister()
        })
    }

    override fun onDestroy() {
        unregister()
        super.onDestroy()
    }

    private fun unregister() {
        receiver?.let {
            try { unregisterReceiver(it) } catch (_: IllegalArgumentException) {}
        }
        receiver = null
    }

    private fun isListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
            ?: return false
        return flat.split(":").mapNotNull { ComponentName.unflattenFromString(it) }
            .any { it.packageName == packageName }
    }

    companion object {
        private const val METHOD_CHANNEL = "dev.dineth.recover/listener"
        private const val EVENT_CHANNEL = "dev.dineth.recover/messages"
    }
}
