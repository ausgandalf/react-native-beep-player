package com.beepplayer

import android.media.*
import android.os.Handler
import android.os.Looper
import com.facebook.react.bridge.*
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.modules.core.DeviceEventManagerModule
import kotlin.math.PI
import kotlin.math.sin

class BeepPlayerModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

    private var isPlaying = false
    private var isMuted = false
    private var bpm: Double = 120.0
    private var sampleRate: Int = 44100
    private var beepDurationSeconds: Double = 0.05
    private var beepFrequency: Double = 1000.0

    private var beepBuffer: FloatArray? = null
    private var beepBufferSampleCount: Int = 0

    private var audioTrack: AudioTrack? = null
    private var handler: Handler = Handler(Looper.getMainLooper())
    private var beatRunnable: Runnable? = null
    private var totalBeats: Int = 64

    override fun getName(): String = "BeepPlayer"

    @ReactMethod
    fun start(bpm: Double, beepFile: String?) {
        stop()
        this.bpm = bpm

        beepFile?.let { loadBeepFile(it) }

        preRenderTrack()
        startBeatEvents()

        audioTrack?.play()
        isPlaying = true
    }

    @ReactMethod
    fun stop() {
        isPlaying = false
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
        beatRunnable?.let { handler.removeCallbacks(it) }
        beatRunnable = null
    }

    @ReactMethod
    fun mute(value: Boolean) {
        isMuted = value
    }

    // Pre-render the entire metronome buffer
    private fun preRenderTrack() {
        val samplesPerBeat = (60.0 / bpm * sampleRate).toInt()
        val beepSamples = if (beepBuffer != null) beepBufferSampleCount else (beepDurationSeconds * sampleRate).toInt()
        val totalSamples = totalBeats * samplesPerBeat
        val trackBuffer = FloatArray(totalSamples)

        var sampleIndex = 0
        for (beat in 0 until totalBeats) {
            for (i in 0 until samplesPerBeat) {
                val isBeepPlaying = i < beepSamples
                trackBuffer[sampleIndex] = if (isMuted || !isBeepPlaying) {
                    0f
                } else {
                    if (beepBuffer != null) {
                        beepBuffer!![i % beepBufferSampleCount]
                    } else {
                        val theta = 2.0 * PI * beepFrequency * (i % beepSamples) / sampleRate
                        (sin(theta) * 0.3).toFloat()
                    }
                }
                sampleIndex++
            }
        }

        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
            .setSampleRate(sampleRate)
            .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
            .build()

        val attr = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()

        audioTrack = AudioTrack.Builder()
            .setAudioAttributes(attr)
            .setAudioFormat(format)
            .setBufferSizeInBytes(trackBuffer.size * 4)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()

        audioTrack?.write(trackBuffer, 0, trackBuffer.size, AudioTrack.WRITE_BLOCKING)
    }

    // Schedule beat events in real time
    private fun startBeatEvents() {
        val beatIntervalMs = (60000.0 / bpm).toLong()
        var currentBeat = 0

        beatRunnable = object : Runnable {
            override fun run() {
                if (!isPlaying) return

                sendBeatEvent(currentBeat)
                currentBeat++
                if (currentBeat < totalBeats) {
                    handler.postDelayed(this, beatIntervalMs)
                }
            }
        }

        handler.post(beatRunnable!!)
    }

    private fun sendBeatEvent(beatIndex: Int) {
        reactApplicationContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit("onBeat", Arguments.createMap().apply { putInt("beatIndex", beatIndex) })
    }

    private fun loadBeepFile(fileName: String) {
        try {
            val file = java.io.File(fileName)
            if (!file.exists()) return

            val fis = file.inputStream()
            val bytes = fis.readBytes()
            fis.close()

            val floatBuffer = FloatArray(bytes.size / 2)
            var j = 0
            for (i in bytes.indices step 2) {
                val sample = ((bytes[i + 1].toInt() shl 8) or (bytes[i].toInt() and 0xFF))
                floatBuffer[j++] = sample / 32768.0f
            }
            beepBuffer = floatBuffer
            beepBufferSampleCount = floatBuffer.size
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
