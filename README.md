# Toehold

Break any task into steps so small you cannot refuse the first one.

## What it is

You know what to do. You cannot make yourself start. That gap is the whole
product.

Type the thing you are stuck on, or tap the situation you already know you are
stuck on. You get a short list of steps where the first one takes under five
seconds and is physical — "stand up", "pick up the toothbrush". Then one step
on screen at a time, because seeing the whole list is the thing that stopped
you.

## Why the AI is free

Breakdowns run on device through Apple's Foundation Models framework. There is
no server, no account, and no per-request cost, so there is nothing to meter
and no reason to put it behind a subscription.

On a device without Apple Intelligence, built-in self-care chains answer
instead. The app never tells you which one ran. A person on an older phone gets
a working app, not a degraded one with an explanation they did not ask for.

## Requirements

- iOS 17.0 or later
- Apple Intelligence (iPhone 15 Pro or newer, supported region) for free-text
  breakdowns of anything you type. Every device gets the built-in chains.

## Building

The Xcode project is generated, not committed:

```sh
brew install xcodegen
xcodegen generate
open Toehold.xcodeproj
```

`project.yml` is the only source of truth for build settings. Editing the
generated project means the change is lost on the next `generate`.

## Layout

| Path | What is in it |
|---|---|
| `Core/` | Generators and the scenario chains. No UI, no `ModelContainer` |
| `Models/` | SwiftData models |
| `Services/` | `TaskStore` — every write the app makes |
| `Views/` | SwiftUI screens |
| `Tests/` | Swift Testing suites |
| `ci/` | App icon generation and the screenshot capture script |

## CI

`.github/workflows/build.yml` builds, runs the tests, and can archive and
upload to TestFlight. It needs these repository secrets, which are not in this
repo and never will be:

`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64`, `DIST_P12_BASE64`,
`DIST_P12_PASSWORD`, `PROVISIONING_PROFILE_BASE64`

A build-only run needs none of them.

## Status

Written on Windows with no Xcode available, so **nothing here has been
compiled yet**. The first real build happens in CI on macOS, and the first run
is expected to surface things a compiler would have caught locally.

## License

Not yet chosen. All rights reserved until one is.
