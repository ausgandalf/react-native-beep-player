import Foundation
import AVFoundation
import React

@objc(BeepPlayer)
class BeepPlayer: RCTEventEmitter {

    // MARK: - React Native module setup
    override static func requiresMainQueueSetup() -> Bool {
        return false
    }

    override func supportedEvents() -> [String]! {
        return ["onBeat"]
    }

    func sendBeatEvent() {
        if _listenerCount > 0 {
            // Dispatch beat event on main queue for React Native
            let beatIndex = beatCount;
            beatCount += 1
            DispatchQueue.main.async {
                self.sendEvent(withName: "onBeat", body: ["beatIndex": beatIndex])
            }
        }
    }

    override func startObserving() {
        _listenerCount += 1
    }

    override func stopObserving() {
        _listenerCount -= 1
    }

    private var _listenerCount = 0

    // MARK: - Audio Engine Properties

    var engine: AVAudioEngine!
    var sourceNode: AVAudioSourceNode!

    var sampleRate: Double = 44100.0
    var bpm: Double = 120
    var samplesPerBeat: Double = 0

    var isPlaying = false
    var isMuted = false

    // Beep parameters
    let beepFrequency: Double = 1000 // fallback sine Hz
    let beepDurationSeconds: Double = 0.05
    var beepSampleCount: Int = 0

    // State for audio rendering
    var sampleIndex: Int = 0
    var beepSampleIndex: Int = 0

    // WAV file buffer
    var beepBuffer: [Float]?
    var beepBufferSampleCount: Int = 0

    // Beat tracking
    var lastBeatSampleIndex: Int = -1
    var beatCount: Int = 0

    // MARK: - React Native API

    @objc func start(_ bpm: NSNumber, beepFile: String?) {
        stop()

        self.bpm = bpm.doubleValue
        sampleRate = 44100.0 // default, will be updated by engine format
        samplesPerBeat = (60.0 / self.bpm) * sampleRate
        beepSampleCount = Int(beepDurationSeconds * sampleRate)

        if let fileName = beepFile {
            loadBeepFile(fileName: fileName)
        }

        setupAudioSession()
        setupEngine()
    }

    @objc func stop() {
        isPlaying = false
        engine?.stop()
        engine = nil
        sourceNode = nil
        sampleIndex = 0
        beepSampleIndex = 0
        lastBeatSampleIndex = -1
        beatCount = 0
    }

    @objc func mute(_ value: Bool) {
        isMuted = value
    }

    // MARK: - Setup functions

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            NSLog("AudioSession setup error: \(error.localizedDescription)")
        }
    }

    private func setupEngine() {
        engine = AVAudioEngine()

        let format = engine.outputNode.outputFormat(forBus: 0)
        sampleRate = format.sampleRate
        samplesPerBeat = (60.0 / bpm) * sampleRate

        if beepBuffer == nil {
            beepSampleCount = Int(beepDurationSeconds * sampleRate)
        } else {
            beepSampleCount = beepBufferSampleCount
        }

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                // Check if this frame is the start of a new beat
                let beatFrameIndex = Int(Double(self.sampleIndex) / self.samplesPerBeat)

                if beatFrameIndex != self.lastBeatSampleIndex {
                    self.lastBeatSampleIndex = beatFrameIndex

                    // Dispatch beat event on main queue for React Native
                    self.sendBeatEvent();
                }

                let isBeepPlaying = (Double(self.sampleIndex).truncatingRemainder(dividingBy: self.samplesPerBeat) < Double(self.beepSampleCount))

                var sampleValue: Float = 0.0
                if self.isMuted || !self.isPlaying || !isBeepPlaying {
                    sampleValue = 0.0
                } else {
                    if let buffer = self.beepBuffer {
                        sampleValue = buffer[self.beepSampleIndex]
                        self.beepSampleIndex += 1
                        if self.beepSampleIndex >= self.beepSampleCount {
                            self.beepSampleIndex = 0
                        }
                    } else {
                        let theta = 2.0 * Double.pi * self.beepFrequency * Double(self.beepSampleIndex) / self.sampleRate
                        sampleValue = Float(sin(theta) * 0.3)
                        self.beepSampleIndex += 1
                        if self.beepSampleIndex >= self.beepSampleCount {
                            self.beepSampleIndex = 0
                        }
                    }
                }

                // Write sampleValue to all channels
                for buffer in ablPointer {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf[frame] = sampleValue
                }

                self.sampleIndex += 1
            }

            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
            isPlaying = true
        } catch {
            NSLog("Failed to start engine: \(error.localizedDescription)")
        }
    }

    // MARK: - WAV loading

    private func findBeepFile(_ beepFile: String) -> URL? {
        let fileManager = FileManager.default

        // Absolute path check
        let potentialPath = URL(fileURLWithPath: beepFile)
        if fileManager.fileExists(atPath: potentialPath.path) {
            return potentialPath
        }

        // Main bundle lookup
        if let mainBundleUrl = Bundle.main.url(forResource: beepFile, withExtension: nil) {
            return mainBundleUrl
        }
        if let nameWithoutExtension = beepFile.components(separatedBy: ".").first,
           let mainBundleUrl = Bundle.main.url(forResource: nameWithoutExtension, withExtension: nil) {
            return mainBundleUrl
        }

        // Framework bundle lookup
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

    private func loadBeepFile(fileName: String) {
        guard let url = findBeepFile(fileName) else {
            NSLog("Beep file not found: \(fileName)")
            return
        }

        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = UInt32(file.length)
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
            try file.read(into: buffer)

            if let channelData = buffer.floatChannelData {
                let channel = channelData[0]
                beepBuffer = Array(UnsafeBufferPointer(start: channel, count: Int(frameCount)))
                beepBufferSampleCount = Int(frameCount)
            }
        } catch {
            NSLog("Error loading beep file: \(error.localizedDescription)")
        }
    }
}
