# Design

Stage 2 (Design) artifact. Implements [requirements.md](requirements.md) under the constraints in [intent.md](intent.md).

## 1. Architecture

One app target (`GetSmarter`), one unit-test target (`GetSmarterTests`, Swift Testing), one UI-test target (`GetSmarterUITests`, XCTest). Xcode folder-synchronized groups, so adding a file needs no project edits. No packages, no protocol-per-service layers.

```
GetSmarter/
  App/            GetSmarterApp, RootView, AppModel (settings + services wiring)
  Core/           GameKind, Tier, SeededRNG, Scoring, Progression, Staircase, GameClock
  Games/
    PairMatch/    PairMatchEngine (pure), PairMatchView
    SequenceEcho/ SequenceEchoEngine, SequenceEchoView
    NBack/        NBackEngine, NBackView
    WordRecall/   WordRecallEngine, WordBank, WordRecallView
  Features/       Menu, GameHost (tutorial/pause/result shell), Result, DailyTraining,
                  Progress, Leaderboard, Science, Settings, Onboarding
  Services/       SoundPlayer (AVAudioEngine synth), Speech, Haptics, GameCenterService,
                  Reminders, Links
  Data/           SessionRecord, TrainingLevel (SwiftData)
  Resources/      Localizable.xcstrings, words.json, science.json, PrivacyInfo.xcprivacy,
                  Assets.xcassets, AppIcon.icon
```

### Engines

Each engine is a value-type state machine: `mutating func handle(_ action: Action, at time: Duration) -> [Effect]`.
- Input: user actions + clock ticks with elapsed game time.
- Output: effects (`.play(sound)`, `.haptic`, `.speak`, `.finished(Result)`).
- No SwiftUI, no timers, no singletons. Fully deterministic with `SeededRNG` (SplitMix64).

Views own an `@Observable` host that drives the clock (`Task.sleep` loop pausing on `scenePhase != .active`), feeds actions to the engine, and executes effects. Pausing freezes game time and resets any in-progress stimulus (REQ-GM-05).

### Session modes

`ranked` (fixed tier params, eligible for leaderboard), `relaxed` (ranked params × 1.5 timing, unranked), `training` (staircase level, unranked).

## 2. Tier parameters

| Game | Beginner | Advanced | Expert |
|---|---|---|---|
| Pair Match | 3×4, 6 pairs, 2 s preview | 4×4, 8 pairs, 1 s preview | 5×6, 15 pairs, no preview |
| Sequence Echo | 2×2, span 2, 800 ms/item, forward | 3×3, span 3, 600 ms, forward | 4×4, span 4, 450 ms, backward |
| N-Back | 1-back position | 2-back position | 2-back dual (position + spoken letter) |
| Word Recall | 8 words, 2 s, 16 choices | 12 words, 1.5 s, 24 choices, lures | 15 words, 1.5 s, 15 s distractor, 30 choices, lures |

Common timings:
- Pair Match: 90 s cap; mismatch shown 0.8 s.
- Sequence Echo: 250 ms gap between items; 2 trials per span; max span 12 (cap = tile count for 2×2 grid → repeats allowed but never twice in a row).
- N-Back: stimulus 500 ms, trial 3000 ms, 20 + n trials, target probability 0.3 per modality, grid 3×3 (centre excluded → 8 positions), letters `C H K L Q R S T` (Jaeggi 2008 set).
- Word Recall: 400 ms blank between words; lures = 1/3 of foils on Advanced/Expert; distractor = count backward by 3 from a random 3-digit number (spoken/visual prompt, tap "Next" each step; not scored).

## 3. Scoring (REQ-GM-03)

All scores are integers ≥ 0.

| Game | Formula |
|---|---|
| Pair Match | `pairsFound × 100 − extraMoves × 10 + (completed ? secondsLeft × 5 : 0)`, where a move = two flips and `extraMoves = max(0, moves − pairs)` |
| Sequence Echo | `longestSpanCorrect × 100 + spansWithBothTrialsCorrect × 25` |
| N-Back | `round(1000 × max(0, Pr))` where `Pr = hitRate − falseAlarmRate` (discrimination index, Snodgrass & Corwin 1988); dual = mean of both modalities |
| Word Recall | `round(1000 × max(0, Pr))` over studied words vs foils |

Note: interview proposed `hits − intrusions` penalties for N-Back and Word Recall. Replaced with Pr so "tap everything" scores 0 and scores are comparable across tiers of different lengths.

Accuracy shown on results: Pair Match `pairs / moves`; Sequence Echo `correct trials / trials`; N-Back and Word Recall `(hits + correct rejections) / items`.

## 4. Progression (REQ-GM-06/07)

Unlock and suggestion thresholds (score on the lower tier):

| Game | Beginner → Advanced | Advanced → Expert |
|---|---|---|
| Pair Match | 800 | 900 |
| Sequence Echo | 500 | 600 |
| N-Back | 700 | 700 |
| Word Recall | 700 | 700 |

Unlock state is **derived** from `SessionRecord`s (any ranked or relaxed score ≥ threshold), so there is no mutable unlock record to conflict across devices. "Suggest next tier" = 3 scores ≥ threshold on the current tier and next tier never played.

## 5. Daily Training (REQ-DT)

Order: Pair Match → Sequence Echo → N-Back → Word Recall, ~75 s each, rounds repeat inside the window.

Staircase: 2-down/1-up (Levitt 1971; converges ≈ 70.7 % correct). Two consecutive correct rounds → level + 1; one failed round → level − 1; clamp to range. Start from stored `TrainingLevel`.

| Game | Level meaning | Range | Round = |
|---|---|---|---|
| Pair Match | pairs on board (preview 1 s) | 3 … 15 | clear board with `extraMoves ≤ pairs` |
| Sequence Echo | span on 3×3 forward | 2 … 9 | one sequence correct |
| N-Back | n, position only | 1 … 6 | block of 10 + n trials with Pr ≥ 0.6 |
| Word Recall | list length, 20 choices max(2×len) | 4 … 20 | Pr ≥ 0.6 |

Streak: consecutive local calendar days with ≥ 1 completed circuit; derived from `SessionRecord`s of mode `training` flagged `circuitComplete`.

## 6. Data model (REQ-DS)

CloudKit-compatible SwiftData: every property has a default, no `.unique`, no required relationships.

```swift
@Model final class SessionRecord {
    var id: UUID = UUID()
    var game: String = ""          // GameKind.rawValue
    var tier: String = ""          // Tier.rawValue, "" for training
    var mode: String = "ranked"    // ranked | relaxed | training
    var score: Int = 0
    var accuracy: Double = 0
    var date: Date = Date.now
    var circuitComplete: Bool = false
    var pendingSubmit: Bool = false  // ranked + opted in, not yet sent to Game Center
}

@Model final class TrainingLevel {
    var game: String = ""
    var level: Int = 1
    var updatedAt: Date = Date.now
}
```

Duplicates from sync: `TrainingLevel` resolved by newest `updatedAt` per game; `SessionRecord` deduped by `id`.

Container: `ModelConfiguration(cloudKitDatabase: .automatic)` with container `iCloud.com.ajaymathur.memorisegetsmatter`. If CloudKit is unavailable, SwiftData falls back to local store automatically; the app never blocks on it.

Settings (`@AppStorage`, local): `soundOn`, `hapticsOn`, `relaxedTiming`, `unlockAll`, `shareScores` (Bool?: nil = not asked), `reminderOn`, `reminderTime`, `onboarded`, `tutorialSeen.<game>`, `lastReviewRequest`.

## 7. Game Center

Leaderboard IDs (24 = 12 classic all-time + 12 recurring weekly, best score, higher is better):

```
lb.<game>.<tier>.alltime     lb.<game>.<tier>.weekly
game ∈ pairmatch, sequenceecho, nback, wordrecall
tier ∈ beginner, advanced, expert
```

Weekly = recurring leaderboard, start Monday 00:00 UTC, duration 7 days.

Achievements:

| ID | Title | Condition |
|---|---|---|
| ach.first_game | First Steps | finish any game |
| ach.all_games | Well Rounded | finish all four games |
| ach.perfect_pairs | Photographic | Pair Match with 0 extra moves (any tier) |
| ach.span_7 | Magic Seven | Sequence Echo span ≥ 7 |
| ach.nback_3 | Three Steps Back | reach training level 3 in N-Back |
| ach.lure_proof | Lure Proof | Word Recall Advanced/Expert with no lure selected |
| ach.expert | Expert Mind | unlock any Expert tier |
| ach.streak_3 | Warming Up | 3-day training streak |
| ach.streak_7 | Habit Formed | 7-day training streak |
| ach.streak_30 | Dedicated | 30-day training streak |

Achievements are evaluated locally from records; reported (100 %) when authenticated and `shareScores == true`.

Submission: `GKLeaderboard.submitScore(_:context:player:leaderboardIDs:)` with both IDs. Queue = records with `pendingSubmit`; flushed on authentication and on `scenePhase == .active`.

## 8. Audio

`AVAudioEngine` + one `AVAudioSourceNode` rendering a small polyphonic synth (triangle/sine, ADSR envelope). Session category `.ambient`.

| Cue | Sound |
|---|---|
| tile i (Sequence Echo) | C-major pentatonic from C4 upward, tile index → note, 250 ms |
| flip | short 1.2 kHz tick, 30 ms |
| match / correct | two-note rising (E5→A5) |
| wrong | low (A3) 150 ms, soft |
| finish | 4-note arpeggio |
| personal best | arpeggio + octave |

Spoken letters and VoiceOver-mode positions: `AVSpeechSynthesizer` with the system voice (on-device).

Haptics via SwiftUI `.sensoryFeedback` (`.success`, `.error`, `.selection`).

## 9. Visual design

- SF Rounded for display text; system text styles for everything else (Dynamic Type).
- Accent: indigo `#4B3FB5` (dark mode `#8E84F0`).
- Game colors (Okabe–Ito): Pair Match orange `#E69F00`, Sequence Echo sky blue `#56B4E9`, N-Back bluish green `#009E73`, Word Recall reddish purple `#CC79A7`.
- Card/tile faces: SF Symbol + color pair; symbol alone is sufficient to distinguish (REQ-AX-03).
- Reduce Motion: `.transition(.opacity)` instead of 3D flip.
- iOS 26+: Liquid Glass comes automatically from standard controls; no custom glass.
- Launch screen: `UILaunchScreen` with `UIColorName` = `LaunchBackground`.

## 10. Accessibility plan

| Game | VoiceOver play |
|---|---|
| Pair Match | Cards are buttons: "Row 2, column 3, face down". On flip, announce symbol name; on match, "Match". |
| Sequence Echo | Tiles named by symbol + note; playback posts announcements per item; response by activating tiles. |
| N-Back | Position spoken ("top left") plus letter in dual; buttons "Position match" / "Sound match". |
| Word Recall | Words announced during study; test grid is a list of toggle buttons. |

Relaxed timing (1.5×) recommended to VoiceOver users on first game (prompt, not forced).

## 11. Research basis (science.json)

The owner must verify each citation before submission. DOIs are displayed as plain text only.

| Game | Skill | Citations |
|---|---|---|
| Pair Match | Visuospatial short-term memory | Baddeley & Hitch 1974 (doi:10.1016/S0079-7421(08)60452-1); Della Sala et al. 1999, *Neuropsychologia* 37(10) (doi:10.1016/S0028-3932(98)00159-6) |
| Sequence Echo | Visuospatial working-memory span | Corsi 1972 (PhD thesis, McGill); Kessels et al. 2000, *Applied Neuropsychology* 7(4) (doi:10.1207/S15324826AN0704_8) |
| N-Back | Working-memory updating | Kirchner 1958, *J Exp Psych* 55(4) (doi:10.1037/h0043688); Jaeggi et al. 2008, *PNAS* 105(19) (doi:10.1073/pnas.0801268105); Owen et al. 2005, *Hum Brain Mapp* 25(1) (doi:10.1002/hbm.20131) |
| Word Recall | Episodic memory, retrieval practice | Roediger & Karpicke 2006, *Psych Sci* 17(3) (doi:10.1111/j.1467-9280.2006.01693.x); Roediger & McDermott 1995, *JEP:LMC* 21(4) (doi:10.1037/0278-7393.21.4.803); Brown 1958, *QJEP* 10(1) (doi:10.1080/17470215808416249); Peterson & Peterson 1959, *J Exp Psych* 58(3) (doi:10.1037/h0049234) |
| Daily Training | Adaptive difficulty | Levitt 1971, *JASA* 49(2B) (doi:10.1121/1.1912375); Klingberg 2010, *Trends Cogn Sci* 14(7) (doi:10.1016/j.tics.2010.05.002) |
| Evidence note | — | Melby-Lervåg & Hulme 2013, *Dev Psych* 49(2) (doi:10.1037/a0028228); Simons et al. 2016, *PSPI* 17(3) (doi:10.1177/1529100616661983) |
| Scoring | — | Snodgrass & Corwin 1988, *JEP: General* 117(1) (doi:10.1037/0096-3445.117.1.34) |

Standard evidence note (every Science screen): "Practising these tasks reliably improves performance on them. Evidence that such practice improves memory or intelligence in everyday life is mixed. This app is for entertainment and education, not medical use."

## 12. Enforcement (Stage 5 gates)

`scripts/check-no-network.sh`, run by CI, a git pre-commit hook, and a Claude Code `PreToolUse` hook:
- fails on `URLSession`, `import Network`, `WebKit`, `SFSafariViewController`, `NSURLConnection`, `CFNetwork`, `Package.resolved`, `XCRemoteSwiftPackageReference`;
- fails on `http://` / `https://` literals in Swift outside `Services/Links.swift`.

`xcrun swift-format lint --strict --recursive GetSmarter GetSmarterTests GetSmarterUITests`.

## 13. Out of scope for code (owner actions)

App Store Connect record, leaderboards/achievements setup, CloudKit container creation, archive/upload, TestFlight. See `docs/release/app-store-connect.md`.
