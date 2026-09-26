# Release checklist (owner actions)

Everything in code is done. These steps need your Apple Developer account and can't be automated from this repo. Work top to bottom.

## 1. Apple Developer portal: identifiers

1. [developer.apple.com](https://developer.apple.com/account) → Certificates, IDs & Profiles → **Identifiers** → **+** → App IDs → App.
2. Description `Get Smarter`, Bundle ID (explicit) `com.ajaymathur.memorisegetsmatter`.
3. Capabilities: tick **Game Center**, **iCloud** (include CloudKit support), **Push Notifications** (CloudKit uses silent pushes to sync). Save.
4. Identifiers → **+** → iCloud Containers → `iCloud.com.ajaymathur.memorisegetsmatter`.
5. Back on the App ID → iCloud → Configure → select that container.

## 2. Xcode signing

1. Open `GetSmarter.xcodeproj` → target **GetSmarter** → Signing & Capabilities.
2. Team: your personal team (Ajay Narain Mathur). Automatic signing stays on.
3. Confirm the capabilities list shows Game Center, iCloud (CloudKit, container above), Push Notifications, Background Modes (Remote notifications).
4. Don't commit your `DEVELOPMENT_TEAM` if you want the public repo team-agnostic. Or commit it: a team ID isn't secret.

## 3. CloudKit schema

1. Run the app once on a device or simulator signed in to iCloud (Debug build) and play one game. This creates the development schema.
2. [CloudKit Console](https://icloud.developer.apple.com) → container → **Deploy Schema Changes** to Production. **Required before release**, or sync fails for App Store users.

## 4. App Store Connect: app record

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → Apps → **+** → New App.
2. Platform iOS, Name from `metadata.md`, primary language English (U.S.), bundle ID above, SKU `getsmarter-memory-001`, full access.
3. If the name is taken, use the fallback in `metadata.md`.

## 5. Game Center

App Store Connect → your app → **Services** (Features) → Game Center. Create exactly what's in `game-center.json`:

- **24 leaderboards**: for each game × level, one **Classic** (`...alltime`) and one **Recurring** (`...weekly`, start next Monday 00:00 UTC, duration 1 week, restarts weekly). Score format: Integer, sort High to Low, submission type Best Score, range 0–5000. Add an English localization using the `name`.
- **10 achievements**: IDs, titles, descriptions, and points from the JSON; not hidden, not repeatable. Each needs a 512×512 or 1024×1024 image (use the app icon or a simple symbol).
- On the app version page, tick **Game Center** so leaderboards ship with 1.0.

IDs must match exactly. The app submits to `lb.<game>.<tier>.alltime` and `.weekly`.

## 6. Version 1.0.0 page

- Paste metadata, keywords, description, promo text, URLs from `metadata.md`.
- Screenshots: run `scripts/screenshots.sh`, upload the 6.9" iPhone and 13" iPad sets.
- App Privacy: "Data Not Collected".
- Age rating: answer per `metadata.md` → 4+.
- Accessibility: claim the labels listed in `metadata.md`.
- App Review notes: paste `review-notes.md`.
- Export compliance: already answered by `ITSAppUsesNonExemptEncryption = NO` in Info.plist.

## 7. Build & upload

1. In `Config/GetSmarter.entitlements`, `aps-environment` is `development`. Xcode switches it to production automatically when archiving for App Store distribution.
2. Bump `CURRENT_PROJECT_VERSION` for each upload (1, 2, 3…). `MARKETING_VERSION` stays `1.0.0`.
3. Xcode → Product → Destination **Any iOS Device** → **Archive** → Distribute App → App Store Connect → Upload.

## 8. TestFlight

1. Wait for processing (≈15–30 min), then add yourself and a few friends as **internal testers**.
2. Test on a real device: sign in to Game Center (sandbox), post a score, check the in-app leaderboard, install on a second device to confirm iCloud sync, turn on VoiceOver and play each game, toggle airplane mode and play.
3. Check that the privacy and support URLs load (GitHub Pages must be enabled; see below).

## 9. Submit

Select the build on the version page → **Add for Review** → Submit. Choose manual or automatic release.

After approval: `git tag v1.0.0 && git push origin v1.0.0`.

## GitHub Pages (one-time)

Repo → Settings → Pages → Source: **GitHub Actions**. The `Pages` workflow deploys `site/` on every push to `main` that touches it.

## Before submitting: verify

- [ ] Citations in `GetSmarter/Resources/science.json` checked against the sources (design.md §11)
- [ ] Support email on the site is the one you want public
- [ ] CloudKit schema deployed to Production
- [ ] All 24 leaderboards + 10 achievements created with matching IDs
