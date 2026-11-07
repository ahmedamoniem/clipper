# Practical macOS validation

Research checked on 2026-11-07. Select the sections relevant to the change.

## Build and tests

Read the repository's CI commands and shared scheme. Inspect `xcodebuild -version`
and `swift --version`. If needed, prefix commands with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; adapt the path to the
installed Xcode. Do not change global `xcode-select` just for a check.

For an Xcode app, a common local check is:

```sh
xcodebuild -project MyApp.xcodeproj -scheme MyApp \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/MyApp-validation \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES test
```

This builds and tests the active architecture without establishing distribution
readiness. Capabilities that need signing may need a separate signed test setup.
For SwiftPM packages use `swift test`; it does not validate an Xcode app bundle.
Preserve a command's exit status when logging through `tee` by using `pipefail`.
Keep generated build data and logs outside tracked sources.

Useful behavioral checks, selected by the changed feature:

- Collections: empty input, duplicates, retention limits, search, pin/unpin rules.
- Persistence: round trip, missing/corrupt data, old schema, save ordering, clear
  followed by restart, and shutdown while a debounced write is pending.
- Asynchronous work: cancellation, replacement by newer work, bounded retries,
  and failure after a dependency disappears. Prefer controllable time or explicit
  completion over sleeps.
- Preferences: use an isolated defaults suite or injected settings and restore
  any changed global state. Temporary files alone do not isolate preferences.

## Desktop smoke checks

| Changed area | Exercise | Observe |
| --- | --- | --- |
| Windows or popup | Open, close, reopen; Escape and outside click; switch apps | Correct focus, no stranded monitors or duplicate windows |
| Keyboard and menus | Tab/arrow navigation, standard commands, configured hotkey conflict | Reachable actions, visible shortcuts, useful conflict handling |
| Accessibility/UI | VoiceOver labels, keyboard-only use, light/dark appearance, relevant sizes | Controls remain named, readable, and usable |
| Permissions | Denied, granted, then revoked | Only dependent feature is limited; fallback remains useful |
| Cross-app paste | Target active, activation delayed, target exits or cannot activate | Input reaches the intended target or stops safely |
| Persistence | Add, delete/clear, quit, relaunch | Latest intended state survives without deleted data returning |
| Utility lifecycle | Idle, repeated popup toggles, sleep/wake, multiple displays | No repeated work, leaked timers, misplaced popup, or focus theft |

Do not grant permissions or emit keystrokes into unrelated apps merely to complete
a review. Use an authorized test app/session. If unavailable, mark the check not
run. Apple emphasizes desktop commands, keyboard use, and multi-app transitions
in [Designing for macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos).

For performance work, compare Release builds on the same machine with the same
data and interaction sequence. Use Instruments when a trace will resolve a
specific issue; inspect CPU/wakeups at idle, memory over repeated operations, or
latency on the critical interaction. Choose the tool to answer the question.

## Distribution, when in scope

Decide the channel before changing entitlements. [Apple's distribution comparison](https://developer.apple.com/macos/distribution/)
lists App Sandbox as required for the Mac App Store and recommended outside it.
Check whether the product's cross-app behavior is compatible before promising an
App Store release. Sandbox entitlements and user-granted Accessibility trust are
separate mechanisms.

For direct distribution, use Developer ID signing and notarization with the
required hardened runtime and timestamp. An ad-hoc signature does not establish
developer identity or notarization. Inspect the notary log; staple and validate
the ticket where supported. See [notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [custom workflows](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
Do not copy a CI command using `codesign --deep --sign -` into a production signing
recipe; nested code needs an intentional signing order and appropriate identities.

After the authorized signing/notarization workflow, useful read-only checks are:

```sh
codesign --verify --deep --strict --verbose=2 /path/to/MyApp.app
codesign -d --verbose=4 --entitlements :- /path/to/MyApp.app
spctl --assess --type execute --verbose=4 /path/to/MyApp.app
xcrun stapler validate /path/to/MyApp.app
```

These checks cover different properties; a valid signature alone does not prove
Gatekeeper acceptance. Validate a stapled DMG on the DMG if that is where the
ticket is attached. Test a downloaded, quarantined artifact on a clean test Mac
with normal Gatekeeper settings, including install, launch, upgrade, and uninstall.
Test the minimum supported OS and each promised architecture when release scope
requires them; report unavailable coverage explicitly.

Keep notarization credentials out of source control. Review required-reason API
and privacy-manifest obligations for the actual APIs and distribution path; for
example, Apple's [UserDefaults documentation](https://developer.apple.com/documentation/foundation/userdefaults)
identifies its privacy-manifest requirement. Do not add entitlements speculatively.
