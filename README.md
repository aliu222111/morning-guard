# Morning Guard

An iOS app that blocks distracting apps for the first stretch of your morning, then walks you through a routine instead.

The block is enforced by iOS itself, not by willpower or a timer you can dismiss. Morning Guard uses Apple's Screen Time frameworks — `FamilyControls`, `ManagedSettings` and `DeviceActivity` — so shielded apps simply refuse to open until the window ends.

## How it works

The interesting constraint is that the block has to apply *without the app running*. You unlock your phone at 6:40am and reach for Instagram; Morning Guard was never launched, so it can't react.

`DeviceActivity` solves this by letting you register a schedule with the system ahead of time. A separate extension target (`MorningGuardExtension`) wakes on the schedule boundary and applies the shield through `ManagedSettingsStore`. A third target (`MorningGuardShield`) customises what you see when you hit a blocked app, so it's a gentle nudge rather than a wall.

State that both the app and the extension need — the streak count especially — lives in a shared App Group (`group.com.alexliu.morningguard`), since the two processes can't otherwise see each other's `UserDefaults`.

## The routine

Once the block is up, the app offers something to do with the time:

- **Journal** — 365 prompts, one per day, with optional voice entry via `SFSpeechRecognizer`
- **Morning light** — a sunlight-exposure step that checks local conditions with WeatherKit
- **Breathe, hydrate, move** — short guided steps
- **Affirmations** — a bank of 50
- **Streaks** — tracked across app and extension, surfaced in a home-screen widget

Journal entries stay on device. WeatherKit authenticates through the app's signing entitlement, so there's no API key anywhere in this repo.

## Targets

| Target | Role |
|---|---|
| `MorningGuard` | Main SwiftUI app |
| `MorningGuardExtension` | `DeviceActivityMonitor` — applies and lifts shields on schedule |
| `MorningGuardShield` | Custom shield UI for blocked apps |
| `MorningGuardWidgets` | Home-screen streak widget |

~6,400 lines of Swift. iOS 17.6+.

## Building

The project file is generated, so `project.yml` is the source of truth — edit that, not the `.xcodeproj`.

```bash
brew install xcodegen
xcodegen generate
open MorningGuard.xcodeproj
```

One thing that will stop you: **`com.apple.developer.family-controls` is a restricted entitlement.** Apple grants it per–developer account on request, and without it the Screen Time calls fail at runtime. The app builds and the UI works, but nothing will actually block. `DEVELOPMENT_TEAM` in `project.yml` is set to my team — change it to yours.

## Status

Builds and runs on device; last archive was 1.0 build 2. Store submission isn't wired up yet — `fastlane/` has the signing lanes scaffolded but `match` hasn't been run. `website/` holds the marketing, privacy and support pages, and `appstore-screenshots/` the store assets, both ready to go.
