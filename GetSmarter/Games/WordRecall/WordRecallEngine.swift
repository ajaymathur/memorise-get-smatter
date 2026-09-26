import Foundation

/// Bundled word lists (REQ-WR-04): concrete nouns + DRM associate lists (Roediger & McDermott 1995).
struct WordBank: Codable, Sendable {
    struct DRMList: Codable, Sendable {
        var lure: String
        var words: [String]
    }

    var nouns: [String]
    var drm: [DRMList]

    static let bundled: WordBank = {
        let url = Bundle.main.url(forResource: "words", withExtension: "json")!
        return try! JSONDecoder().decode(WordBank.self, from: Data(contentsOf: url))
    }()
}

/// Study a list, then recognise studied words among foils (REQ-WR-01..05).
/// Advanced/Expert add DRM critical lures as a third of the foils; Expert adds a
/// Brown–Peterson counting distractor before the test.
struct WordRecallEngine: GameEngine {
    struct Config: Sendable, Equatable {
        var listLength: Int
        var exposure: Duration
        var blank: Duration = .milliseconds(400)
        var choices: Int
        var lures = false
        var distractor: Duration = .zero

        var foils: Int { choices - listLength }

        static func tier(_ tier: Tier) -> Config {
            switch tier {
            case .beginner: Config(listLength: 8, exposure: .seconds(2), choices: 16)
            case .advanced: Config(listLength: 12, exposure: .milliseconds(1500), choices: 24, lures: true)
            case .expert:
                Config(
                    listLength: 15, exposure: .milliseconds(1500), choices: 30, lures: true, distractor: .seconds(15))
            }
        }

        /// Daily Training: list length 4…20, up to 10 foils, no lures (design.md §5).
        static func training(length: Int) -> Config {
            Config(listLength: length, exposure: .milliseconds(1500), choices: length + min(length, 10))
        }

        func relaxed() -> Config {
            var c = self
            c.exposure = exposure.scaled(SessionMode.relaxedTimingFactor)
            return c
        }
    }

    enum Phase: Sendable, Equatable {
        case study(index: Int, showing: Bool, remaining: Duration)
        /// Count backward by 3: pick `current - 3` from the options.
        case distractor(remaining: Duration, current: Int, options: [Int])
        case test
        case finished
    }

    let config: Config
    let studied: [String]
    let lureWords: Set<String>
    /// Test grid, shuffled studied words + foils.
    let choices: [String]
    private(set) var phase: Phase
    private(set) var selected: Set<String> = []
    private(set) var outcome: Outcome?
    private var rng: SeededRNG

    init(config: Config, bank: WordBank = .bundled, rng: SeededRNG) {
        self.config = config
        self.rng = rng
        var studied: [String] = []
        var lures: [String] = []
        if config.lures {
            // One DRM theme per lure foil; study its strongest associates (list order = strength).
            let themeCount = config.foils / 3
            let themes = bank.drm.shuffled(using: &self.rng).prefix(themeCount)
            let perTheme = config.listLength / themeCount
            for (i, theme) in themes.enumerated() {
                let extra = i < config.listLength % themeCount ? 1 : 0
                studied += theme.words.prefix(perTheme + extra)
            }
            lures = themes.map(\.lure)
        }
        var fillers = bank.nouns.shuffled(using: &self.rng)[...]
        let needStudy = config.listLength - studied.count
        studied += fillers.prefix(needStudy)
        fillers = fillers.dropFirst(needStudy)
        let foils = lures + fillers.prefix(config.foils - lures.count)
        self.studied = studied.shuffled(using: &self.rng)
        lureWords = Set(lures)
        choices = (studied + foils).shuffled(using: &self.rng)
        phase = .study(index: 0, showing: false, remaining: config.blank)
    }

    /// Word on screen during study, if any.
    var shownWord: String? {
        if case .study(let i, true, _) = phase { return studied[i] }
        return nil
    }

    mutating func toggle(_ word: String) -> [Effect] {
        guard phase == .test, choices.contains(word) else { return [] }
        if selected.remove(word) == nil { selected.insert(word) }
        return [.haptic(.selection)]
    }

    mutating func answerDistractor(_ value: Int) -> [Effect] {
        guard case .distractor(let remaining, let current, _) = phase else { return [] }
        let correct = value == current - 3
        let next = correct ? current - 3 : current
        phase = .distractor(remaining: remaining, current: next, options: Self.options(for: next, rng: &rng))
        return [.haptic(correct ? .success : .error)]
    }

    mutating func done() -> [Effect] {
        guard phase == .test else { return [] }
        let studiedSet = Set(studied)
        let hits = selected.intersection(studiedSet).count
        let falseAlarms = selected.subtracting(studiedSet).count
        let pr = Pr.value(hits: hits, targets: studied.count, falseAlarms: falseAlarms, nonTargets: config.foils)
        let correct = hits + (config.foils - falseAlarms)
        phase = .finished
        outcome = Outcome(
            score: Pr.score(pr), accuracy: Double(correct) / Double(choices.count),
            stats: ["luresPicked": selected.intersection(lureWords).count, "prPercent": Int((pr * 100).rounded())])
        return [.sound(.finish)]
    }

    private static func options(for n: Int, rng: inout SeededRNG) -> [Int] {
        [n - 3, n - 2, n - 4].shuffled(using: &rng)
    }

    mutating func advance(by dt: Duration) -> [Effect] {
        switch phase {
        case .test, .finished:
            return []
        case .distractor(let remaining, let current, let options):
            if remaining > dt {
                phase = .distractor(remaining: remaining - dt, current: current, options: options)
                return []
            }
            phase = .test
            return [.announce(String(localized: "Now tap every word you studied"))]
        case .study(let index, let showing, let remaining):
            if remaining > dt {
                phase = .study(index: index, showing: showing, remaining: remaining - dt)
                return []
            }
            if !showing {
                phase = .study(index: index, showing: true, remaining: config.exposure)
                return [.announce(studied[index])]
            }
            if index + 1 < studied.count {
                phase = .study(index: index + 1, showing: false, remaining: config.blank)
                return []
            }
            if config.distractor > .zero {
                let start = Int.random(in: 300...999, using: &rng)
                phase = .distractor(
                    remaining: config.distractor, current: start, options: Self.options(for: start, rng: &rng))
                return [.announce(String(localized: "Count backward by 3 from \(start)"))]
            }
            phase = .test
            return [.announce(String(localized: "Now tap every word you studied"))]
        }
    }

    /// Re-show the current word from its start (REQ-GM-05).
    mutating func resumeFromPause() {
        if case .study(let index, _, _) = phase {
            phase = .study(index: index, showing: false, remaining: config.blank)
        }
    }
}
