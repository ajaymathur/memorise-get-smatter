import Testing

@testable import GetSmarter

struct SoundTests {
    @Test func pentatonicStartsAtMiddleCAndRisesPerOctave() {
        #expect(abs(SoundPlayer.pentatonic(0) - 261.63) < 0.01)
        #expect(abs(SoundPlayer.pentatonic(5) - 523.26) < 0.01)
        let notes = (0..<16).map(SoundPlayer.pentatonic)
        #expect(notes == notes.sorted())
        #expect(Set(notes).count == 16)
    }
}
