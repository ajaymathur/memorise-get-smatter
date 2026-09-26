import SwiftUI

/// Research basis shown in-app (REQ-GM-09). Citations are plain text: no links, no network.
struct Science: Codable, Sendable {
    struct Entry: Codable, Sendable {
        var skill: String
        var paradigm: String
        var citations: [String]
    }

    var evidenceNote: String
    var games: [String: Entry]
    var training: Entry
    var evidence: [String]

    static let bundled: Science = {
        let url = Bundle.main.url(forResource: "science", withExtension: "json")!
        return try! JSONDecoder().decode(Science.self, from: Data(contentsOf: url))
    }()
}

struct ScienceView: View {
    /// nil shows every game plus training.
    var game: GameKind?
    private let science = Science.bundled

    var body: some View {
        List {
            if let game, let entry = science.games[game.rawValue] {
                EntrySections(title: Text(game.title), entry: entry)
            } else {
                ForEach(GameKind.allCases) { g in
                    if let entry = science.games[g.rawValue] { EntrySections(title: Text(g.title), entry: entry) }
                }
                EntrySections(title: Text("Daily Training"), entry: science.training)
            }
            Section {
                Text(science.evidenceNote)
                ForEach(science.evidence, id: \.self) { Text($0).font(.footnote).textSelection(.enabled) }
            } header: {
                Text("What the evidence says")
            }
        }
        .navigationTitle("The Science")
    }
}

private struct EntrySections: View {
    let title: Text
    let entry: Science.Entry

    var body: some View {
        Section {
            Text(entry.skill).font(.headline)
            Text(entry.paradigm)
            ForEach(entry.citations, id: \.self) {
                Text($0).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
            }
        } header: {
            title
        }
    }
}
