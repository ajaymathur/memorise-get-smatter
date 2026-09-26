import Foundation
import Testing

@testable import GetSmarter

struct ContentTests {
    @Test func scienceCoversEveryGameWithCitations() {
        let science = Science.bundled
        for game in GameKind.allCases {
            let entry = science.games[game.rawValue]
            #expect(entry != nil, "missing \(game)")
            #expect((entry?.citations.count ?? 0) >= 1)
        }
        #expect(science.evidenceNote.contains("mixed"))
    }

    /// No overclaiming in shipped copy (intent.md hard constraints).
    @Test func noHealthClaimsInContent() throws {
        let banned = ["improves memory", "boost", "iq", "clinically", "dementia", "prevent", "cure"]
        let science = Science.bundled
        let copy =
            science.games.values.flatMap { [$0.skill, $0.paradigm] } + [
                science.training.skill, science.training.paradigm,
            ]
        for text in copy {
            for word in banned {
                #expect(!text.lowercased().contains(word), "\"\(word)\" in: \(text)")
            }
        }
    }
}
