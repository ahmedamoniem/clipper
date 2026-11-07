# macOS implementation decisions

Research checked on 2026-11-07. Recheck API availability against the project's
deployment target and SDK when adopting a recommendation. These are qualitative
engineering comparisons; no framework performance benchmarks were run.

## UI and platform choice

| Approach | Useful when | Complexity to account for | Default decision |
| --- | --- | --- | --- |
| SwiftUI scenes and controls | A new native app fits the scene and control APIs | State lifetime, focus, API availability | Start here for a new native app |
| SwiftUI with small AppKit bridges | Specific desktop behavior needs lower-level control | Synchronizing state, ownership, responder chain, teardown | Add only the bridge the behavior needs |
| AppKit UI | Existing AppKit code or demanding window, document, or responder behavior | More imperative UI and lifecycle code | Keep it when it already fits |
| Electron | Existing web UI and team experience make cross-platform reuse valuable | Chromium/Node process boundaries, IPC, runtime updates | Evaluate for a real cross-platform requirement |
| Tauri | A web UI and Rust/backend expertise fit the product | Webview differences, Rust/web IPC, permissions and plugins | Evaluate when reuse offsets the extra toolchains |

Apple supports hosting SwiftUI in AppKit and wrapping AppKit views in SwiftUI;
neither requires a wholesale rewrite. See [AppKit integration](https://developer.apple.com/documentation/swiftui/appkit-integration).
For simple utilities, [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
offers a native menu bar scene, including a window style. Prototype required focus
and hotkey behavior before replacing an existing status-item implementation.

Electron uses main and renderer processes and a preload bridge; Tauri combines
Rust with a system webview and message passing. These documented boundaries inform
the complexity comparison, not a claim that one is always faster or smaller in
practice. Sources: [Electron process model](https://www.electronjs.org/docs/latest/tutorial/process-model),
[Tauri architecture](https://v2.tauri.app/concept/architecture/).

## State and architecture

Start with view state and a concrete feature model. Use one shared owner rather
than independently initialized copies of shared state. [Apple's Observation guide](https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app)
documents SwiftUI support from macOS 14 and how `@State` owns observable models.
Observation tracks changes; it does not provide actor isolation or persistence.

| Proposed addition | Evidence that can justify it | Simpler first option |
| --- | --- | --- |
| View model | Presentation transformations or workflows obscure the view | Extract the specific logic into a concrete model or function |
| Protocol | Multiple implementations or a difficult I/O boundary need substitution | Inject a concrete dependency, URL, clock, or closure |
| State framework | Cross-feature coordination is repeatedly inconsistent | Explicit state ownership and ordinary methods |
| Local package | Code is reused, independently built, or needs an enforced boundary | Folders in the current target |
| Third-party library | A maintained implementation saves meaningful work on a real requirement | System framework or a small local implementation |

These are project heuristics. Explain the current problem an abstraction solves;
do not impose a file count, layer count, or blanket ban on dependencies.

## Persistence

| Choice | Good fit | Cost or reason to move on |
| --- | --- | --- |
| UserDefaults / @AppStorage | Nonsensitive preferences | Unsuitable for secrets or a growing content collection |
| Codable file in Application Support | A bounded collection read and written as a whole | Whole-file I/O; own schema compatibility and serialized writes |
| SwiftData | Model relationships, queries, SwiftUI integration on supported OS versions | Schema/migration and model-context behavior to learn and test |
| Core Data or SQLite | Existing investment or specific store/query requirements | More persistence machinery; adopt for demonstrated needs |

Apple describes [UserDefaults](https://developer.apple.com/documentation/foundation/userdefaults)
as a store for nonsensitive settings. [SwiftData's persistence guide](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches)
covers models, relationships, and storage configurations. The recommendation to
start a bounded collection with Codable is a simplicity judgment.

For files, serialize writes and use atomic replacement; atomic replacement alone
does not stop an older queued snapshot overwriting a newer one. Handle missing,
corrupt, and older data separately; preserve recoverable content when appropriate.
A clear action must reach disk, and pending saves must not resurrect deleted data.
Use a temporary URL or in-memory store in tests. Add indexes, caches, or a database
when measurements or required queries justify them, without an arbitrary row limit.

## Concurrency and native experience

Begin with explicit ownership and the required actor isolation. Keep blocking I/O
and expensive computation away from UI execution when they would harm responsiveness.
Use an actor or serial queue for shared background state, not both by default.
Cancellation of queued work is not proof it can no longer write.

Check compiler version, language mode, default actor isolation, and upcoming
features separately. A newer compiler does not imply Swift 6 language mode.
Migrate concurrency checking incrementally rather than bundling it into an
unrelated feature. See [Swift's migration guide](https://www.swift.org/migration/documentation/migrationguide/)
and [incremental adoption](https://www.swift.org/migration/documentation/swift-6-concurrency-migration-guide/incrementaladoption/).

Use [Apple's macOS design guidance](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos)
to check menu commands, keyboard use, window behavior, and transitions between
apps. Measure the workload that matters before adding caching, background workers,
or a custom rendering system.
