package com.gotnull.socialmesh

import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Build
import android.util.Log
import com.nothing.ketchum.GlyphMatrixManager
import com.nothing.ketchum.GlyphMatrixFrame
import com.nothing.ketchum.GlyphMatrixObject
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

private const val TAG = "GlyphMatrixPlugin"
private const val MATRIX_SIZE = 25
// Device code for Nothing Phone 3 (not in the Community SDK, only in GlyphMatrix SDK)
private const val DEVICE_PHONE_3 = "23112"

/**
 * Flutter plugin for Nothing Phone 3 GlyphMatrix (25x25 LED matrix)
 * Device code: DEVICE_23112
 */
class GlyphMatrixPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var mGM: GlyphMatrixManager? = null
    private var mCallback: GlyphMatrixManager.Callback? = null
    private var isConnected = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "glyph_matrix")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        Log.d(TAG, "GlyphMatrixPlugin attached to engine")
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            mGM?.closeAppMatrix()
            mGM?.unInit()
        } catch (e: Exception) {
            Log.e(TAG, "Error during detach: ${e.message}")
        }
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isPhone3" -> {
                val model = Build.MODEL.lowercase()
                val isPhone3 = model.contains("a024") || 
                               model.contains("phone 3") || 
                               model.contains("phone(3)")
                Log.d(TAG, "isPhone3 check: model=$model, result=$isPhone3")
                result.success(isPhone3)
            }
            "init" -> {
                initGlyphMatrix(result)
            }
            "turnOff" -> {
                try {
                    mGM?.closeAppMatrix()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("TURN_OFF_ERROR", e.message, null)
                }
            }
            "setPixel" -> {
                val x = call.argument<Int>("x") ?: 0
                val y = call.argument<Int>("y") ?: 0
                val brightness = call.argument<Int>("brightness") ?: 255
                setPixel(x, y, brightness, result)
            }
            "setMatrix" -> {
                val pixels = call.argument<List<Int>>("pixels")
                if (pixels != null && pixels.size == MATRIX_SIZE * MATRIX_SIZE) {
                    setMatrix(pixels.toIntArray(), result)
                } else {
                    result.error("INVALID_PIXELS", "Expected ${MATRIX_SIZE * MATRIX_SIZE} pixels", null)
                }
            }
            "showPattern" -> {
                val pattern = call.argument<String>("pattern") ?: "pulse"
                showPattern(pattern, result)
            }
            "showText" -> {
                val text = call.argument<String>("text") ?: ""
                val brightness = call.argument<Int>("brightness") ?: 255
                showText(text, brightness, result)
            }
            "showProgress" -> {
                val progress = call.argument<Int>("progress") ?: 0
                val brightness = call.argument<Int>("brightness") ?: 255
                showProgress(progress, brightness, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun initGlyphMatrix(result: Result) {
        if (mGM != null && isConnected) {
            Log.d(TAG, "GlyphMatrix already initialized")
            result.success(true)
            return
        }

        try {
            mCallback = object : GlyphMatrixManager.Callback {
                override fun onServiceConnected(componentName: ComponentName) {
                    Log.d(TAG, "GlyphMatrix service connected")
                    try {
                        mGM?.register(DEVICE_PHONE_3)
                        isConnected = true
                        channel.invokeMethod("onServiceConnected", true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error registering device: ${e.message}")
                    }
                }

                override fun onServiceDisconnected(componentName: ComponentName) {
                    Log.d(TAG, "GlyphMatrix service disconnected")
                    isConnected = false
                    channel.invokeMethod("onServiceDisconnected", true)
                }
            }

            mGM = GlyphMatrixManager.getInstance(context)
            mGM?.init(mCallback)
            Log.d(TAG, "GlyphMatrix init called")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing GlyphMatrix: ${e.message}")
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun setPixel(x: Int, y: Int, brightness: Int, result: Result) {
        if (!isConnected) {
            result.error("NOT_CONNECTED", "GlyphMatrix not connected", null)
            return
        }

        try {
            val pixels = IntArray(MATRIX_SIZE * MATRIX_SIZE) { 0 }
            pixels[y * MATRIX_SIZE + x] = brightness
            mGM?.setAppMatrixFrame(pixels)
            result.success(null)
        } catch (e: Exception) {
            result.error("SET_PIXEL_ERROR", e.message, null)
        }
    }

    private fun setMatrix(pixels: IntArray, result: Result) {
        if (!isConnected) {
            result.error("NOT_CONNECTED", "GlyphMatrix not connected", null)
            return
        }

        try {
            mGM?.setAppMatrixFrame(pixels)
            result.success(null)
        } catch (e: Exception) {
            result.error("SET_MATRIX_ERROR", e.message, null)
        }
    }

    private fun showPattern(pattern: String, result: Result) {
        if (!isConnected) {
            result.error("NOT_CONNECTED", "GlyphMatrix not connected", null)
            return
        }

        try {
            val pixels = IntArray(MATRIX_SIZE * MATRIX_SIZE)
            
            when (pattern) {
                "pulse" -> {
                    // Fill center with brightness gradient
                    for (y in 0 until MATRIX_SIZE) {
                        for (x in 0 until MATRIX_SIZE) {
                            val dx = x - MATRIX_SIZE / 2
                            val dy = y - MATRIX_SIZE / 2
                            val dist = kotlin.math.sqrt((dx * dx + dy * dy).toDouble())
                            val brightness = (255 * (1 - dist / (MATRIX_SIZE / 2))).toInt().coerceIn(0, 255)
                            pixels[y * MATRIX_SIZE + x] = brightness
                        }
                    }
                }
                "border" -> {
                    // Draw border
                    for (i in 0 until MATRIX_SIZE) {
                        pixels[i] = 255 // Top
                        pixels[(MATRIX_SIZE - 1) * MATRIX_SIZE + i] = 255 // Bottom
                        pixels[i * MATRIX_SIZE] = 255 // Left
                        pixels[i * MATRIX_SIZE + MATRIX_SIZE - 1] = 255 // Right
                    }
                }
                "cross" -> {
                    // Draw X
                    for (i in 0 until MATRIX_SIZE) {
                        pixels[i * MATRIX_SIZE + i] = 255
                        pixels[i * MATRIX_SIZE + (MATRIX_SIZE - 1 - i)] = 255
                    }
                }
                "dots" -> {
                    // Dot pattern
                    for (y in 0 until MATRIX_SIZE step 4) {
                        for (x in 0 until MATRIX_SIZE step 4) {
                            pixels[y * MATRIX_SIZE + x] = 255
                        }
                    }
                }
                "full" -> {
                    // All on
                    for (i in 0 until pixels.size) {
                        pixels[i] = 255
                    }
                }
                else -> {
                    // Default: center dot
                    pixels[12 * MATRIX_SIZE + 12] = 255
                }
            }
            
            mGM?.setAppMatrixFrame(pixels)
            result.success(null)
        } catch (e: Exception) {
            result.error("PATTERN_ERROR", e.message, null)
        }
    }

    private fun showText(text: String, brightness: Int, result: Result) {
        if (!isConnected) {
            result.error("NOT_CONNECTED", "GlyphMatrix not connected", null)
            return
        }

        try {
            // Create a bitmap to render text
            val bitmap = Bitmap.createBitmap(MATRIX_SIZE, MATRIX_SIZE, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint().apply {
                color = Color.WHITE
                textSize = 20f
                isAntiAlias = false
            }
            
            // Center the text
            val textWidth = paint.measureText(text)
            val x = (MATRIX_SIZE - textWidth) / 2
            val y = MATRIX_SIZE / 2 + 7f
            
            canvas.drawText(text, x, y, paint)
            
            // Convert bitmap to pixel array
            val pixels = IntArray(MATRIX_SIZE * MATRIX_SIZE)
            for (py in 0 until MATRIX_SIZE) {
                for (px in 0 until MATRIX_SIZE) {
                    val pixel = bitmap.getPixel(px, py)
                    val gray = (Color.red(pixel) + Color.green(pixel) + Color.blue(pixel)) / 3
                    pixels[py * MATRIX_SIZE + px] = (gray * brightness / 255).coerceIn(0, 255)
                }
            }
            
            bitmap.recycle()
            mGM?.setAppMatrixFrame(pixels)
            result.success(null)
        } catch (e: Exception) {
            result.error("TEXT_ERROR", e.message, null)
        }
    }

    private fun showProgress(progress: Int, brightness: Int, result: Result) {
        if (!isConnected) {
            result.error("NOT_CONNECTED", "GlyphMatrix not connected", null)
            return
        }

        try {
            val pixels = IntArray(MATRIX_SIZE * MATRIX_SIZE)
            val fillRows = (MATRIX_SIZE * progress / 100).coerceIn(0, MATRIX_SIZE)
            
            // Fill from bottom up
            for (y in (MATRIX_SIZE - fillRows) until MATRIX_SIZE) {
                for (x in 0 until MATRIX_SIZE) {
                    pixels[y * MATRIX_SIZE + x] = brightness
                }
            }
            
            mGM?.setAppMatrixFrame(pixels)
            result.success(null)
        } catch (e: Exception) {
            result.error("PROGRESS_ERROR", e.message, null)
        }
    }
}
