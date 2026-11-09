package com.kedai.kedai_abs

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Prints raw ESC/POS bytes to paired classic-Bluetooth thermal printers.
 * Only bonded devices are used, so no scan or location permission is needed.
 */
class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // Touched only on [executor] so print jobs never interleave.
    private var socket: BluetoothSocket? = null
    private var socketAddress: String? = null

    private var pendingPermission: ((Boolean) -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    override fun onDestroy() {
        executor.execute { closeSocket() }
        executor.shutdown()
        super.onDestroy()
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPairedPrinters" -> withBluetoothPermission(result) { listPairedPrinters(result) }
            "print" -> {
                val address = call.argument<String>("address")
                val bytes = call.argument<ByteArray>("bytes")
                if (address.isNullOrEmpty() || bytes == null) {
                    result.error("INVALID_ARGS", "Alamat printer atau data cetak kosong.", null)
                    return
                }
                withBluetoothPermission(result) { printBytes(address, bytes, result) }
            }
            "disconnect" -> executor.execute {
                closeSocket()
                mainHandler.post { result.success(null) }
            }
            else -> result.notImplemented()
        }
    }

    private fun hasBluetoothPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun withBluetoothPermission(result: MethodChannel.Result, action: () -> Unit) {
        // Before Android 12, BLUETOOTH is an install-time permission.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || hasBluetoothPermission()) {
            action()
            return
        }
        if (pendingPermission != null) {
            result.error("PERMISSION_PENDING", "Permintaan izin Bluetooth sedang berjalan.", null)
            return
        }
        pendingPermission = { granted ->
            if (granted) {
                action()
            } else {
                result.error("PERMISSION_DENIED", "Izin Bluetooth ditolak.", null)
            }
        }
        requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), REQUEST_BLUETOOTH)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_BLUETOOTH) return
        val callback = pendingPermission
        pendingPermission = null
        callback?.invoke(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED,
        )
    }

    private fun bluetoothAdapter(): BluetoothAdapter? =
        (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    @SuppressLint("MissingPermission")
    private fun listPairedPrinters(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth tidak tersedia.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Bluetooth mati.", null)
            return
        }
        try {
            val devices = adapter.bondedDevices.orEmpty().map { device ->
                mapOf("name" to (device.name ?: device.address), "address" to device.address)
            }
            result.success(devices)
        } catch (e: SecurityException) {
            result.error("PERMISSION_DENIED", e.message, null)
        }
    }

    private fun printBytes(address: String, bytes: ByteArray, result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth tidak tersedia.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("BLUETOOTH_OFF", "Bluetooth mati.", null)
            return
        }
        if (!BluetoothAdapter.checkBluetoothAddress(address)) {
            result.error("INVALID_ADDRESS", "Alamat printer tidak valid.", null)
            return
        }
        executor.execute {
            try {
                writeWithRetry(adapter, address, bytes)
                mainHandler.post { result.success(true) }
            } catch (e: IOException) {
                closeSocket()
                mainHandler.post { result.error("PRINT_FAILED", e.message, null) }
            } catch (e: SecurityException) {
                closeSocket()
                mainHandler.post { result.error("PERMISSION_DENIED", e.message, null) }
            }
        }
    }

    private fun writeWithRetry(adapter: BluetoothAdapter, address: String, bytes: ByteArray) {
        try {
            write(connect(adapter, address), bytes)
        } catch (e: IOException) {
            // A cached socket goes stale when the printer sleeps or restarts.
            closeSocket()
            write(connect(adapter, address), bytes)
        }
    }

    private fun connect(adapter: BluetoothAdapter, address: String): BluetoothSocket {
        val current = socket
        if (current != null && socketAddress == address && current.isConnected) {
            return current
        }
        closeSocket()
        val opened = openSocket(adapter.getRemoteDevice(address))
        socket = opened
        socketAddress = address
        return opened
    }

    @SuppressLint("MissingPermission")
    private fun openSocket(device: BluetoothDevice): BluetoothSocket {
        val factories = listOf<() -> BluetoothSocket>(
            { device.createRfcommSocketToServiceRecord(SPP_UUID) },
            // Some low-cost printers only accept insecure RFCOMM connections.
            { device.createInsecureRfcommSocketToServiceRecord(SPP_UUID) },
        )
        var lastError: IOException? = null
        for (factory in factories) {
            var candidate: BluetoothSocket? = null
            try {
                candidate = factory()
                candidate.connect()
                return candidate
            } catch (e: IOException) {
                lastError = e
                try {
                    candidate?.close()
                } catch (ignored: IOException) {
                }
            }
        }
        throw lastError ?: IOException("Tidak dapat terhubung ke printer.")
    }

    private fun write(target: BluetoothSocket, bytes: ByteArray) {
        val output = target.outputStream
        output.write(bytes)
        output.flush()
    }

    private fun closeSocket() {
        try {
            socket?.close()
        } catch (ignored: IOException) {
        }
        socket = null
        socketAddress = null
    }

    companion object {
        private const val CHANNEL = "kedai_abs/bluetooth_printer"
        private const val REQUEST_BLUETOOTH = 4101
        // Standard Serial Port Profile UUID used by ESC/POS Bluetooth printers.
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }
}
