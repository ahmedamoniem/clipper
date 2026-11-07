---
name: macos-app-validation
description: Validate or review a macOS desktop app change with proportionate build, behavior, performance, and distribution checks. Use for testing, simplicity reviews, and release readiness; report evidence without publishing or altering system permissions.
---

# Validate a macOS app change

Inspect repository instructions, the diff, supported macOS versions, scheme and
test targets, CI, and distribution channel. Identify what changed for the user
and select checks that can disprove the proposed behavior. Do not introduce a
testing framework or release pipeline just to run a review.

Read [the validation guide](references/validation.md) for command patterns,
desktop checks, and distribution requirements. Adapt example names and paths to
the repository; do not assume it uses Xcode rather than SwiftPM.

## Validate in proportion to the change

- Documentation and skill changes: check references, commands, frontmatter, and
  realistic decision scenarios. An app build is optional unless guidance depends
  on compiler or SDK behavior.
- Logic or persistence changes: build and run focused tests for the contract,
  including relevant boundary/failure cases. Isolate preferences, files, time,
  and external apps so tests do not depend on or mutate a user's real history.
- UI, focus, hotkey, and permission changes: add targeted desktop verification.
  Pure unit tests cannot prove responder-chain or cross-app behavior.
- Performance changes: compare the same workload and build configuration before
  and after. Record OS, hardware, sample size, and observations. Avoid numerical
  claims without measurements.
- Distribution changes: inspect the final packaged artifact and the actual
  signing/notarization path. A successful unsigned CI build is insufficient.

Use existing XCTest or Swift Testing conventions. Add tests for meaningful
behavior rather than assertions about implementation shape. Re-run or broaden
checks when a failure, new change, or unresolved concern calls for it.

## Review simplicity

For a new layer, dependency, cache, worker, or persistence system, identify the
specific requirement or measured issue it addresses. Compare it with the smallest
working alternative and account for lifetime, failure handling, migration, and
maintenance. Recommend a concrete simplification when benefits do not cover cost.
Preserve existing abstractions when removing them would expand the task without
improving the requested behavior.

## Return evidence

Report actionable findings with file/line references and a reproducible trigger,
then state the relevant commands and observed results. Separate failures in the
change from environment blockers and checks not run. Passing tests do not establish
unmeasured performance or untested OS/architecture support. A source review, API
type-check, manual smoke test, and release validation are different evidence.

If Xcode is unavailable, unlicensed, or incompatible, record the blocker and
provide the exact rerun command. A per-command `DEVELOPER_DIR` can select an
installed Xcode without changing global configuration. Do not accept licenses,
grant Accessibility permission, or submit releases as part of a validation task.
