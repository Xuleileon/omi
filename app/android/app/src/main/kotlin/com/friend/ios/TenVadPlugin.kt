package com.friend.ios

import android.content.Context
import android.util.Log
import com.friend.ios.tenvad.TenVad
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.nio.ByteBuffer
import java.nio.ByteOrder

class TenVadPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
  private val tag = "TEN_VAD"

  private var tenVad: TenVad? = null
  private var hopSize: Int = 256
  private var hopBuffer: ShortArray = ShortArray(hopSize)

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "init" -> {
        val hop = call.argument<Int>("hopSize") ?: 256
        val threshold = call.argument<Double>("threshold")?.toFloat() ?: 0.5f
        try {
          tenVad?.destroy()
          hopSize = hop
          hopBuffer = ShortArray(hopSize)
          tenVad = TenVad(hopSize, threshold)
          Log.d(tag, "TEN VAD init ok, version=${TenVad.getVersion()}, hopSize=$hopSize, threshold=$threshold")
          result.success(mapOf("version" to TenVad.getVersion()))
        } catch (e: Exception) {
          Log.e(tag, "TEN VAD init failed: ${e.message}")
          result.error("TEN_VAD_INIT_FAILED", e.message, null)
        }
      }

      "processPcm" -> {
        val bytes = call.argument<ByteArray>("pcm") ?: ByteArray(0)
        if (bytes.isEmpty() || tenVad == null) {
          result.success(mapOf("speech" to false, "probability" to 0.0))
          return
        }
        try {
          val shortCount = bytes.size / 2
          val shorts = ShortArray(shortCount)
          ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(shorts)

          var anySpeech = false
          var maxProb = 0.0f
          var i = 0
          while (i + hopSize <= shortCount) {
            System.arraycopy(shorts, i, hopBuffer, 0, hopSize)
            val res = tenVad!!.process(hopBuffer)
            if (res.probability > maxProb) {
              maxProb = res.probability
            }
            if (res.isVoiceDetected) {
              anySpeech = true
            }
            i += hopSize
          }

          result.success(mapOf("speech" to anySpeech, "probability" to maxProb))
        } catch (e: Exception) {
          Log.e(tag, "TEN VAD process failed: ${e.message}")
          result.error("TEN_VAD_PROCESS_FAILED", e.message, null)
        }
      }

      "release" -> {
        try {
          tenVad?.destroy()
          tenVad = null
          result.success(true)
        } catch (e: Exception) {
          Log.e(tag, "TEN VAD release failed: ${e.message}")
          result.error("TEN_VAD_RELEASE_FAILED", e.message, null)
        }
      }

      else -> result.notImplemented()
    }
  }
}

