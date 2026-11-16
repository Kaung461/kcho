# K帳 — JLPT Vocab & Grammar

A small, offline-first Flutter app (iOS-focused, Cupertino widgets) for studying Japanese
vocabulary (単語) and grammar (文法) with Myanmar translations. All JLPT levels.

## What's here

```
lib/
  main.dart                     app bootstrap: Hive init + CupertinoApp
  app_scope.dart                InheritedWidget exposing EntryRepository
  models/entry.dart             Entry model + hand-written Hive TypeAdapter
  services/entry_repository.dart CRUD over the Hive box + first-run sample seed
  screens/
    root_tabs.dart              bottom tab bar (Home / Flashcards / Quiz / Progress)
    home_screen.dart            単語/文法 segmented list, "+" to add, tap to edit
    add_entry_screen.dart       add / edit / delete form
    flashcard_screen.dart       one card, tap to flip, swipe for next/previous
    quiz_screen.dart            50-question sessions, 4-choice, auto-advance, score
    progress_screen.dart        stat cards (total / mastered / learning …)
  widgets/entry_tile.dart       Home list row
```

Storage is **Hive**, fully local — no backend, no network. The Hive adapter is
hand-written, so there is **no `build_runner` / codegen step**.

## Quick run (no Xcode) — web

```sh
export PATH="$PATH:/opt/homebrew/bin"
flutter create --project-name k_cho --platforms=web .
flutter pub get
flutter run -d chrome
```

The app runs fully on web: Cupertino widgets render, Hive uses IndexedDB, and
`path_provider` is not touched on web. Good for verifying behaviour quickly.

## Live web deploy (GitHub Pages)

Every `git push` to `main` triggers [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml),
which builds the web release and publishes it to the `gh-pages` branch automatically —
no manual deploy step needed.

Live URL: **https://kaung461.github.io/kcho/**

One-time setup on GitHub (not something a workflow file can do): go to
**Settings → Pages** on the repo and set the source to the `gh-pages` branch
(it's created by the first workflow run, so do this after that run finishes once).

⚠️ **The web build and the Mac desktop build do not share data.** Storage is
per-platform: the desktop app persists to a local Hive file on disk, while the
web build uses the browser's IndexedDB. Entries you add in one do not appear
in the other, and clearing browser data / a different browser wipes the web
copy independently of the desktop copy. There's no sync between them.

Also web-only limitation: the Settings screen's **Study reminder** (local
notifications) has no effect in the browser — `flutter_local_notifications`
doesn't ship a web implementation, so the switch just won't schedule anything
there. It works normally on iOS/macOS.

## First-time setup (iOS — the real target)

This project ships only `lib/` + `pubspec.yaml`. Generate the platform folders and
fetch packages:

```sh
# 1. Install Flutter if needed:  https://docs.flutter.dev/get-started/install/macos
#    (Xcode + CocoaPods are required for the iOS simulator.)

cd K帳

# 2. Create the ios/ platform folder. `flutter create` skips files that already
#    exist (lib/, pubspec.yaml), so it only adds the missing platform scaffolding.
#    If it reports that pubspec.yaml changed, `git checkout pubspec.yaml` to keep
#    the dependency list in this repo.
flutter create --org com.example --project-name k_cho --platforms=ios .

# 3. Get dependencies
flutter pub get

# 4. Run on an iOS simulator (or any attached device)
open -a Simulator
flutter run
```

## First-time setup (macOS desktop)

```sh
export PATH="$PATH:/opt/homebrew/bin"
flutter create --org com.example --project-name k_cho --platforms=macos .
flutter pub get
flutter run -d macos
```

⚠️ **Required manual step for the AI features** (auto-fill, reading passages). `flutter
create` generates a sandboxed macOS app that only grants the network **server**
entitlement by default, so the outgoing HTTP calls to Groq's API are silently
blocked — the app just shows a generic communication error. After
generating `macos/`, add the client-networking entitlement to **both**
`macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`
(inside the existing `<dict>`):

```xml
<key>com.apple.security.network.client</key>
<true/>
```

This has to be redone any time `macos/` is regenerated from scratch, since that
whole folder is gitignored (see "What's here" above).

## AI features (auto-fill, reading passages, diary correction)

These call [Groq](https://console.groq.com) through a small server-side
proxy — see [`worker/`](worker/) — not directly from the app. The real Groq
API key lives only in that proxy (a Cloudflare Worker secret); it never
ships inside this app's build, so it can't be extracted from the public web
bundle (that's what happened before this was added — see the Worker's
README for the full story).

The app only needs the proxy's public URL, baked in at **build time** via
`--dart-define` (not a secret — just where to send requests):

```sh
flutter run -d macos --dart-define=AI_PROXY_URL=https://your-worker.workers.dev
```

Without `--dart-define`, this compiles in empty and the AI features show
"AI機能は現在利用できません" instead of failing silently.

The live web build (GitHub Pages) gets this from the repo's `AI_PROXY_URL`
[Actions variable](../../settings/variables/actions) (a plain variable, not
a secret) — see [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml).
Deploying/updating the proxy itself is a separate step — see
[`worker/README.md`](worker/README.md).

## Data model

| field            | notes                                              |
|------------------|----------------------------------------------------|
| `id`             | UUID, also the Hive key                             |
| `type`           | `tango` \| `grammar`                                |
| `term`           | Kanji/word (tango) or grammar pattern              |
| `reading`        | よみかた — tango only, nullable                      |
| `meaningMy`      | Myanmar meaning                                     |
| `exampleSentence`| 例文                                                |
| `correctCount` / `wrongCount` / `lastReviewed` | spaced-repetition counters |
| `createdAt`      | set on creation                                     |

**Mastered** = `correctCount >= 3 && wrongCount == 0`.

## Notes / possible extensions

- Spaced repetition currently just records correct/wrong counts. A natural next step:
  weight quiz selection toward entries with `wrongCount > 0` or an old `lastReviewed`
  (see `EntryRepository._buildSession` in `quiz_screen.dart`).
- Sample entries are seeded once on first launch (`EntryRepository.seedIfEmpty`).
  Delete them from Home once you've added your own.
