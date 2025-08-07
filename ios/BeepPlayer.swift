import Foundation
import AVFoundation
import React

@objc(BeepPlayer)
class BeepPlayer: NSObject, RCTBridgeModule {
    static func moduleName() -> String! {
        return "BeepPlayer"
    }
    var engine: AVAudioEngine!
    var player: AVAudioPlayerNode!
    var buffer: AVAudioPCMBuffer!
    var beepInterval: Double = 0.5
    var sampleRate: Double = 44100.0
    var lookAheadSeconds: Double = 5.0
    var isPlaying = false
    var isMuted = false
    var silenceBuffer: AVAudioPCMBuffer!

    @objc func start(_ bpm: NSNumber, beepFile: String) {
        stop() // ensure clean start

        guard let url = Bundle.main.url(forResource: beepFile, withExtension: nil) else {
            print("Beep file not found")
            return
        }

        let file = try! AVAudioFile(forReading: url)
        sampleRate = file.fileFormat.sampleRate
        beepInterval = 60.0 / bpm.doubleValue

        // Load beep buffer
        buffer = AVAudioPCMBuffer(
            pcmFormat: file.processingFormat,
            frameCapacity: AVAudioFrameCount(file.length)
        )!
        try! file.read(into: buffer!)

        // Create silence buffer with same format & length
        silenceBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        )!
        silenceBuffer.frameLength = buffer.frameLength
        memset(
            silenceBuffer.int16ChannelData!.pointee,
            0,
            Int(silenceBuffer.frameLength) * MemoryLayout<Int16>.size
        )

        // Setup engine
        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
        try! engine.start()

        isPlaying = true
        player.play()

        scheduleBeepLoop()
    }

    func scheduleBeepLoop() {
        guard isPlaying else { return }

        let currentTime = player.lastRenderTime!
        let playerTime = player.playerTime(forNodeTime: currentTime)!
        let timeAhead = Double(playerTime.sampleTime) / sampleRate

        var nextBeepTime = timeAhead
        while nextBeepTime < timeAhead + lookAheadSeconds {
            player.scheduleBuffer(
                isMuted ? silenceBuffer : buffer,
                at: AVAudioTime(
                    sampleTime: AVAudioFramePosition(nextBeepTime * sampleRate),
                    atRate: sampleRate
                ),
                options: [],
                completionHandler: nil
            )
            nextBeepTime += beepInterval
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.scheduleBeepLoop()
        }
    }

    @objc func stop() {
        isPlaying = false
        player?.stop()
        engine?.stop()
        engine = nil
        player = nil
    }

    @objc func mute(_ value: Bool) {
        isMuted = value
    }
}
