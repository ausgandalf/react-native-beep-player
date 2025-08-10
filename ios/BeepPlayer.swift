import Foundation
import AVFoundation
import React

@objc(BeepPlayer)
class BeepPlayer: NSObject {

    static func moduleName() -> String! {
        return "BeepPlayer"
    }

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

    @objc func start(_ bpm: NSNumber, beepFile: String?) {
        stop()

        self.bpm = bpm.doubleValue
        sampleRate = 44100.0 // default, will be updated from engine
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
    }

    @objc func mute(_ value: Bool) {
        isMuted = value
    }

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
        if beepBuffer == nil { // adjust beepSampleCount if no file
            beepSampleCount = Int(beepDurationSeconds * sampleRate)
        } else {
            beepSampleCount = beepBufferSampleCount
        }

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                let isBeepPlaying = (Double(self.sampleIndex).truncatingRemainder(dividingBy: self.samplesPerBeat) < Double(self.beepSampleCount))

                var sampleValue: Float = 0.0
                if self.isMuted || !self.isPlaying || !isBeepPlaying {
                    sampleValue = 0.0
                } else {
                    if let buffer = self.beepBuffer {
                        // Play from loaded WAV buffer
                        sampleValue = buffer[self.beepSampleIndex]
                        self.beepSampleIndex += 1
                        if self.beepSampleIndex >= self.beepSampleCount {
                            self.beepSampleIndex = 0
                        }
                    } else {
                        // Fallback to sine wave
                        let theta = 2.0 * Double.pi * self.beepFrequency * Double(self.beepSampleIndex) / self.sampleRate
                        sampleValue = Float(sin(theta) * 0.3)
                        self.beepSampleIndex += 1
                        if self.beepSampleIndex >= self.beepSampleCount {
                            self.beepSampleIndex = 0
                        }
                    }
                }

                // Write to all channels
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