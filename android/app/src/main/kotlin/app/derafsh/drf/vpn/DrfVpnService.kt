package app.derafsh.drf.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.net.IpPrefix
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.util.Log
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.TunOptions

/// The Android VPN service: creates the TUN device via VpnService.Builder and
/// runs the sing-box core ([BoxCore]) on top of it.
class DrfVpnService : VpnService(), DrfPlatformInterface {

    companion object {
        const val ACTION_STOP = "app.derafsh.drf.vpn.STOP"
        const val EXTRA_CONFIG = "config"
        private const val NOTIFICATION_ID = 42
        private const val CHANNEL_ID = "drf_vpn"
        private const val TAG = "DrfVpnService"
    }

    private val core = BoxCore(this, this)
    private var receiverRegistered = false

    private val stopReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_STOP) {
                shutdown()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            shutdown()
            return START_NOT_STICKY
        }
        if (!receiverRegistered) {
            if (Build.VERSION.SDK_INT >= 33) {
                registerReceiver(
                    stopReceiver,
                    IntentFilter(ACTION_STOP),
                    Context.RECEIVER_NOT_EXPORTED,
                )
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(stopReceiver, IntentFilter(ACTION_STOP))
            }
            receiverRegistered = true
        }
        startForegroundNotification()

        val config = intent?.getStringExtra(EXTRA_CONFIG) ?: VpnStateBus.pendingConfig
        if (config.isNullOrEmpty()) {
            shutdown()
            return START_NOT_STICKY
        }
        NetworkMonitor.start()
        VpnStateBus.setPhase("connecting")
        core.startService(config)
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = super.onBind(intent)

    override fun onRevoke() {
        shutdown()
    }

    override fun onDestroy() {
        if (receiverRegistered) {
            runCatching { unregisterReceiver(stopReceiver) }
            receiverRegistered = false
        }
        NetworkMonitor.stop()
        super.onDestroy()
    }

    // -------------------------------------------------- platform interface

    override fun autoDetectInterfaceControl(fd: Int) {
        protect(fd)
    }

    override fun openTun(options: TunOptions): Int {
        if (prepare(this) != null) error("android: missing vpn permission")

        val builder = Builder()
            .setSession("Derafsh")
            .setMtu(options.mtu)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        val inet4 = options.inet4Address
        while (inet4.hasNext()) {
            val prefix = inet4.next()
            builder.addAddress(prefix.address(), prefix.prefix())
        }
        val inet6 = options.inet6Address
        while (inet6.hasNext()) {
            val prefix = inet6.next()
            builder.addAddress(prefix.address(), prefix.prefix())
        }

        if (options.autoRoute) {
            if (options.dnsMode?.value != Libbox.DNSModeDisabled) {
                val dns = options.dnsServerAddress
                while (dns.hasNext()) {
                    builder.addDnsServer(dns.next())
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                var hasRoute4 = false
                val route4 = options.inet4RouteAddress
                while (route4.hasNext()) {
                    hasRoute4 = true
                    val prefix = route4.next()
                    builder.addRoute(IpPrefix("${prefix.address()}/${prefix.prefix()}"))
                }
                if (!hasRoute4) builder.addRoute("0.0.0.0", 0)

                var hasRoute6 = false
                val route6 = options.inet6RouteAddress
                while (route6.hasNext()) {
                    hasRoute6 = true
                    val prefix = route6.next()
                    builder.addRoute(IpPrefix("${prefix.address()}/${prefix.prefix()}"))
                }
                if (!hasRoute6) builder.addRoute("::", 0)

                val exclude4 = options.inet4RouteExcludeAddress
                while (exclude4.hasNext()) {
                    val prefix = exclude4.next()
                    builder.excludeRoute(IpPrefix("${prefix.address()}/${prefix.prefix()}"))
                }
                val exclude6 = options.inet6RouteExcludeAddress
                while (exclude6.hasNext()) {
                    val prefix = exclude6.next()
                    builder.excludeRoute(IpPrefix("${prefix.address()}/${prefix.prefix()}"))
                }
            } else {
                val range4 = options.inet4RouteRange
                while (range4.hasNext()) {
                    val prefix = range4.next()
                    builder.addRoute(prefix.address(), prefix.prefix())
                }
                val range6 = options.inet6RouteRange
                while (range6.hasNext()) {
                    val prefix = range6.next()
                    builder.addRoute(prefix.address(), prefix.prefix())
                }
            }
        }

        val pfd = builder.establish()
            ?: error("android: establish() failed (permission revoked?)")
        core.fileDescriptor = pfd
        return pfd.fd
    }

    // ------------------------------------------------------------ lifecycle

    fun selfStop() {
        stopForegroundCompat()
        stopSelf()
    }

    fun shutdown() {
        core.stopService()
        stopForegroundCompat()
        stopSelf()
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            @Suppress("DEPRECATION")
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    private fun startForegroundNotification() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "اتصال درفش",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val contentPi = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setContentTitle("درفش فعال است")
            .setContentText("اتصال امن برقرار است")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(contentPi)
        val notification = builder.build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}
