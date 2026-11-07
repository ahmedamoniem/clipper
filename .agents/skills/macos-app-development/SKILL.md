---
name: macos-app-development
description: Build or change native macOS desktop apps with SwiftUI and AppKit, choosing the smallest design that meets the feature. Use for implementation and architecture decisions; preserve an existing nonnative stack unless a migration is requested.
---

# Develop a macOS app

Inspect repository instructions, the deployment target, compiler and language mode,
app lifecycle, dependencies, and current tests before choosing APIs. Define the
observable user behavior and its acceptance checks. Keep an existing working
design unless a concrete requirement makes it inadequate.

## Choose the smallest implementation

- For a new native app, start with SwiftUI scenes and standard controls. Add an
  AppKit bridge for a specific missing capability, such as precise window/focus
  behavior. Preserve an AppKit app rather than rewriting it to follow this default.
- For menu bar utilities, evaluate `MenuBarExtra` first. Use `NSStatusItem` and a
  window controller when the required activation, anchoring, or dismissal behavior
  warrants it. Verify focus in the real desktop environment.
- Keep view-local state local. Give shared feature data one owner and pass it to
  consumers. On macOS 14+, consider `@Observable`; use `@State` for SwiftUI-owned
  instances and `@Bindable` where bindings are needed. Preserve `ObservableObject`
  where older targets or existing code justify it.
- A view plus a concrete model/service is often sufficient. Add a view model,
  protocol, package, dependency container, or state framework only when it removes
  demonstrated duplication, isolates a real external boundary, or makes behavior
  substantially easier to test. Constructor injection does not require a container.
- Use nonsensitive preferences in `UserDefaults`/`@AppStorage`, small bounded data
  in Codable files, and a database when queries, relationships, or measured data
  volume justify it. Keep credentials in Keychain. Plan compatibility before
  changing persisted formats.

Read [the decision guide](references/decisions.md) when comparing frameworks,
storage, architecture, or concurrency. Its defaults are engineering judgments,
not requirements imposed by Apple.

## Implement desktop behavior deliberately

Keep UI state and AppKit operations in their required isolation, typically
`@MainActor`. An `async` function or `Task` is not proof that expensive work leaves
the main actor. Move blocking work across an explicit boundary when necessary;
pass value snapshots and preserve write ordering. Give timers, event monitors,
observers, and tasks an owner and cleanup/cancellation path.

Use native menus, standard shortcuts, accessible names, and predictable focus.
Check keyboard-only operation, Escape dismissal, appearance, and relevant window
sizes. For utilities, opening and closing a popup must not unexpectedly redirect
input to another app.

Request protected capabilities when the user enables the dependent feature.
Handle denial and revocation with a useful fallback. Treat clipboard contents as
sensitive: avoid logging payloads, keep retention bounded, and make deletion
persistent. Local JSON is unencrypted; it is not a privacy guarantee.

## Validate and report

Run the repository's relevant build and tests, then exercise affected desktop
behavior. For a workflow, use this order: reproduce, make a focused change, run
targeted checks, and summarize behavior, tradeoffs, and remaining limitations.
Distinguish checks that passed from checks that were blocked or only reviewed.
For detailed test or release work, use the separate macos-app-validation skill if
available; this skill remains usable on its own.
