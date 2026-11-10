package com.vazscan.app

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothSocket
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors

/** Нативный Bluetooth SPP для ELM327. Dart вызывает его через канал vazscan/bt. */
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var socket: BluetoothSocket? = null
    private var inp: InputStream? = null
    private var out: OutputStream? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vazscan/bt").setMethodCallHandler { call, result ->
            when (call.method) {
                "paired" -> result.success(paired())
                "connect" -> {
                    val addr = call.argument<String>("address") ?: ""
                    io.execute { reply(result) { connect(addr); true } }
                }
                "send" -> {
                    val cmd = call.argument<String>("cmd") ?: ""
                    val timeout = call.argument<Int>("timeout") ?: 3000
                    io.execute { reply(result) { sendCmd(cmd, timeout) } }
                }
                "disconnect" -> io.execute { close(); main.post { result.success(null) } }
                else -> result.notImplemented()
            }
        }
    }

    private fun <T> reply(result: MethodChannel.Result, block: () -> T) {
        try {
            val v = block()
            main.post { result.success(v) }
        } catch (e: Exception) {
            main.post { result.error("BT", e.message ?: "Ошибка Bluetooth", null) }
        }
    }

    @SuppressLint("MissingPermission")
    private fun paired(): List<Map<String, String>> {
        val ad = BluetoothAdapter.getDefaultAdapter() ?: return emptyList()
        return ad.bondedDevices.map { mapOf("name" to (it.name ?: "Без имени"), "address" to it.address) }
    }

    @SuppressLint("MissingPermission")
    private fun connect(addr: String) {
        close()
        val ad = BluetoothAdapter.getDefaultAdapter() ?: throw IllegalStateException("Bluetooth недоступен")
        val dev = ad.getRemoteDevice(addr)
        val uuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        var s = dev.createRfcommSocketToServiceRecord(uuid)
        try {
            s.connect()
        } catch (e: Exception) {
            try { s.close() } catch (_: Exception) {}
            val m = dev.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
            s = m.invoke(dev, 1) as BluetoothSocket
            s.connect()
        }
        socket = s
        inp = s.inputStream
        out = s.outputStream
    }

    private fun sendCmd(cmd: String, timeoutMs: Int): String {
        val o = out ?: throw IllegalStateException("Нет соединения")
        val i = inp ?: throw IllegalStateException("Нет соединения")
        while (i.available() > 0) i.read()
        o.write((cmd + "\r").toByteArray())
        o.flush()
        val sb = StringBuilder()
        val end = System.currentTimeMillis() + timeoutMs
        while (System.currentTimeMillis() < end) {
            if (i.available() > 0) {
                val c = i.read()
                if (c < 0) throw IllegalStateException("Соединение закрыто адаптером")
                val ch = c.toChar()
                if (ch == '>') return sb.toString()
                sb.append(ch)
            } else {
                Thread.sleep(8)
            }
        }
        return sb.toString()
    }

    private fun close() {
        try { socket?.close() } catch (_: Exception) {}
        socket = null
        inp = null
        out = null
    }

    override fun onDestroy() {
        io.execute { close() }
        io.shutdown()
        super.onDestroy()
    }
}
