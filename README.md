# Get Smarter: Memory Games

A free, offline-first iOS/iPadOS game with four memory mini-games based on classic cognitive-psychology tasks:

| Game | Exercises | Based on |
|---|---|---|
| Pair Match | Visuospatial short-term memory | Concentration paradigm, Baddeley & Hitch |
| Sequence Echo | Working-memory span | Corsi block-tapping |
| N-Back | Working-memory updating | Kirchner 1958, Jaeggi et al. 2008 |
| Word Recall | Episodic memory, retrieval | Testing effect, DRM false memory, Brown–Peterson |

Each has Beginner, Advanced and Expert tiers, plus an adaptive Daily Training circuit. Optional Game Center leaderboards. No ads, no tracking, no data collected. The app code makes no network calls.

*Entertainment and education only, not a medical product. Evidence that such practice transfers to everyday memory is mixed.*

## Docs

- [Intent](docs/intent.md): goals and constraints
- [Requirements](docs/requirements.md)
- [Design](docs/design.md)
- [Release checklist](docs/release/app-store-connect.md)

## Build

Xcode 26+ (tested with Xcode 27). Open `GetSmarter.xcodeproj`, run the `GetSmarter` scheme. See [CLAUDE.md](CLAUDE.md) for test and lint commands.

## Release

- `swift scripts/make-icon.swift`: regenerate the app icon
- `scripts/screenshots.sh`: capture App Store screenshots into `./screenshots`
- [docs/release/](docs/release/): metadata, review notes, Game Center IDs, and the App Store Connect checklist
- Website (privacy/support): https://ajaymathur.github.io/memorise-get-smatter/

## License

All rights reserved. See [LICENSE](LICENSE).
