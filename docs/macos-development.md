# Simple macOS app development

Research and repository review: 2026-11-07. These skills support native macOS
development with proportionate architecture and validation. The recommendations
are defaults to reconsider when product needs supply better evidence.

## Reusable skills

| Skill | Use it for | Supporting guide |
| --- | --- | --- |
| [macos-app-development](../.agents/skills/macos-app-development/SKILL.md) | Implement a feature or compare implementation choices | [Framework, architecture, storage, and concurrency decisions](../.agents/skills/macos-app-development/references/decisions.md) |
| [macos-app-validation](../.agents/skills/macos-app-validation/SKILL.md) | Test a change, review complexity, or assess release readiness | [Build, desktop, performance, and distribution checks](../.agents/skills/macos-app-validation/references/validation.md) |

The repository stores them in `.agents/skills/`. Invoke them in a Codex session
that has discovered the repository skills, for example:

```text
Use $macos-app-development to add a preferences toggle using the existing model.
Use $macos-app-validation to review this diff for correctness and unnecessary layers.
```

To reuse elsewhere, copy either complete skill folder, including its `references/`,
into that repository's `.agents/skills/`. Each skill is self-contained. Repository
instructions and the user's requirements take precedence over its defaults.

## Recommended starting point

For a new macOS-only utility, start with SwiftUI, a small concrete feature model,
and system APIs. Bridge to AppKit only where the behavior needs it. Apple supports
[both directions of integration](https://developer.apple.com/documentation/swiftui/appkit-integration).
For an existing app, the simpler choice is usually to preserve working code.

Use preferences for settings, Codable files for small bounded collections, and a
database for real query, relationship, or scale requirements. A framework choice
does not replace ownership, error handling, or persistence tests. The decision
guide compares SwiftUI, hybrid UI, AppKit, Electron, and Tauri, including situations
where cross-platform reuse could outweigh an additional runtime or toolchain.

Before adding a layer or dependency, name the problem it solves now, compare a
concrete smaller alternative, and include its maintenance and validation cost.
There is no mandatory MVVM, protocol-per-type, DI container, or multi-package
layout. Add structure when the feature benefits from it.

## Application to Clipper

The baseline inspected was `f92441f` on `workflow-fixes`. This branch adds guidance;
it does not change application behavior or release automation.

| Existing evidence | Practical conclusion |
| --- | --- |
| `AppDelegate` owns the store, status item, watcher, and popup; `PopupWindowController` hosts SwiftUI | Keep this small hybrid implementation; a SwiftUI-only rewrite needs a concrete benefit |
| macOS deployment target is 14.0; `ClipboardStore` uses `@Observable` and `@MainActor` | Observation fits the target; preserve explicit ownership and isolation |
| `ClipboardStore` persists Codable snapshots to Application Support | Keep JSON unless workload or query needs justify a database; test ordering and deletion durability |
| The watcher polls `NSPasteboard.changeCount` every 0.4 seconds | Measure idle wakeups and capture latency before changing the interval or introducing new machinery |
| Tests use XCTest and injected storage URLs | Extend the current tests when changing behavior; also isolate shared preferences |
| CI builds and tests a shared Xcode scheme | Reuse that command shape; do not add another build runner for documentation |
| Release workflow applies an ad-hoc signature | It is not a verified Developer ID/notarized distribution path; plan that separately when release work is requested |

Apple's [notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
specify Developer ID signing, hardened runtime, and a secure timestamp. The
current release workflow does not demonstrate those requirements being met.

Two concrete follow-up checks emerged from source review, outside this documentation
change: the clear-history observer removes items without scheduling a save, and
auto-paste sends after activation retries expire even when the target PID still
differs. Validate deletion across restart and failed-activation behavior before
claiming those paths are covered. This was a focused review, not a full app audit.

## Validation evidence

Results below describe this authoring session, not CI or release certification.

| Check | Result and limits |
| --- | --- |
| Skill frontmatter and scaffold validation | Both skills passed the bundled `quick_validate.py` validator |
| Local Markdown links and repository paths | Six relative guidance links and the README entry resolved; no unfinished scaffold markers |
| Native API type-check | Passed with Swift 5 language mode and an arm64 macOS 14 deployment target: Observation, State, Bindable, NSHostingView, and MenuBarExtra window style |
| Codable behavior probe | Passed: file round trip, persisted empty collection, and corrupt-input rejection; this does not test Clipper's save queue or clear action |
| Clipper Xcode tests | Blocked before compilation: installed Xcode requires license acceptance |
| Desktop interaction, minimum-OS runtime, Intel, and distribution checks | Not run; no claims of coverage |
| Framework performance comparison | Qualitative documentation comparison only; no benchmarks |

The Xcode attempt used Xcode 27.2 through a per-command `DEVELOPER_DIR`. The host
was Apple silicon running macOS 26.6.2, with Command Line Tools Swift 6.3.3. The
project declares `SWIFT_VERSION = 5.9`; an isolated probe using Swift 5 language
mode does not validate that Xcode project configuration or its entire build.

After the machine owner has reviewed and accepted the Xcode license, rerun from
the repository root:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Clipper.xcodeproj -scheme Clipper \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath /tmp/clipper-macos-skills-validation \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES test
```

Manual decision checks were also used while writing the skills:

| Scenario | Decision supported by the guidance |
| --- | --- |
| Add one preference | Existing settings plus a native control; no new architecture |
| Fix popup focus | Inspect the existing window controller; verify cross-app behavior |
| Add complex relationships and filtered persistence queries | Compare a database with whole-file storage and plan migration |
| Support an older macOS deployment target | Check API availability and preserve compatible observation APIs |
| Release the current ad-hoc-signed app | Separate CI success from Developer ID, notarization, and Gatekeeper checks |

These are author-reviewed scenarios, not independent agent evaluations. Revisit
the guidance when real usage reveals a wrong decision; prefer a narrow correction
over accumulating blanket rules.
