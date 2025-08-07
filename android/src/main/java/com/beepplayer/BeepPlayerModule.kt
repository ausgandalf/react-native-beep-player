package com.beepplayer

import com.facebook.react.bridge.*
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import java.nio.ByteBuffer
import java.nio.ByteOrder

class BeepPlayerModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
  private var audioTrack: AudioTrack? = null
  private var isPlaying = false
  private var beepData: ShortArray? = null
  private var beepIntervalFrames: Int = 0
  private val lookAheadSeconds = 5.0

  override fun getName() = "BeepPlayer"

  @ReactMethod
  fun start(bpm: Double, beepFile: String) {
    stop()

    val afd = reactApplicationContext.assets.openFd(beepFile)
    val input = afd.createInputStream()
    val pcmBytes = input.readBytes()
    input.close()

    beepData = ShortArray(pcmBytes.size / 2)
    ByteBuffer.wrap(pcmBytes).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(beepData)

    val sampleRate = 44100
    beepIntervalFrames = (sampleRate * (60.0 / bpm)).toInt()

    val minBufSize = AudioTrack.getMinBufferSize(
      sampleRate,
      AudioFormat.CHANNEL_OUT_MONO,
      AudioFormat.ENCODING_PCM_16BIT
    )

    audioTrack = AudioTrack(
      AudioManager.STREAM_MUSIC,
      sampleRate,
      AudioFormat.CHANNEL_OUT_MONO,
      AudioFormat.ENCODING_PCM_16BIT,
      minBufSize,
      AudioTrack.MODE_STREAM
    )

    isPlaying = true
    audioTrack!!.play()

    Thread {
      val lookAheadFrames = (sampleRate * lookAheadSeconds).toInt()
      var framesBuffered = 0

      while (isPlaying) {
        if (framesBuffered < lookAheadFrames) {
          audioTrack!!.write(beepData!!, 0, beepData!!.size)
          framesBuffered += beepData!!.size

          val silenceFrames = beepIntervalFrames - beepData!!.size
          if (silenceFrames > 0) {
            val silence = ShortArray(silenceFrames)
            audioTrack!!.write(silence, 0, silence.size)
            framesBuffered += silenceFrames
          }
        } else {
          Thread.sleep(10)
        }
      }
    }.start()
  }

  @ReactMethod
  fun stop() {
    isPlaying = false
    audioTrack?.stop()
    audioTrack?.release()
    audioTrack = null
  }
}
