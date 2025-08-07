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
    var audioSessionConfigured = false

    @objc func start(_ bpm: NSNumber, beepFile: String) {
        NSLog("🔔 BeepPlayer.start() called with bpm=%@, beepFile=%@", bpm, beepFile)
        stop()

        configureAudioSession()
        
        guard audioSessionConfigured else {
            NSLog("❌ Cannot start beep player - audio session configuration failed")
            return
        }

        var url: URL?

        if let mainBundleUrl = Bundle.main.url(forResource: beepFile, withExtension: nil) {
            url = mainBundleUrl
        } else if let nameWithoutExtension = beepFile.components(separatedBy: ".").first,
                  let mainBundleUrl = Bundle.main.url(forResource: nameWithoutExtension, withExtension: nil) {
            url = mainBundleUrl
        } else {
            let frameworkBundle = Bundle(for: type(of: self))
            if let frameworkUrl = frameworkBundle.url(forResource: beepFile, withExtension: nil) {
                url = frameworkUrl
            } else if let nameWithoutExtension = beepFile.components(separatedBy: ".").first,
                      let frameworkUrl = frameworkBundle.url(forResource: nameWithoutExtension, withExtension: nil) {
                url = frameworkUrl
            }
        }

        if let fileUrl = url {
            loadAudioFromFile(fileUrl, bpm: bpm)
        } else {
            NSLog("❌ Beep file not found, generating fallback beep")
            generateFallbackBeep()
        }
    }

    private func loadAudioFromFile(_ fileUrl: URL, bpm: NSNumber) {
        do {
            let file = try AVAudioFile(forReading: fileUrl)
            sampleRate = file.fileFormat.sampleRate
            beepInterval = 60.0 / bpm.doubleValue

            buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
            try file.read(into: buffer!)
            buffer.frameLength = AVAudioFrameCount(file.length)

            setupAudioEngine()
        } catch {
            NSLog("❌ Error loading audio file: %@", error.localizedDescription)
            generateFallbackBeep()
        }
    }

    private func generateFallbackBeep() {
        sampleRate = 44100.0

        let frequency: Double = 440.0
        let duration: Double = 0.1
        let frameCount = Int(sampleRate * duration)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)

        if let channelData = buffer.floatChannelData {
            for i in 0..<frameCount {
                let sample = sin(2.0 * Double.pi * frequency * Double(i) / sampleRate)
                channelData[0][i] = Float(sample * 0.3)
            }
        }

        setupAudioEngine()
    }

    private func setupAudioEngine() {
        silenceBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity)!
        silenceBuffer.frameLength = buffer.frameLength

        if let channelData = silenceBuffer.floatChannelData {
            memset(channelData[0], 0, Int(silenceBuffer.frameLength) * MemoryLayout<Float>.size)
        }

        engine = AVAudioEngine()
        player = AVAudioPlayerNode()

        guard audioSessionConfigured else {
            NSLog("❌ Audio session not configured")
            return
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)

        do {
            engine.prepare()
            try engine.start()

            isPlaying = true

            let nextBuffer = isMuted ? silenceBuffer : buffer
            if let validBuffer = nextBuffer {
                player.scheduleBuffer(
                    validBuffer,
                    at: nil,
                    options: [],
                    completionHandler: nil
                )
            } else {
                NSLog("❌ Failed to schedule buffer: buffer was nil")
            }

            player.play()

            DispatchQueue.main.asyncAfter(deadline: .now() + beepInterval) {
                self.scheduleBeepLoop()
            }

        } catch {
            NSLog("❌ Error starting engine: %@", error.localizedDescription)
            engine = nil
            player = nil
            isPlaying = false
        }
    }

    private func scheduleBeepLoop() {
        guard isPlaying else {
            return
        }

        let beepsToSchedule = Int(lookAheadSeconds / beepInterval)

        for _ in 0..<beepsToSchedule {
            let nextBuffer = isMuted ? silenceBuffer : buffer
            if let validBuffer = nextBuffer {
                player.scheduleBuffer(validBuffer, at: nil, options: [])
            } else {
                NSLog("❌ Failed to schedule buffer: buffer was nil")
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + lookAheadSeconds) {
            self.scheduleBeepLoop()
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()

            try session.setActive(false)
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(sampleRate)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)

            audioSessionConfigured = true
        } catch {
            NSLog("❌ Audio session configuration failed: %@", error.localizedDescription)
            audioSessionConfigured = false
        }
    }

    @objc func stop() {
        isPlaying = false

        player?.stop()
        engine?.stop()

        player = nil
        engine = nil

        buffer = nil
        silenceBuffer = nil

        if audioSessionConfigured {
            do {
                try AVAudioSession.sharedInstance().setActive(false)
                audioSessionConfigured = false
            } catch {
                NSLog("❌ Failed to deactivate session: %@", error.localizedDescription)
            }
        }
    }

    @objc func mute(_ value: Bool) {
        isMuted = value
    }
}
