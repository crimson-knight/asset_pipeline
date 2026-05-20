# Phase 7 — Accessibility & Visual Verification Automation

**Tier:** Infrastructure
**Depends on:** Phase 6 (demo app must exist to baseline)
**Blocks:** Initiative sign-off
**Estimated remediation budget:** 1 loop

---

## Why this phase exists

By this point, phases 1–6 have built a real cross-platform demo. But without an automated way to *prove* it stays correct over time, the next change to a renderer could silently regress glass appearance or push a button off-screen at 375px without anyone noticing until a human spots it.

This phase establishes the automated verification floor:

- **Visual regression** for the demo app at every screen × platform × viewport × scheme combination.
- **Accessibility audits** per platform: axe-core + IBM Equal Access for web, XCUITest/AXTest for native.
- **CI gate** so the audits and visual diffs run on every PR to the initiative branch.

After this phase, the initiative is shippable.

## Scope summary

In scope:

- Visual regression infrastructure:
  - Baseline screenshots for every demo screen × platform × viewport × color scheme captured and committed under `test-results/initiative-demo-baselines/`.
  - A `scripts/diff_demo_screenshots.cr` (or extension of existing audit scripts) that:
    - Re-captures screenshots
    - Diffs each against baseline using a pixel-tolerance algorithm (e.g., 1% pixel difference threshold)
    - Reports failures with side-by-side images
- Accessibility audits:
  - Web: extend `scripts/axe_web_demo_audit.cr` and `scripts/ibm_web_demo_audit.cr` to cover the initiative demo pages.
  - iOS: a test target in the iOS sample app that runs XCUITest accessibility checks against the demo screens (focus order, accessibility labels present, dynamic type respected).
  - macOS: an `AXUIElement` walk of the demo screens verifying every interactive element has an accessibility role + label.
- CI configuration:
  - GitHub Actions workflow (or extension of existing) that runs on PRs to `feature/utility-first-css-asset-pipeline`:
    - Build the demo on web, macOS, iOS
    - Run visual regression
    - Run accessibility audits
    - Fail the check if any audit reports a violation (configurable severity threshold)
- Documentation:
  - `docs/initiative-cross-platform-ui/verification-runbook.md` explaining how to update baselines after an intentional visual change.
  - Update `CLAUDE.md` to point future agents at the verification runbook.

Out of scope:

- Performance regression testing (FPS, render time). Possible future phase.
- User testing / qualitative research. This phase is about machine-checkable invariants.
- Fixing audit failures discovered during baselining — those become bugs to fix, but the bug fixing itself is not phase 7 work. Phase 7 establishes the floor; the work of staying above the floor is permanent.

## Acceptance summary

Phase 7 is done when:

- Visual regression baselines are committed for every demo screen × platform × viewport × scheme combination.
- The diff script runs cleanly: zero diffs immediately after baseline (sanity check).
- Web accessibility audits (axe + IBM EA) produce zero violations at level "serious" or higher on the demo pages, or every remaining violation is documented in the runbook with a justification and disposition.
- iOS XCUITest accessibility checks pass.
- macOS AXUIElement walk passes.
- CI workflow is set up and a test PR demonstrates that:
  - Introducing a visual regression fails the check.
  - Introducing an accessibility violation fails the check.
- The verification runbook documents the steps to refresh baselines, run audits locally, and interpret CI failures.

Detailed checks in `validation.md`.

## Risk notes

- **Pixel-diff false positives.** Anti-aliasing, font hinting, and subpixel rendering vary across CI machines. The tolerance threshold must be tuned. Validator should explicitly check that re-running the baseline twice produces zero diffs.
- **iOS simulator screenshot determinism.** The simulator must be at a fixed device + iOS version. Pin in the build script.
- **macOS resizable window captures.** The `.app` must be launched at a deterministic window size for baselining. Make this scripted, not interactive.
- **CI runtime cost.** Building three platform targets per PR may be slow. Budget for it; the alternative (no CI gate) is worse.
- **Existing audit infrastructure** is solid (`scripts/validate_web_demo.cr`, axe, IBM EA). Extend it; do not rewrite from scratch.

## Briefing documents

- Implementer: `implementation.md`
- Validator: `validation.md`
- Universal: `../../rubric/implementation_criteria.md`, `../../rubric/validation_criteria.md`
