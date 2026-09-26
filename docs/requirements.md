# Requirements

Stage 2 (Design) artifact. Derived from [intent.md](intent.md). Each requirement has an ID referenced by tests and commits. Parameters live in [design.md](design.md).

## Global

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-G-01 | App code makes no network calls | CI guard fails on `URLSession`, `import Network`, `WKWebView`, `SFSafariViewController`, `http(s)://` literals in Swift (except allowlisted static store/support links in `Links.swift`), and any `Package.resolved` |
| REQ-G-02 | Fully playable offline and without Game Center / iCloud | UI test runs every game with no auth |
| REQ-G-03 | Zero third-party dependencies | No SPM packages in project |
| REQ-G-04 | iOS 18+, iPhone + iPad | Deployment target 18.0, device family 1,2 |
| REQ-G-05 | iPhone portrait-only; iPad all orientations | Info.plist orientations |
| REQ-G-06 | All user-visible strings in `Localizable.xcstrings` | No raw literals outside `Text("…")` / `String(localized:)` |
| REQ-G-07 | Privacy manifest declares no tracking, no collected data, UserDefaults reason `CA92.1` | `PrivacyInfo.xcprivacy` present in bundle |
| REQ-G-08 | `ITSAppUsesNonExemptEncryption = NO` | Info.plist |

## Games (shared)

| ID | Requirement | Acceptance |
|---|---|---|
| REQ-GM-01 | Four games, three tiers each, fixed params per tier | Engine unit tests assert params from design.md |
| REQ-GM-02 | Game engines are deterministic given a seed | Same seed → same board/sequence in tests |
| REQ-GM-03 | Score computed per design.md formula; never negative | Unit tests incl. edge cases |
| REQ-GM-04 | Result screen: score, accuracy, personal-best badge, replay, menu | UI test |
| REQ-GM-05 | Backgrounding or pause hides the board and freezes timers; resume continues. Stimulus in progress (preview, playback, n-back trial, study word) restarts from the current item so pausing cannot extend exposure | Unit test on engine clock |
| REQ-GM-06 | Soft unlock: Advanced after Beginner score ≥ threshold; Expert after Advanced ≥ threshold; "Unlock all" setting bypasses | Unit tests on `Progression` |
| REQ-GM-07 | Suggest next tier after 3 scores ≥ threshold | Unit test |
| REQ-GM-08 | Interactive tutorial on first open per game; replayable via "?" | UI test |
| REQ-GM-09 | Science screen per game: skill, paradigm, citations (plain text), mixed-evidence note | Content JSON validated by test |

## Pair Match (REQ-PM)

| ID | Requirement |
|---|---|
| REQ-PM-01 | Grid & pairs per tier; preview duration per tier; 90 s cap |
| REQ-PM-02 | Tap flips card; two non-matching cards flip back after 0.8 s; matched stay revealed |
| REQ-PM-03 | Taps ignored while two unmatched cards are showing |
| REQ-PM-04 | Each card face = SF Symbol + color (never color alone) |
| REQ-PM-05 | VoiceOver: card announced as "Card, row r column c, face down" / "<symbol name>"; flip via activate |

## Sequence Echo (REQ-SE)

| ID | Requirement |
|---|---|
| REQ-SE-01 | Grid, start span, item duration per tier; Expert uses backward recall |
| REQ-SE-02 | Two trials per span; advance span if either correct; stop when both fail |
| REQ-SE-03 | Each tile has distinct pentatonic tone + symbol |
| REQ-SE-04 | Taps disabled during playback |
| REQ-SE-05 | VoiceOver: playback announces tile names; tiles are buttons with names |

## N-Back (REQ-NB)

| ID | Requirement |
|---|---|
| REQ-NB-01 | n and modality per tier; 500 ms stimulus, 3 s trial, 20 + n trials, ~30 % targets per modality |
| REQ-NB-02 | "Position match" and (dual) "Sound match" buttons; response window = trial |
| REQ-NB-03 | Score from hits, misses, false alarms per design.md |
| REQ-NB-04 | Letters spoken with on-device `AVSpeechSynthesizer` |
| REQ-NB-05 | VoiceOver / audio mode: position also spoken ("top left"), so the game is playable eyes-free |

## Word Recall (REQ-WR)

| ID | Requirement |
|---|---|
| REQ-WR-01 | Study list length, exposure per word, choice grid size per tier |
| REQ-WR-02 | Advanced/Expert include DRM semantic lures among foils |
| REQ-WR-03 | Expert: 15 s count-backward distractor between study and test |
| REQ-WR-04 | Word bank ≥ 300 concrete nouns + ≥ 12 DRM lure sets, bundled JSON; no word repeats within a session |
| REQ-WR-05 | Test = tap all words you studied, then "Done" |

## Daily Training (REQ-DT)

| ID | Requirement |
|---|---|
| REQ-DT-01 | Circuit of 4 games, ~75 s each, unranked |
| REQ-DT-02 | Per-game level stored; 2-down/1-up staircase adjusts within session |
| REQ-DT-03 | Completing a circuit counts toward daily streak (local calendar day) |
| REQ-DT-04 | Never submits to leaderboards |

## Game Center (REQ-GC)

| ID | Requirement |
|---|---|
| REQ-GC-01 | Authenticate at launch, non-blocking |
| REQ-GC-02 | One-time opt-in prompt on first ranked result while authenticated; setting toggle thereafter |
| REQ-GC-03 | Scores submitted only if authenticated AND opted in AND ranked session (not relaxed timing, not Daily Training) |
| REQ-GC-04 | Offline/unauthenticated ranked scores (when opted in) queued; flushed on auth/foreground |
| REQ-GC-05 | In-app leaderboard: game + tier, Global/Friends, All-time/This week, top 25 + local player rank |
| REQ-GC-06 | Access point visible on main menu only |
| REQ-GC-07 | Achievements per design.md reported when authenticated + opted in |

## Data & Sync (REQ-DS)

| ID | Requirement |
|---|---|
| REQ-DS-01 | SwiftData models CloudKit-compatible (all optional/defaulted, no unique constraints, optional relationships) |
| REQ-DS-02 | Sync via CloudKit private DB; works local-only when iCloud unavailable |
| REQ-DS-03 | Settings stored locally via `@AppStorage` |
| REQ-DS-04 | Reset progress (with confirmation) deletes all sessions & progression |

## Audio / Haptics (REQ-AU)

| ID | Requirement |
|---|---|
| REQ-AU-01 | All SFX synthesized at runtime; audio session `.ambient` |
| REQ-AU-02 | Sound and haptics toggles |

## Accessibility (REQ-AX)

| ID | Requirement |
|---|---|
| REQ-AX-01 | Dynamic Type in all non-board UI |
| REQ-AX-02 | Reduce Motion replaces flips/scale with fades |
| REQ-AX-03 | Colorblind-safe palette + symbols; Differentiate Without Color honored |
| REQ-AX-04 | Tap targets ≥ 44 pt |
| REQ-AX-05 | VoiceOver-complete: menus, settings, games, results, leaderboards |
| REQ-AX-06 | "Relaxed timing" setting: 1.5× timing windows; sessions become unranked |
| REQ-AX-07 | Dark Mode and Increase Contrast supported |

## UX (REQ-UX)

| ID | Requirement |
|---|---|
| REQ-UX-01 | 3-screen skippable onboarding incl. disclaimer |
| REQ-UX-02 | Progress screen: best per game/tier, trend chart, streak |
| REQ-UX-03 | Optional daily reminder (local notification); permission requested only when enabled |
| REQ-UX-04 | `requestReview` only after a personal best, at most once per 30 days (OS further limits) |
| REQ-UX-05 | Settings: sound, haptics, relaxed timing, unlock all, share scores, reminder, reset, about/science, privacy & support links |

## Release (REQ-RL)

| ID | Requirement |
|---|---|
| REQ-RL-01 | App icon (light/dark/tinted) + 1024 PNG fallback |
| REQ-RL-02 | Screenshot UI test producing 6.9" iPhone and 13" iPad images |
| REQ-RL-03 | GitHub Pages site: landing, privacy, support |
| REQ-RL-04 | Store metadata, review notes, App Store Connect checklist in `docs/release/` |
