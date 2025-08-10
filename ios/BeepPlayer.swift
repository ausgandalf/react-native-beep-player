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
    var silenceBuffer: AVAudioPCMBuffer!
    var beepInterval: Double = 0.5
    var sampleRate: Double = 44100.0
    var nextBeatSampleTime: AVAudioFramePosition = 0
    var isPlaying = false
    var isMuted = false
    var audioSessionConfigured = false

    // MARK: - Public API

    @objc func start(_ bpm: NSNumber, beepFile: String) {
        NSLog("🔔 BeepPlayer.start() called with bpm=%@, beepFile=%@", bpm, beepFile)
        stop()

        configureAudioSession()

        guard audioSessionConfigured else {
            NSLog("❌ Cannot start beep player - audio session configuration failed")
            return
        }

        beepInterval = 60.0 / bpm.doubleValue

        // Try to find the file
        if let fileUrl = findBeepFile(beepFile) {
            loadAudioFromFile(fileUrl)
        } else {
            NSLog("❌ Beep file not found, generating fallback beep")
            generateFallbackBeep()
        }

        setupAudioEngine()
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

    // MARK: - File Handling

    private func findBeepFile(_ beepFile: String) -> URL? {
        let fileManager = FileManager.default
        
        // 1. If the string is already an absolute path and exists, return it
        let potentialPath = URL(fileURLWithPath: beepFile)
        if fileManager.fileExists(atPath: potentialPath.path) {
            return potentialPath
        }
        
        // 2. Otherwise, try from main bundle
        if let mainBundleUrl = Bundle.main.url(forResource: beepFile, withExtension: nil) {
            return mainBundleUrl
        }
        if let nameWithoutExtension = beepFile.components(separatedBy: ".").first,
        let mainBundleUrl = Bundle.main.url(forResource: nameWithoutExtension, withExtension: nil) {
            return mainBundleUrl
        }
        
        // 3. Try from framework bundle
        let frameworkBundle = Bundle(for: type(of: self))
        if let frameworkUrl = frameworkBundle.url(forResource: beepFile, withExtension: nil) {
            return frameworkUrl
        }
        if let nameWithoutExtension = beepFile.components(separatedBy: ".").first,
        let frameworkUrl = frameworkBundle.url(forResource: nameWithoutExtension, withExtension: nil) {
            return frameworkUrl
        }
        
        return nil
    }


    private func loadAudioFromFile(_ fileUrl: URL) {
        do {
            let file = try AVAudioFile(forReading: fileUrl)
            sampleRate = file.fileFormat.sampleRate
            buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
            try file.read(into: buffer!)
            buffer.frameLength = AVAudioFrameCount(file.length)
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
    }

    // MARK: - Engine Setup & Scheduling

    private func setupAudioEngine() {
        guard let buffer = buffer else {
            NSLog("❌ Buffer not loaded")
            return
        }

        // Create silence buffer for mute mode
        silenceBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity)!
        silenceBuffer.frameLength = buffer.frameLength
        if let channelData = silenceBuffer.floatChannelData {
            memset(channelData[0], 0, Int(silenceBuffer.frameLength) * MemoryLayout<Float>.size)
        }

        engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: buffer.format)

        do {
            try engine.start()
            isPlaying = true
            player.play()

            let lastRenderTime = engine.outputNode.lastRenderTime
            let outputTime = player.playerTime(forNodeTime: lastRenderTime!)!
            nextBeatSampleTime = outputTime.sampleTime

            scheduleNextBeat()
        } catch {
            NSLog("❌ Error starting engine: %@", error.localizedDescription)
            engine = nil
            player = nil
            isPlaying = false
        }
    }

    private func scheduleNextBeat() {
        guard isPlaying else { return }
        guard let buffer = isMuted ? silenceBuffer : buffer else { return }

        let framesPerBeat = AVAudioFramePosition(beepInterval * sampleRate)

        // Get current player time relative to engine clock
        if let lastRenderTime = engine.outputNode.lastRenderTime,
        let playerTime = player.playerTime(forNodeTime: lastRenderTime) {

            let currentSampleTime = playerTime.sampleTime

            // Calculate how many beats have elapsed
            let beatsElapsed = Double(currentSampleTime) / (beepInterval * sampleRate)

            // Find the *next* exact beat sample time
            let nextBeatIndex = ceil(beatsElapsed)
            nextBeatSampleTime = AVAudioFramePosition(nextBeatIndex * beepInterval * sampleRate)

        } else {
            // Fallback if timing unavailable — just increment
            nextBeatSampleTime += framesPerBeat
        }

        let beatTime = AVAudioTime(sampleTime: nextBeatSampleTime, atRate: sampleRate)

        // Schedule this beat
        player.scheduleBuffer(buffer, at: beatTime, options: []) { [weak self] in
            self?.scheduleNextBeat()
        }
    }


    // MARK: - Audio Session

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
}
