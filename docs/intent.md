# Intent — Get Smarter: Memory Games

Stage 1 (Plan) artifact of the AI-native SDLC playbook. Captures *what* we want, *why*, and *under which constraints*. Source: design interview, 2026-09-26.

## What

A free iOS/iPadOS game with four research-based memory mini-games, each with Beginner / Advanced / Expert tiers, plus an adaptive unranked Daily Training circuit. Players can optionally publish scores to Game Center leaderboards and see other players' scores.

## Why

Give people a fun, honest, well-crafted way to exercise specific memory skills, grounded in openly available cognitive-psychology research — without the overclaiming, ads, or data collection common in "brain training" apps.

## Goals

1. Four mini-games at launch, each modeled on an established research paradigm:
   - **Pair Match** — visuospatial short-term memory (concentration paradigm; Baddeley's visuospatial sketchpad).
   - **Sequence Echo** — working-memory span (Corsi block-tapping, incl. backward Corsi).
   - **N-Back** — working-memory updating (Kirchner 1958; Jaeggi et al. 2008 dual n-back).
   - **Word Recall** — episodic memory & retrieval practice (testing effect; DRM false memory; Brown–Peterson distractor).
2. Fixed parameters per tier so leaderboards are fair; soft unlocks between tiers.
3. Daily Training: ~5 min, unranked, adaptive 2-down/1-up staircase per game, streaks.
4. Game Center: 12 leaderboards (game × tier, all-time + weekly), ~10 achievements, explicit in-app opt-in before any score is published.
5. Progress synced across the user's devices via iCloud (private database).
6. Fully accessible, including VoiceOver-playable games.
7. Ready for App Store submission.

## Hard constraints

- **No network calls from app code.** No `URLSession`, `Network` framework, web views, remote assets/config, analytics, ads, or third-party SDKs. Only Apple first-party frameworks (GameKit, CloudKit via SwiftData) touch the network. The game is fully playable offline and signed out.
- **Sound generated internally** (synthesized with AVAudioEngine; speech via on-device `AVSpeechSynthesizer`). No bundled third-party audio.
- **Zero third-party dependencies.** No Swift packages.
- **Honest claims.** Say "based on / inspired by research" and "exercises <skill>". Never "improves memory", "boosts IQ", "prevents dementia", "clinically proven". Every game has an in-app Science screen with citations and a note that far-transfer evidence is mixed.
- **Privacy:** App Store label "Data Not Collected"; no tracking; privacy manifest present.
- SwiftUI, Swift 6 strict concurrency, iOS 18+, universal iPhone + iPad.
- Source is public but **All Rights Reserved**.

## Non-goals (v1)

- Combined cross-game leaderboard.
- Background music.
- Localization beyond English (but all strings in a String Catalog).
- In-app purchases, ads, accounts, push notifications.
- Kids category.
- Xcode Cloud / fastlane automation.

## Success criteria

- All four games × three tiers playable, tested, VoiceOver-accessible.
- CI green: unit tests, UI smoke tests, format lint, no-network guard.
- App builds, archives, and passes App Store review on first or second submission.

## Owner decisions log

| # | Decision |
|---|---|
| 1 | Network rule = app code makes no calls; Apple frameworks (GameKit, CloudKit) allowed |
| 2 | 4 mini-games × 3 tiers at launch |
| 3 | SwiftUI, Swift 6, iOS 18+, universal, zero deps |
| 4 | 12 leaderboards + weekly, per-game scoring, fixed-length sessions, ~10 achievements |
| 5 | Fixed tiers, soft unlock + "Unlock all" toggle, adaptive unranked Daily Training |
| 6 | Conservative research wording, Science screens, Puzzle category |
| 7 | Synthesized sound, `.ambient` session, haptics, no music |
| 8 | Full VoiceOver incl. games; audio n-back variant; relaxed timing (unranked) |
| 9 | 4+, not Kids category, English + String Catalog, free |
| 10 | iCloud sync via SwiftData + CloudKit private DB |
| 11 | Individual developer account (Ajay Narain Mathur); bundle `com.ajaymathur.memorisegetsmatter` |
| 12 | Full AI-SDLC layout; public repo; CI on push + PR; rebase-merge |
| 13 | All Rights Reserved license |
| 14 | Native style, Okabe-Ito palette, generated layered icon, XCUITest screenshots |
| 15 | Game Center opt-in publish prompt, offline score queue, custom in-app leaderboard |
| 16 | Tier parameter table (see design.md) |
| 17 | 3-screen onboarding, interactive tutorials, opt-in local daily reminder |
| 18 | GitHub Pages for privacy/support; support email ajaynarainmathur@gmail.com |
| 19 | Fully autonomous build, milestone PRs |
