# CLAUDE.md

iOS memory game "Get Smarter: Memory Games". Read `docs/intent.md` (constraints), `docs/requirements.md` (REQ IDs), `docs/design.md` (params, formulas) before changing behavior.

## Commands

```sh
# build + unit/UI tests (pick any installed iPhone simulator)
xcodebuild test -project GetSmarter.xcodeproj -scheme GetSmarter \
  -destination 'platform=iOS Simulator,name=iPhone 17' -quiet
# unit tests only
xcodebuild test -project GetSmarter.xcodeproj -scheme GetSmarter \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:GetSmarterTests -quiet
# gates (CI runs both)
scripts/check-no-network.sh
xcrun swift-format lint --strict --recursive GetSmarter GetSmarterTests GetSmarterUITests
```

## Hard rules

- **No network code.** Never use URLSession, Network, WebKit, SFSafariViewController, or URL literals outside `GetSmarter/Services/Links.swift`. Only GameKit and SwiftData/CloudKit may talk to the network.
- **No third-party packages.** Stdlib + Apple frameworks only.
- **No health claims** in UI strings or store copy: never "improves memory", "boosts IQ", "clinically proven", "prevents dementia". Use "based on research" / "exercises <skill>".
- SwiftData models stay CloudKit-compatible: default values on every property, no `.unique`, optional relationships.
- All user-facing strings via `Localizable.xcstrings` (SwiftUI `Text("…")` literals auto-extract).
- Engines (`Games/*/…Engine.swift`) are pure value types: no SwiftUI, no timers, deterministic with `SeededRNG`. Put logic there and unit-test it.
- Every interactive element needs a VoiceOver label; never convey state by color alone; honor Reduce Motion.
- Ranked scores only go to Game Center when authenticated AND `shareScores == true` AND mode == ranked.

## Conventions

- Swift 6 strict concurrency, iOS 18 deployment target, `@Observable` over `ObservableObject`.
- Swift Testing (`import Testing`) for unit tests; XCTest only for UI tests.
- Conventional Commits, small and single-purpose, reference REQ IDs when relevant (`feat(pairmatch): flip-back delay (REQ-PM-02)`).
- One branch + PR per milestone; rebase-merge.
- New bug or rule breach → add `docs/intents/NNN-short-name.md`.
