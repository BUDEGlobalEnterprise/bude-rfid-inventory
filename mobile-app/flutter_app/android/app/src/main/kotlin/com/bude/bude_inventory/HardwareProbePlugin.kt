package com.bude.bude_inventory

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Answers Dart's `bude.hardware/probe` channel. Reads Build identifiers
 * + a small set of capability flags. Vendor-specific RFID detection
 * (Chainway / Zebra / Urovo) currently relies on Build.MANUFACTURER
 * matching — extend [detectCapabilities] when concrete SDK probes are
 * available.
 */
object HardwareProbePlugin {
    private const val CHANNEL = "bude.hardware/probe"

    fun register(engine: FlutterEngine, context: Context) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "probe") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val payload = mapOf(
                    "manufacturer" to (Build.MANUFACTURER ?: "unknown"),
                    "model" to (Build.MODEL ?: "unknown"),
                    "osVersion" to (Build.VERSION.RELEASE ?: ""),
                    "capabilities" to detectCapabilities(context),
                )
                result.success(payload)
            }
    }

    private fun detectCapabilities(context: Context): List<String> {
        val pm = context.packageManager
        val capabilities = mutableListOf<String>()

        if (pm.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            capabilities.add("camera")
        }
        if (pm.hasSystemFeature(PackageManager.FEATURE_USB_HOST)) {
            capabilities.add("usbRfidReader")
        }
        if (pm.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            capabilities.add("bluetoothRfidReader")
        }

        // Heuristic: vendor handhelds advertise an integrated UHF radio
        // via a known system feature ("com.<vendor>.uhf"). When we add
        // a real SDK integration these checks should be replaced with
        // SDK class lookups (e.g. RFIDWithUHFUART.getInstance()).
        val manufacturer = (Build.MANUFACTURER ?: "").lowercase()
        if (manufacturer.contains("chainway") ||
            manufacturer.contains("zebra") ||
            manufacturer.contains("urovo")) {
            capabilities.add("builtInRfidReader")
            capabilities.add("builtInBarcodeScanner")
        }
        if (manufacturer.contains("honeywell")) {
            capabilities.add("builtInBarcodeScanner")
        }

        return capabilities
    }
}
