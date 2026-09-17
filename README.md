# Morning Guard

An iOS app that blocks your distracting apps for the first stretch of the morning, then gives you something to do with the time instead.

The block is enforced by iOS itself rather than by willpower, so a shielded app simply refuses to open until the window ends. Morning Guard does this with Apple's Screen Time frameworks: `FamilyControls`, `ManagedSettings` and `DeviceActivity`.

## How it works

The awkward part of the problem is that the block has to apply while the app isn't running. You unlock your phone at 6:40am and reach straight for Instagram, and Morning Guard was never launched, so it has no chance to react.

`DeviceActivity` gets around this by letting you register a schedule with the system in advance. A separate extension target, `MorningGuardExtension`, wakes up when the schedule boundary hits and applies the shield through `ManagedSettingsStore`. A third target, `MorningGuardShield`, replaces the default blocked-app screen with something softer than a hard stop.

Because the app and the extension run as separate processes, they can't see each other's `UserDefaults`. Anything both of them need, the streak count in particular, lives in a shared App Group (`group.com.alexliu.morningguard`).

## The routine

Once the block is up, the app walks you through a set of steps, one screen at a time. There's a journal with 365 prompts, one per day, which you can type or dictate through `SFSpeechRecognizer`. There's a morning-light step that uses the camera as a lux meter, with `CoreMotion` checking that you're actually holding the phone toward the sky, and it tells you how long to stay out based on the reading (roughly 7 minutes in direct sun, 20 under overcast). The rest are shorter: breathe, hydrate, move, and a bank of 50 affirmations. Streaks are tracked across both the app and the extension and surface in a home-screen widget. Weather for the day comes from WeatherKit on the home screen, separately from the light meter.

Journal entries never leave the device. WeatherKit authenticates through the app's signing entitlement, so there's no API key anywhere in this repo.

## Targets

| Target | Role |
|---|---|
| `MorningGuard` | Main SwiftUI app |
| `MorningGuardExtension` | `DeviceActivityMonitor`, applies and lifts shields on schedule |
| `MorningGuardShield` | Custom shield UI for blocked apps |
| `MorningGuardWidgets` | Home-screen streak widget |

About 6,400 lines of Swift. iOS 17.6+.

## Building

The Xcode project is generated from `project.yml`, so edit that file rather than the `.xcodeproj`.

```bash
brew install xcodegen
xcodegen generate
open MorningGuard.xcodeproj
```

One thing will stop you cold: `com.apple.developer.family-controls` is a restricted entitlement that Apple grants per developer account on request. Without it the app still builds and the UI still works, but the Screen Time calls fail at runtime and nothing actually gets blocked. You'll also want to change `DEVELOPMENT_TEAM` in `project.yml`, which is currently set to mine.

## Status

Builds and runs on a device, last archived as 1.0 build 2 in August 2026. There's an App Store Connect record reserved (app ID 6793297906) but the app isn't live in any store yet, and the fastlane lanes in `fastlane/` are scaffolded without `match` having been run, so signing isn't set up either.

Worth knowing if you read the marketing copy in `website/`: it was written ahead of a release that hasn't happened, so the hero badge claims "Now on the App Store" and the download buttons point at that reserved ID. Both are premature.
