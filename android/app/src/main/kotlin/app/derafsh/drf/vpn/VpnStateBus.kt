package app.derafsh.drf.vpn

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

/// Bridges the native VPN state into the Flutter EventChannel.
object VpnStateBus {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null

    @Volatile
    var pendingConfig: String? = null

    @Volatile
    private var phase = "disconnected"

    @Volatile
    private var error: String? = null

    fun setSink(sink: EventChannel.EventSink?) {
        this.sink = sink
        sink?.success(current())
    }

    fun setConfigPublic(config: String) {
        pendingConfig = config
    }

    fun current(): Map<String, Any?> = mapOf("state" to phase, "error" to error)

    fun setPhase(newPhase: String) {
        phase = newPhase
        error = null
        emit()
    }

    fun setPhaseWithError(newPhase: String, message: String?) {
        phase = newPhase
        error = message
        emit()
    }

    private fun emit() {
        mainHandler.post {
            sink?.success(current())
        }
    }
}
