package app.derafsh.drf.vpn

import app.derafsh.drf.DrfApplication
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Process
import android.system.OsConstants
import android.util.Log
import io.nekohasekai.libbox.ConnectionOwner
import io.nekohasekai.libbox.InterfaceUpdateListener
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.LocalDNSTransport
import io.nekohasekai.libbox.NeighborUpdateListener
import io.nekohasekai.libbox.NetworkInterfaceIterator
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.StringIterator
import io.nekohasekai.libbox.TunOptions
import io.nekohasekai.libbox.WIFIState
import java.net.Inet6Address
import java.net.InetSocketAddress
import java.net.InterfaceAddress
import java.net.NetworkInterface
import io.nekohasekai.libbox.NetworkInterface as LibboxNetworkInterface

/// Kotlin-side defaults for the libbox [PlatformInterface].
///
/// Only [openTun] and [autoDetectInterfaceControl] are implemented by the
/// VPN service; notification delegates are overridden there too. Everything
/// else is a safe no-op or an explicit error for features Derafsh does not
/// use (root shell, bridge, tailscale, SSH, ...).
interface DrfPlatformInterface : PlatformInterface {

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun autoDetectInterfaceControl(fd: Int) {}

    override fun openTun(options: TunOptions): Int {
        error("android: tun inbound requires VPN service")
    }

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int,
    ): ConnectionOwner {
        return try {
            val uid = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                DrfApplication.connectivity.getConnectionOwnerUid(
                    ipProtocol,
                    InetSocketAddress(sourceAddress, sourcePort),
                    InetSocketAddress(destinationAddress, destinationPort),
                )
            } else {
                Libbox.findConnectionOwner(
                    ipProtocol,
                    sourceAddress,
                    sourcePort,
                    destinationAddress,
                    destinationPort,
                ).userId
            }
            if (uid == Process.INVALID_UID) {
                error("android: connection owner not found")
            }
            val packages = DrfApplication.app.packageManager.getPackagesForUid(uid)
            ConnectionOwner().also { owner ->
                owner.userId = uid
                owner.userName = packages?.firstOrNull() ?: ""
                owner.setAndroidPackageNames(
                    StringArray((packages?.toList() ?: emptyList()).iterator()),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "findConnectionOwner", e)
            throw e
        }
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        NetworkMonitor.setListener(listener)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        NetworkMonitor.setListener(null)
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val cm = DrfApplication.connectivity
        val interfaces = mutableListOf<LibboxNetworkInterface>()
        val systemInterfaces = try {
            val enumeration = NetworkInterface.getNetworkInterfaces()
            if (enumeration != null) java.util.Collections.list(enumeration) else emptyList()
        } catch (_: Exception) {
            emptyList()
        }
        for (network in cm.allNetworks) {
            val linkProperties = cm.getLinkProperties(network) ?: continue
            val capabilities = cm.getNetworkCapabilities(network) ?: continue
            val boxInterface = LibboxNetworkInterface()
            val name = linkProperties.interfaceName
            val systemInterface = systemInterfaces.firstOrNull { it.name == name } ?: continue
            boxInterface.name = name
            boxInterface.dnsServer = StringArray(
                linkProperties.dnsServers.mapNotNull { it.hostAddress }.iterator(),
            )
            boxInterface.gateway = StringArray(
                linkProperties.routes
                    .filter { it.destination.prefixLength == 0 }
                    .mapNotNull { it.gateway }
                    .filterNot { it.isAnyLocalAddress }
                    .mapNotNull { it.hostAddress }
                    .iterator(),
            )
            boxInterface.type = when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ->
                    Libbox.InterfaceTypeWIFI
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ->
                    Libbox.InterfaceTypeCellular
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ->
                    Libbox.InterfaceTypeEthernet
                else -> Libbox.InterfaceTypeOther
            }
            boxInterface.index = systemInterface.index
            runCatching { boxInterface.mtu = systemInterface.mtu }
            boxInterface.addresses = StringArray(
                systemInterface.interfaceAddresses
                    .mapTo(mutableListOf()) { it.toPrefixString() }
                    .iterator(),
            )
            var flags = 0
            if (capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                flags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
            }
            if (systemInterface.isLoopback) flags = flags or OsConstants.IFF_LOOPBACK
            if (systemInterface.isPointToPoint) flags = flags or OsConstants.IFF_POINTOPOINT
            if (systemInterface.supportsMulticast()) flags = flags or OsConstants.IFF_MULTICAST
            boxInterface.flags = flags
            boxInterface.metered = !capabilities
                .hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            interfaces.add(boxInterface)
        }
        return InterfaceArray(interfaces.iterator())
    }

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun clearDNSCache() {}

    override fun readWIFIState(): WIFIState? = null

    override fun localDNSTransport(): LocalDNSTransport? = null

    override fun sendNotification(notification: io.nekohasekai.libbox.Notification) {
        error("android: notifications require VPN service")
    }

    override fun cancelNotification(identifier: String, typeID: Int) {}

    override fun startNeighborMonitor(listener: NeighborUpdateListener) {}

    override fun closeNeighborMonitor(listener: NeighborUpdateListener) {}

    override fun registerMyInterface(name: String) {}

    override fun usePlatformShell(): Boolean = false

    override fun checkPlatformShell() {
        error("not supported")
    }

    override fun openShellSession(
        user: io.nekohasekai.libbox.PlatformUser?,
        command: String?,
        environ: StringIterator?,
        term: String?,
        rows: Int,
        cols: Int,
    ): io.nekohasekai.libbox.ShellSession {
        error("not supported")
    }

    override fun lookupUser(username: String): io.nekohasekai.libbox.PlatformUser {
        error("not supported")
    }

    override fun lookupSFTPServer(): String {
        error("not supported")
    }

    override fun readSystemSSHHostKey(): String {
        error("not supported")
    }

    override fun tailscaleHostname(): String =
        "${Build.MANUFACTURER} ${Build.MODEL}".trim()

    override fun usePlatformBridge(): Boolean = false

    override fun createBridge(
        options: io.nekohasekai.libbox.BridgeOptions?,
    ): io.nekohasekai.libbox.BridgeSession {
        error("not supported")
    }

    private fun InterfaceAddress.toPrefixString(): String {
        val address = this.address
        return if (address is Inet6Address) {
            "${Inet6Address.getByAddress(address.address).hostAddress}/$networkPrefixLength"
        } else {
            "${address.hostAddress}/$networkPrefixLength"
        }
    }

    private class InterfaceArray(
        private val iterator: Iterator<LibboxNetworkInterface>,
    ) : NetworkInterfaceIterator {
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): LibboxNetworkInterface = iterator.next()
    }

    class StringArray(private val iterator: Iterator<String>) : StringIterator {
        override fun len(): Int = 0
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): String = iterator.next()
    }

    private companion object {
        const val TAG = "DrfPlatformInterface"
    }
}
