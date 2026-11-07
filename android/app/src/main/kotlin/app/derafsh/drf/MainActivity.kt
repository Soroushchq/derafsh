package app.derafsh.drf

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import app.derafsh.drf.vpn.DrfVpnService
import app.derafsh.drf.vpn.VpnStateBus

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "app.derafsh.drf/vpn"
        private const val EVENTS = "app.derafsh.drf/vpn/events"
        private const val REQUEST_VPN = 1001
    }

    private var pendingVpnResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val config = call.argument<String>("config") ?: ""
                        if (config.isEmpty()) {
                            result.error("config", "empty config", null)
                            return@setMethodCallHandler
                        }
                        VpnStateBus.setConfigPublic(config)
                        val prepareIntent = VpnService.prepare(this)
                        if (prepareIntent != null) {
                            pendingVpnResult = result
                            startActivityForResult(prepareIntent, REQUEST_VPN)
                        } else {
                            launchVpnService(config)
                            result.success(true)
                        }
                    }

                    "stop" -> {
                        sendBroadcast(
                            Intent(DrfVpnService.ACTION_STOP).setPackage(packageName),
                        )
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    VpnStateBus.setSink(events)
                }

                override fun onCancel(arguments: Any?) {
                    VpnStateBus.setSink(null)
                }
            })
    }

    private fun launchVpnService(config: String) {
        val intent = Intent(this, DrfVpnService::class.java)
            .putExtra(DrfVpnService.EXTRA_CONFIG, config)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_VPN) return
        val result = pendingVpnResult
        pendingVpnResult = null
        if (resultCode == Activity.RESULT_OK) {
            if (result != null) {
                // A live Dart caller is waiting for this exact reply.
                val config = VpnStateBus.pendingConfig ?: ""
                launchVpnService(config)
                result.success(true)
            }
            // B14: result == null means the session that requested consent is
            // gone (activity recreated or process died while the dialog was
            // open — the engine, and with it the awaiting Dart isolate, died
            // too). Starting the VPN here would race the fresh UI (which
            // believes it is disconnected and would then double-start), so
            // the grant is dropped; the user can connect explicitly.
        } else {
            VpnStateBus.setPhaseWithError("disconnected", "دسترسی VPN داده نشد")
            result?.success(false)
        }
    }
}
