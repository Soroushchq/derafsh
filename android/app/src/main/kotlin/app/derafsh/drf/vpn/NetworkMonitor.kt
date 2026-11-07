package app.derafsh.drf.vpn

import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.util.Log
import io.nekohasekai.libbox.InterfaceUpdateListener
import java.net.NetworkInterface

/// Tracks the default network and feeds interface updates to libbox.
object NetworkMonitor {
    private const val TAG = "NetworkMonitor"

    private var listener: InterfaceUpdateListener? = null
    private var defaultNetwork: Network? = null
    private var registered = false

    private val callbackHandler by lazy {
        Handler(HandlerThread("drf-net-callback").apply { start() }.looper)
    }

    private val callback = object : ConnectivityManager.NetworkCallback() {
        override fun onAvailable(network: Network) {
            defaultNetwork = network
            notifyListener()
        }

        override fun onLinkPropertiesChanged(network: Network, linkProperties: android.net.LinkProperties) {
            defaultNetwork = network
            notifyListener()
        }

        override fun onLost(network: Network) {
            if (defaultNetwork == network) {
                defaultNetwork = null
            }
            notifyListener()
        }
    }

    private val request = NetworkRequest.Builder()
        .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        .addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_RESTRICTED)
        .build()

    fun start() {
        if (registered) return
        val cm = DrfApplication.connectivity
        try {
            when {
                Build.VERSION.SDK_INT >= 31 ->
                    cm.registerBestMatchingNetworkCallback(request, callback, callbackHandler)
                Build.VERSION.SDK_INT >= 28 ->
                    cm.requestNetwork(request, callback, callbackHandler)
                else ->
                    @Suppress("DEPRECATION")
                    cm.registerDefaultNetworkCallback(callback)
            }
            registered = true
        } catch (e: Exception) {
            Log.w(TAG, "register network callback: ${e.message}")
        }
        defaultNetwork = cm.activeNetwork
    }

    fun stop() {
        if (!registered) return
        runCatching {
            DrfApplication.connectivity.unregisterNetworkCallback(callback)
        }
        registered = false
        defaultNetwork = null
    }

    fun setListener(l: InterfaceUpdateListener?) {
        listener = l
        notifyListener()
    }

    private fun notifyListener() {
        val l = listener ?: return
        val network = defaultNetwork
        if (network == null) {
            l.updateDefaultInterface("", -1, false, false)
            return
        }
        for (i in 0 until 10) {
            val linkProperties = DrfApplication.connectivity.getLinkProperties(network)
            if (linkProperties == null) {
                Thread.sleep(100)
                continue
            }
            val name = linkProperties.interfaceName
            val index = try {
                NetworkInterface.getByName(name)?.index ?: -1
            } catch (_: Exception) {
                -1
            }
            l.updateDefaultInterface(name, index, false, false)
            return
        }
        l.updateDefaultInterface("", -1, false, false)
    }
}
