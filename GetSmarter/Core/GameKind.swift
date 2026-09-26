import SwiftUI

enum GameKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case pairMatch = "pairmatch"
    case sequenceEcho = "sequenceecho"
    case nBack = "nback"
    case wordRecall = "wordrecall"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .pairMatch: "Pair Match"
        case .sequenceEcho: "Sequence Echo"
        case .nBack: "N-Back"
        case .wordRecall: "Word Recall"
        }
    }

    var skill: LocalizedStringResource {
        switch self {
        case .pairMatch: "Visual memory"
        case .sequenceEcho: "Memory span"
        case .nBack: "Working memory"
        case .wordRecall: "Word memory"
        }
    }

    var symbol: String {
        switch self {
        case .pairMatch: "square.grid.2x2.fill"
        case .sequenceEcho: "waveform.path"
        case .nBack: "arrow.uturn.backward.circle.fill"
        case .wordRecall: "text.book.closed.fill"
        }
    }

    /// Okabe–Ito colorblind-safe palette (design.md §9).
    var color: Color {
        switch self {
        case .pairMatch: Color(red: 0xE6 / 255, green: 0x9F / 255, blue: 0x00 / 255)
        case .sequenceEcho: Color(red: 0x56 / 255, green: 0xB4 / 255, blue: 0xE9 / 255)
        case .nBack: Color(red: 0x00 / 255, green: 0x9E / 255, blue: 0x73 / 255)
        case .wordRecall: Color(red: 0xCC / 255, green: 0x79 / 255, blue: 0xA7 / 255)
        }
    }
}

enum Tier: String, CaseIterable, Identifiable, Codable, Sendable {
    case beginner, advanced, expert

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .beginner: "Beginner"
        case .advanced: "Advanced"
        case .expert: "Expert"
        }
    }

    var next: Tier? {
        switch self {
        case .beginner: .advanced
        case .advanced: .expert
        case .expert: nil
        }
    }
}

enum SessionMode: String, Codable, Sendable {
    /// Fixed tier params; eligible for leaderboards.
    case ranked
    /// Ranked params with 1.5× timing; never submitted (REQ-AX-06).
    case relaxed
    /// Daily Training staircase; never submitted (REQ-DT-04).
    case training

    static let relaxedTimingFactor = 1.5
}
