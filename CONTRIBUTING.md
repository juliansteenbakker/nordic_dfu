# Contributing

Thanks for considering contributing to nordic_dfu!

## Getting started

This is a single-package Flutter plugin, so there is no bootstrap step:

```bash
flutter pub get
cd example && flutter pub get
```

The plugin wraps Nordic Semiconductor's official DFU libraries — the
[Android DFU Library](https://github.com/NordicSemiconductor/Android-DFU-Library)
(pulled in by `android/build.gradle.kts`) and the
[iOS DFU Library](https://github.com/NordicSemiconductor/IOS-DFU-Library) (pulled in
as a Swift package by `darwin/nordic_dfu/Package.swift`). Bugs in the DFU protocol
itself usually belong upstream; this repo owns the Dart API and the Android/Apple
platform channel code.

Layout:

* `lib/` — the public Dart API (`NordicDfu`) and the per-platform parameter classes.
* `android/src/` — Kotlin plugin implementation.
* `darwin/nordic_dfu/Sources/` — Swift implementation shared by iOS and macOS.
* `example/` — the example app, which doubles as the manual test harness.

## Testing changes

There are no meaningful unit tests: almost everything this plugin does requires a
real Bluetooth radio and a real Nordic device. Please verify your change by running
the example app against actual hardware and say so in the PR — including which
platform(s) you tested on and which nRF chip. A change that only compiles has not
been tested.

CI builds the example app for Android, iOS, and macOS, since `flutter analyze`
never compiles the Kotlin or Swift sources.

## Pull requests

* Open feature/fix PRs against `develop`. Only hotfixes for an already-released
  version go against `master`.
* PR titles must follow [Conventional Commits](https://www.conventionalcommits.org/)
  (e.g. `feat: ...`, `fix: ...`, `chore: ...`) — this is enforced by CI, and the
  title is what ends up in the changelog, since PRs are squash-merged.
* Use a scope when the change is platform-specific: `fix(android): ...`,
  `feat(darwin): ...`.
* Before pushing, run:

  ```bash
  flutter analyze .
  dart format --set-exit-if-changed .
  ```

  Both run in CI. Analysis also runs against the minimum supported Flutter version
  and against downgraded dependency versions, so avoid APIs that are newer than the
  floor declared in `pubspec.yaml`.

## Versioning

Releases are handled automatically by
[Release Please](https://github.com/googleapis/release-please). **Please don't bump
the `pubspec.yaml` version or add a `CHANGELOG.md` entry yourself** — Release Please
generates both from the merged commit messages.

1. Once your PR lands on `develop`, Release Please opens a
   `chore(develop): release X.Y.Z` PR.
2. Merging that PR tags the release, publishes to pub.dev via CI, and promotes the
   release commit onto `master`.
3. `darwin/nordic_dfu.podspec` is version-bumped automatically as an extra file, so
   it doesn't need a manual edit either.

For a hotfix on top of the latest release, branch from `master` and target `master`;
Release Please cuts the release there and opens a PR to sync it back into `develop`
(that one is merged manually, because the changelog can conflict with unreleased
work).
