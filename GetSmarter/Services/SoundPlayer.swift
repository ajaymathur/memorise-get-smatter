import AVFoundation
import os

/// All game audio is synthesized at runtime (REQ-AU-01): no bundled files, no licensing.
enum Cue: Sendable, Equatable {
    case tile(Int)
    case flip, correct, wrong, finish, personalBest
}

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    var isEnabled = true
    private let engine = AVAudioEngine()
    private let synth = Synth()
    private var started = false

    private init() {}

    func play(_ cue: Cue) {
        guard isEnabled else { return }
        startIfNeeded()
        synth.add(Self.notes(for: cue))
    }

    /// C-major pentatonic from C4 upward: any tile sequence sounds pleasant (design.md §8).
    static func pentatonic(_ index: Int) -> Double {
        let steps = [0, 2, 4, 7, 9]
        let semis = steps[index % 5] + 12 * (index / 5)
        return 261.63 * pow(2, Double(semis) / 12)
    }

    static func notes(for cue: Cue) -> [Synth.Note] {
        func n(_ hz: Double, _ at: Double, _ dur: Double, _ amp: Double = 0.25) -> Synth.Note {
            Synth.Note(frequency: hz, start: at, duration: dur, amplitude: amp)
        }
        switch cue {
        case .tile(let i): return [n(pentatonic(i), 0, 0.25)]
        case .flip: return [n(1200, 0, 0.03, 0.12)]
        case .correct: return [n(659.25, 0, 0.09), n(880, 0.09, 0.14)]
        case .wrong: return [n(220, 0, 0.15, 0.2)]
        case .finish: return [523.25, 659.25, 783.99, 1046.5].enumerated().map { n($1, Double($0) * 0.1, 0.18) }
        case .personalBest:
            return [523.25, 659.25, 783.99, 1046.5, 2093].enumerated().map { n($1, Double($0) * 0.1, 0.22) }
        }
    }

    private func startIfNeeded() {
        guard !started else { return }
        // Respect the silent switch and mix with the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        try? AVAudioSession.sharedInstance().setActive(true)
        let format = engine.outputNode.inputFormat(forBus: 0)
        let node = synth.makeNode(sampleRate: format.sampleRate)
        engine.attach(node)
        engine.connect(
            node, to: engine.mainMixerNode,
            format: AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 1))
        started = (try? engine.start()) != nil
    }
}

/// Tiny triangle-wave synth rendered on the audio thread.
nonisolated final class Synth: Sendable {
    struct Note: Sendable, Equatable {
        var frequency: Double
        var start: Double
        var duration: Double
        var amplitude: Double
    }

    private struct Voice {
        var note: Note
        var elapsed: Double  // seconds since cue was queued; negative = waiting
        var phase: Double = 0
    }

    private let voices = OSAllocatedUnfairLock(initialState: [Voice]())

    func add(_ notes: [Note]) {
        voices.withLock { $0 += notes.map { Voice(note: $0, elapsed: -$0.start) } }
    }

    func makeNode(sampleRate: Double) -> AVAudioSourceNode {
        let dt = 1 / sampleRate
        return AVAudioSourceNode { [voices] _, _, frameCount, bufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
            voices.withLockUnchecked { voices in
                for frame in 0..<Int(frameCount) {
                    var sample = 0.0
                    for i in voices.indices {
                        voices[i].elapsed += dt
                        let t = voices[i].elapsed
                        let note = voices[i].note
                        guard t >= 0, t < note.duration else { continue }
                        voices[i].phase = (voices[i].phase + note.frequency * dt).truncatingRemainder(dividingBy: 1)
                        let tri = 4 * abs(voices[i].phase - 0.5) - 1
                        // 5 ms attack, exponential-ish release over the note.
                        let env = min(t / 0.005, 1) * pow(1 - t / note.duration, 2)
                        sample += tri * env * note.amplitude
                    }
                    let value = Float(max(-1, min(1, sample)))
                    for buffer in buffers {
                        buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = value
                    }
                }
                voices.removeAll { $0.elapsed >= $0.note.duration }
            }
            return noErr
        }
    }
}
