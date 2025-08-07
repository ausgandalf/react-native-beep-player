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
            print("✅ Beep buffer loaded: frameCapacity=\(buffer.frameCapacity), frameLength=\(buffer.frameLength)")

            // Setup silence buffer
            silenceBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity)!
            silenceBuffer.frameLength = buffer.frameLength
            memset(silenceBuffer.int16ChannelData!.pointee, 0, Int(silenceBuffer.frameLength) * MemoryLayout<Int16>.size)
            print("🔇 Silence buffer created")

            // Setup audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            print("📱 AVAudioSession set to playback and activated")

            // Setup engine
            engine = AVAudioEngine()
            player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)

            try engine.start()
            print("✅ AVAudioEngine started")

            isPlaying = true
            player.play()
            print("▶️ AVAudioPlayerNode started playing")

            scheduleBeepLoop()

        } catch {
            print("❌ Error setting up audio engine or file: \(error)")
        }
    }

    func scheduleBeepLoop() {
        guard isPlaying else {
            print("⏹️ scheduleBeepLoop() called but isPlaying is false — exiting")
            return
        }

        guard let currentTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: currentTime) else {
            print("⚠️ Could not get player time — skipping schedule")
            return
        }

        let timeAhead = Double(playerTime.sampleTime) / sampleRate
        print("🕒 Current player time (in sec): \(timeAhead)")

        var nextBeepTime = timeAhead
        while nextBeepTime < timeAhead + lookAheadSeconds {
            let scheduledTime = AVAudioTime(
                sampleTime: AVAudioFramePosition(nextBeepTime * sampleRate),
                atRate: sampleRate
            )
            player.scheduleBuffer(
                isMuted ? silenceBuffer : buffer,
                at: scheduledTime,
                options: [],
                completionHandler: nil
            )
            print("📅 Scheduled beep at sampleTime: \(scheduledTime.sampleTime)")
            nextBeepTime += beepInterval
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
