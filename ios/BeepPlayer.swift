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
    let beepFrequency: Double = 1000 // Hz
    let beepDurationSeconds: Double = 0.05 // length of beep in seconds
    var beepSampleCount: Int = 0

    // State for audio rendering
    var sampleIndex: Int = 0
    var beepSampleIndex: Int = 0

    @objc func start(_ bpm: NSNumber, beepFile: String?) {
        stop()

        self.bpm = bpm.doubleValue
        sampleRate = 44100.0 // default, will get real value later
        samplesPerBeat = (60.0 / self.bpm) * sampleRate
        beepSampleCount = Int(beepDurationSeconds * sampleRate)

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
        beepSampleCount = Int(beepDurationSeconds * sampleRate)

        // Create source node with render block
        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                let isBeepPlaying = (Double(self.sampleIndex).truncatingRemainder(dividingBy: self.samplesPerBeat) < Double(self.beepSampleCount))

                // Calculate sample value: beep tone or silence
                let sampleValue: Float
                if self.isMuted || !self.isPlaying || !isBeepPlaying {
                    sampleValue = 0.0
                } else {
                    // Simple sine wave beep tone
                    let theta = 2.0 * Double.pi * self.beepFrequency * Double(self.beepSampleIndex) / self.sampleRate
                    sampleValue = Float(sin(theta) * 0.3)
                    self.beepSampleIndex += 1
                    if self.beepSampleIndex >= self.beepSampleCount {
                        self.beepSampleIndex = 0
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
}
