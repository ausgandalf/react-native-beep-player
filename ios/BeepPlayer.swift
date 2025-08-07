import Foundation
import AVFoundation
import React

@objc(BeepPlayer)
class BeepPlayer: NSObject {
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
        print("🔔 BeepPlayer.start() called with bpm=\(bpm), beepFile=\(beepFile)")
        stop()

        guard let url = Bundle.main.url(forResource: beepFile, withExtension: nil) else {
            print("❌ Beep file not found in bundle: \(beepFile)")
            return
        }

        print("📦 Found beep file at URL: \(url)")

        do {
            let file = try AVAudioFile(forReading: url)
            sampleRate = file.fileFormat.sampleRate
            beepInterval = 60.0 / bpm.doubleValue
            print("🎧 Loaded audio file: sampleRate=\(sampleRate), beepInterval=\(beepInterval)")

            buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
            try file.read(into: buffer!)
            buffer.frameLength = AVAudioFrameCount(file.length)
            print("✅ Beep buffer loaded: frameCapacity=\(buffer.frameCapacity), frameLength=\(buffer.frameLength)")

            // Setup silence buffer
            silenceBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity)!
            silenceBuffer.frameLength = buffer.frameLength
            memset(silenceBuffer.int16ChannelData!.pointee, 0, Int(silenceBuffer.frameLength) * MemoryLayout<Int16>.size)
            print("🔇 Silence buffer created")

            // Setup audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true, options: [])
            print("📱 AVAudioSession set to playback and activated")
            print("🔉 Output volume: \(AVAudioSession.sharedInstance().outputVolume)")

            // Setup engine
            engine = AVAudioEngine()
            player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
            print("🔌 Connected player to main mixer")

            try engine.start()
            print("✅ AVAudioEngine started")
            print("🔊 Engine output format: \(engine.outputNode.outputFormat(forBus: 0))")

            isPlaying = true

            print("🔁 isMuted: \(isMuted)")
            // Schedule a single buffer just to test
            player.scheduleBuffer(
                isMuted ? silenceBuffer : buffer,
                at: nil,
                options: [],
                completionHandler: {
                    print("✅ Buffer playback complete")
                }
            )

            player.play()
            print("▶️ AVAudioPlayerNode started playing")

            // Schedule the loop after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.scheduleBeepLoop()
            }

        } catch {
            print("❌ Error setting up audio engine or file: \(error)")
        }
    }

    func scheduleBeepLoop() {
        guard isPlaying else {
            print("⏹️ scheduleBeepLoop() called but isPlaying is false — exiting")
            return
        }

        let now = AVAudioTime.now()
        var nextBeepTime = now

        for _ in 0..<Int(lookAheadSeconds / beepInterval) {
            let bufferToPlay = isMuted ? silenceBuffer : buffer
            player.scheduleBuffer(bufferToPlay, at: nextBeepTime, options: []) {
                print("✅ Scheduled beep buffer finished at: \(nextBeepTime.sampleTime)")
            }
            nextBeepTime = nextBeepTime.offset(seconds: beepInterval)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.scheduleBeepLoop()
        }
    }

    @objc func stop() {
        print("🛑 BeepPlayer.stop() called")
        isPlaying = false
        player?.stop()
        engine?.stop()
        engine = nil
        player = nil
    }

    @objc func mute(_ value: Bool) {
        isMuted = value
        print("🔇 BeepPlayer mute set to \(value)")
    }
}

private extension AVAudioTime {
    func offset(seconds: Double) -> AVAudioTime {
        let offsetSamples = AVAudioFramePosition(seconds * 44100)
        return AVAudioTime(sampleTime: self.sampleTime + offsetSamples, atRate: 44100)
    }
}
