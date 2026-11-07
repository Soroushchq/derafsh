package app.derafsh.drf.vpn

import android.os.ParcelFileDescriptor
import android.util.Log
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.OverrideOptions
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.SystemProxyStatus

/// Hosts the sing-box instance through libbox's CommandServer.
class BoxCore(
    private val vpnService: DrfVpnService,
    private val platformInterface: PlatformInterface,
) : CommandServerHandler {

    companion object {
        private const val TAG = "BoxCore"
    }

    var fileDescriptor: ParcelFileDescriptor? = null

    private var commandServer: CommandServer? = null

    @Volatile
    private var stopRequested = false

    fun startService(configContent: String) {
        stopRequested = false
        Thread {
            var server: CommandServer? = null
            try {
                val newServer = CommandServer(this, platformInterface)
                newServer.start()
                server = newServer
                commandServer = newServer
                if (stopRequested) {
                    // stop arrived while we were starting
                    closeServer(newServer)
                    VpnStateBus.setPhase("disconnected")
                    return@Thread
                }
                newServer.startOrReloadService(configContent, OverrideOptions())
                if (stopRequested) {
                    closeServer(newServer)
                    commandServer = null
                    closeTun()
                    VpnStateBus.setPhase("disconnected")
                    vpnService.selfStop()
                    return@Thread
                }
                VpnStateBus.setPhase("connected")
            } catch (e: Exception) {
                Log.e(TAG, "start service: ${e.message}", e)
                closeServer(server)
                commandServer = null
                closeTun()
                VpnStateBus.setPhaseWithError("disconnected", e.message ?: "start failed")
                vpnService.selfStop()
            }
        }.start()
    }

    fun stopService() {
        stopRequested = true
        closeTun()
        val server = commandServer
        commandServer = null
        if (server == null) {
            VpnStateBus.setPhase("disconnected")
            return
        }
        Thread {
            closeServer(server)
            VpnStateBus.setPhase("disconnected")
        }.start()
    }

    private fun closeTun() {
        val fd = fileDescriptor
        fileDescriptor = null
        try {
            fd?.close()
        } catch (_: Exception) {
        }
    }

    private fun closeServer(server: CommandServer?) {
        if (server == null) return
        try {
            server.closeService()
        } catch (e: Exception) {
            Log.w(TAG, "closeService: ${e.message}")
        }
        try {
            server.close()
        } catch (_: Exception) {
        }
    }

    // -------------------------------------------------- CommandServerHandler

    override fun serviceStop() {
        closeTun()
        closeServer(commandServer)
        commandServer = null
        VpnStateBus.setPhase("disconnected")
        vpnService.selfStop()
    }

    override fun serviceReload() {}

    override fun getSystemProxyStatus(): SystemProxyStatus? = null

    override fun setSystemProxyEnabled(enabled: Boolean) {}

    override fun triggerNativeCrash() {}

    override fun writeDebugMessage(message: String?) {
        Log.d(TAG, message ?: "")
    }

    override fun connectSSHAgent(): Int = -1
}
