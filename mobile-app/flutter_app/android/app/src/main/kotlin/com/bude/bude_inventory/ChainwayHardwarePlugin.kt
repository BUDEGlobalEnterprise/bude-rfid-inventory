package com.bude.bude_inventory

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.rscja.deviceapi.Barcode2D
import com.rscja.deviceapi.RFIDWithUHFUART
import com.rscja.deviceapi.entity.UHFTAGInfo
import com.rscja.deviceapi.interfaces.IUHFInventoryCallback
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

object ChainwayHardwarePlugin {
    private const val RFID_METHOD_CHANNEL = "bude.hardware/chainway/rfid"
    private const val RFID_EVENT_CHANNEL = "bude.hardware/chainway/rfid/events"
    private const val BARCODE_METHOD_CHANNEL = "bude.hardware/chainway/barcode"
    private const val BARCODE_EVENT_CHANNEL = "bude.hardware/chainway/barcode/events"

    fun register(engine: FlutterEngine, context: Context) {
        val appContext = context.applicationContext
        val rfid = ChainwayRfidBridge(appContext)
        MethodChannel(engine.dartExecutor.binaryMessenger, RFID_METHOD_CHANNEL)
            .setMethodCallHandler(rfid)
        EventChannel(engine.dartExecutor.binaryMessenger, RFID_EVENT_CHANNEL)
            .setStreamHandler(rfid)

        val barcode = ChainwayBarcodeBridge(appContext)
        MethodChannel(engine.dartExecutor.binaryMessenger, BARCODE_METHOD_CHANNEL)
            .setMethodCallHandler(barcode)
        EventChannel(engine.dartExecutor.binaryMessenger, BARCODE_EVENT_CHANNEL)
            .setStreamHandler(barcode)
    }
}

private class ChainwayRfidBridge(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var reader: RFIDWithUHFUART? = null
    private var eventSink: EventChannel.EventSink? = null
    private val connected = AtomicBoolean(false)
    private val inventorying = AtomicBoolean(false)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> runIo(result) {
                val r = getReader()
                val ok = connected.get() || r.init(context)
                connected.set(ok)
                ok
            }
            "disconnect" -> runIo(result) {
                stopInventoryInternal()
                val ok = reader?.free() ?: true
                connected.set(false)
                ok
            }
            "isConnected" -> result.success(connected.get())
            "startInventory" -> runIo(result) {
                ensureConnected()
                val r = getReader()
                r.setInventoryCallback(IUHFInventoryCallback { tag ->
                    emitTag(tag)
                })
                val ok = r.startInventoryTag()
                inventorying.set(ok)
                ok
            }
            "stopInventory" -> runIo(result) {
                stopInventoryInternal()
            }
            "readTag" -> runIo(result) {
                ensureConnected()
                tagToMap(getReader().inventorySingleTag())
            }
            "writeTagEpc" -> runIo(result) {
                ensureConnected()
                val epc = call.argument<String>("epc")
                    ?: throw IllegalArgumentException("epc is required")
                val password = call.argument<String>("accessPassword") ?: "00000000"
                requireHexPassword(password)
                getReader().writeDataToEpc(password, epc)
            }
            "lockTag" -> runIo(result) {
                ensureConnected()
                val bank = call.argument<String>("bank")
                    ?: throw IllegalArgumentException("bank is required")
                val password = call.argument<String>("accessPassword")
                    ?: throw IllegalArgumentException("accessPassword is required")
                requireHexPassword(password)
                getReader().lockMem(password, lockCodeFor(bank))
            }
            "killTag" -> runIo(result) {
                ensureConnected()
                val password = call.argument<String>("killPassword")
                    ?: throw IllegalArgumentException("killPassword is required")
                requireHexPassword(password)
                getReader().killTag(password)
            }
            "setPowerLevel" -> runIo(result) {
                ensureConnected()
                val dbm = call.argument<Int>("dbm")
                    ?: throw IllegalArgumentException("dbm is required")
                getReader().setPower(dbm)
            }
            "getPowerLevel" -> runIo(result) {
                ensureConnected()
                getReader().getPower()
            }
            "dispose" -> runIo(result) {
                stopInventoryInternal()
                reader?.free()
                connected.set(false)
                true
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun getReader(): RFIDWithUHFUART {
        val existing = reader
        if (existing != null) return existing
        return RFIDWithUHFUART.getInstance().also { reader = it }
    }

    private fun ensureConnected() {
        if (!connected.get()) {
            val ok = getReader().init(context)
            connected.set(ok)
        }
        if (!connected.get()) {
            throw IllegalStateException("Chainway UHF reader is not connected")
        }
    }

    private fun stopInventoryInternal(): Boolean {
        if (!inventorying.get()) return true
        val ok = reader?.stopInventory() ?: true
        inventorying.set(false)
        return ok
    }

    private fun emitTag(tag: UHFTAGInfo?) {
        val payload = tagToMap(tag) ?: return
        main.post { eventSink?.success(payload) }
    }

    private fun tagToMap(tag: UHFTAGInfo?): Map<String, Any?>? {
        if (tag == null || tag.getEPC().isNullOrBlank()) return null
        return mapOf(
            "epc" to tag.getEPC(),
            "tid" to tag.getTid(),
            "userMemory" to tag.getUser(),
            "rssi" to tag.getRssi()?.toIntOrNull(),
            "antenna" to tag.getAnt()?.toIntOrNull(),
            "timestampMillis" to System.currentTimeMillis(),
        )
    }

    private fun lockCodeFor(bank: String): String {
        val bits = IntArray(20)
        when (bank.lowercase(Locale.US)) {
            "epc" -> {
                bits[15] = 1
                bits[5] = 1
            }
            "tid" -> {
                bits[13] = 1
                bits[3] = 1
            }
            "user" -> {
                bits[11] = 1
                bits[1] = 1
            }
            else -> throw UnsupportedOperationException(
                "Chainway lockTag supports epc, tid, and user banks only",
            )
        }
        val binary = buildString {
            append("0000")
            for (i in bits.indices.reversed()) append(bits[i])
        }
        return binary.toLong(2).toString(16).padStart(6, '0')
    }

    private fun requireHexPassword(value: String) {
        require(value.length == 8 && value.matches(Regex("[0-9a-fA-F]+"))) {
            "password must be 8 hex characters"
        }
    }

    private fun runIo(result: MethodChannel.Result, block: () -> Any?) {
        executor.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (error: Throwable) {
                main.post {
                    result.error(
                        error::class.java.simpleName,
                        error.message ?: "Chainway RFID operation failed",
                        null,
                    )
                }
            }
        }
    }
}

private class ChainwayBarcodeBridge(
    private val context: Context,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private val main = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var scanner: Barcode2D? = null
    private var eventSink: EventChannel.EventSink? = null
    private val scanning = AtomicBoolean(false)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startScan" -> {
                ensureOpen()
                if (scanning.compareAndSet(false, true)) {
                    executor.execute { scanLoop() }
                }
                result.success(true)
            }
            "stopScan" -> {
                scanning.set(false)
                scanner?.stopScan()
                result.success(true)
            }
            "scanSingle" -> {
                val timeoutMillis = call.argument<Int>("timeoutMillis") ?: 30000
                executor.execute {
                    try {
                        val scanner = ensureOpen()
                        scanner.setTimeOut((timeoutMillis / 1000).coerceAtLeast(1))
                        val value = scanner.scan()
                        main.post { result.success(scanToMap(value)) }
                    } catch (error: Throwable) {
                        main.post {
                            result.error(
                                error::class.java.simpleName,
                                error.message ?: "Chainway barcode operation failed",
                                null,
                            )
                        }
                    }
                }
            }
            "dispose" -> {
                scanning.set(false)
                scanner?.stopScan()
                scanner?.close()
                scanner = null
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun ensureOpen(): Barcode2D {
        val existing = scanner
        if (existing != null && existing.isPowerOn) return existing
        return Barcode2D.getInstance().also {
            if (!it.open(context)) {
                throw IllegalStateException("Chainway barcode scanner failed to open")
            }
            scanner = it
        }
    }

    private fun scanLoop() {
        while (scanning.get()) {
            val value = try {
                ensureOpen().scan()
            } catch (error: Throwable) {
                main.post {
                    eventSink?.error(
                        error::class.java.simpleName,
                        error.message ?: "Chainway barcode scan failed",
                        null,
                    )
                }
                scanning.set(false)
                null
            }
            val payload = scanToMap(value)
            if (payload != null) {
                main.post { eventSink?.success(payload) }
            }
        }
    }

    private fun scanToMap(value: String?): Map<String, Any?>? {
        if (value.isNullOrBlank()) return null
        return mapOf(
            "barcode" to value,
            "format" to null,
            "timestampMillis" to System.currentTimeMillis(),
        )
    }
}
