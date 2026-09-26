import AVFoundation

/// On-device speech for N-Back letters and eyes-free cues (REQ-NB-04). No network.
@MainActor
final class Speech {
    static let shared = Speech()
    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func say(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.1
        synthesizer.speak(utterance)
    }
}
