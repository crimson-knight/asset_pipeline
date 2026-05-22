# Master Plan — Cross-Platform UI Initiative

**Status:** Planning complete, ready for execution
**Initiative branch:** `feature/utility-first-css-asset-pipeline` (the merge target; each phase merges back here when its validator passes)
**Phase branches:** `phase-{NN}-{slug}` per phase (created by the Architect before each Team Lead dispatch; see "Branching Discipline" below)
**Date initiated:** 2026-05-20
**Roles:** **Architect** (oversees the entire initiative, dispatches per-phase Team Leads) → **Team Lead** (orchestrates one phase, dispatches Implementer + Validator) → **Implementer** + **Validator** (trust pair, never communicate with each other).

> **Read `origin.md` before reading the rest of this document.** It preserves the verbatim prompts from the project owner that shaped every load-bearing decision below. When a phase's formal docs are silent on an ambiguity, the origin is where the spirit of the work lives.

---

## North Star

A single Crystal source defines a demo app. It builds to **desktop web**, **mobile web**, **iOS native**, and **macOS native**. Looking at all four side-by-side, a reasonable observer can:

1. **Identify them as the same brand** — colors, type scale, spacing, radii, motion all read as a unified product.
2. **See the platform speaking its own language** — Apple platforms use SwiftUI defaults (system fonts, glass surfaces, action sheets, haptics); web uses browser-native semantics; behavior fluidly adapts when the macOS window or web viewport is resized between desktop and mobile widths.
3. **Verify accessibility** — every interactive element meets WCAG 2.2 AA on web and the platform equivalent on native (AXUIElement, XCUITest accessibility identifiers).

The Crystal API for the demo author looks the same on every platform. The library does the platform-tailoring underneath, with explicit opt-in for genuinely platform-only widgets.

---

## What This Plan Is

This document is the **team lead's working ledger**. It is the only document the team lead needs to read in full to understand:

- Where the work is in the overall sequence
- What phase is currently active
- Which agent (implementer or validator) should be spawned next
- What "done" means for each phase
- Where to find the detailed brief for each phase

The team lead **does not** execute implementation work directly. The team lead **delegates** to a trust pair (implementer + validator) per phase. See `rubric/trust_pair_protocol.md`.

---

## What This Plan Is Not

- Not a feature backlog. Backlog work lives in GitHub issues.
- Not a detailed implementation document. Each phase has its own `implementation.md` (briefing for the implementer agent) and `validation.md` (rubric for the validator agent).
- Not a Gantt chart. Phases are sequenced by dependency, not by date.

---

## Tier model (foundational concept)

Every widget and visual behavior in the library belongs to one of three tiers. This vocabulary is used throughout the plan and in every phase.

| Tier | Definition | Cascades to | Examples |
|---|---|---|---|
| **Tier 1 — Brand** | Universal design language: colors, spacing, type scale, border radius, motion, breakpoints. | All four platforms identically (within platform unit conventions). | Brand primary color, 4-pt spacing grid, semibold body text, 6 px button radius |
| **Tier 2 — Platform Default** | Visual treatment that comes from the platform's idiomatic UI library when the developer has not customized. | The platform's native styling (SwiftUI on Apple, browser-native on web, Material on Android). Overrides cascade from Tier 1 when developer customizes. | Default button hover (web :hover), default toggle animation (SwiftUI), glass surface (iOS 26+), system font fallback |
| **Tier 3 — Platform-Only Widget** | A widget that only exists on certain platforms and requires explicit opt-in. Using it on an unsupported platform is a compile-time error unless an explicit fallback is wired. | Native implementation on supported platform. Optional documented fallback on others. | `ActionSheet` (iOS), `ContextMenu` (macOS/iOS), `HapticFeedback` (iOS), platform notifications |

**Rule of thumb:** A demo screen written against the public API should compile and look correct on every supported platform **without** the author touching Tier 2 or Tier 3 concerns. The author writes against Tier 1; Tier 2 happens for free; Tier 3 is reached for intentionally.

---

## Branching discipline

Each phase gets its own working branch, cut from the latest commit of `feature/utility-first-css-asset-pipeline`. The Architect creates the phase branch **before** dispatching the Team Lead and merges it back **after** the validator passes. The Implementer and Validator both operate on the phase branch; they do not see or interact with the initiative branch directly.

Phase branch naming: `phase-{NN}-{slug}` where `NN` is the two-digit phase number and `slug` matches the phase folder. Examples:

- `phase-01-design-token-foundation`
- `phase-02-responsive-web-fluid-resize`
- `phase-03-swiftui-native-bridge`

Architect's per-phase git rhythm:

1. **Before dispatch:**
   ```
   git checkout feature/utility-first-css-asset-pipeline
   git pull --ff-only origin feature/utility-first-css-asset-pipeline   # if remote exists
   git checkout -b phase-{NN}-{slug}
   ```
2. **Team Lead dispatched.** Implementer commits incrementally on this branch; Validator runs against the same branch.
3. **On a passing GATE_REPORT:**
   ```
   git checkout feature/utility-first-css-asset-pipeline
   git merge --ff-only phase-{NN}-{slug}
   git tag phase-{NN}-passed-{YYYY-MM-DD}
   git branch -d phase-{NN}-{slug}    # optional
   ```
4. Update the progress ledger to `Passed`. Archive the gate report under `handoff/`. Write a reflection note (`handoff/phase-{NN}-reflection-{date}.md`).
5. **Checkpoint with the project owner before creating the next phase's branch.** Phase transitions are deliberate, not autopilot.

**Forbidden:** force-push, `rebase --interactive` rewriting already-handed-off history, deleting the initiative branch, deleting passed-phase tags, branching off anything other than the latest passed state of the initiative branch. If a passed phase needs correction, the correction is a forward commit on the current phase's branch — never a rewrite of history before the passed tag.

---

## Phase sequence

Phases are listed in dependency order. The team lead must complete validation gates in order; do not parallelize unless explicitly noted in the phase's README.

| # | Phase | Purpose | Folder |
|---|---|---|---|
| 1 | **Design Token Foundation** | Single source of truth for Tier 1: colors, spacing, type, radius, motion, breakpoints. Generators for web CSS, Apple Swift, Android resources. Brand override API. | `phases/phase-01-design-token-foundation/` |
| 2 | **Responsive Web Fluid Resize** | Replace pixel constraints with `clamp()`. Implement container queries. Mobile-first layout. Viewport meta. Touch-target minimums. | `phases/phase-02-responsive-web-fluid-resize/` |
| 3 | **SwiftUI Native Bridge** | Swift companion library exposing SwiftUI components via `@objc`. Crystal renderers use SwiftUI defaults; modifiers only when Crystal view declares overrides. | `phases/phase-03-swiftui-native-bridge/` |
| 4 | **Platform Tier Gating** | Formalize Tier 1/2/3. Add compile-time guards on Tier 3 widgets. Document and (where reasonable) provide web fallbacks for Tier 3. | `phases/phase-04-platform-tier-gating/` |
| 5 | **Glass Material Tokenization** | Promote glass material strength to design tokens. Wire all renderers (incl. RenderEffect on Android API 31+). Brand override of glass intensity. | `phases/phase-05-glass-material-tokenization/` |
| 6 | **Side-by-Side Demo App** | Single Crystal source. Builds web + iOS + macOS. Five representative screens. Screenshot harness for the four-up comparison page. | `phases/phase-06-side-by-side-demo-app/` |
| 7 | **Accessibility & Visual Verification Automation** | Visual regression baselines per screen × platform × viewport × scheme. Accessibility audits per platform. CI gate. | `phases/phase-07-accessibility-visual-verification/` |

### Why this order

- **Phase 1 is the foundation.** Every later phase reads from the token system.
- **Phase 2 can technically run in parallel with phase 3**, but the team lead should serialize them to keep validation evidence clean. If schedule pressure demands parallelization, document the decision in `handoff/` and run two separate validators.
- **Phase 3 (SwiftUI bridge) is the highest-risk phase.** A failed validation here means the entire native experience is wrong. Budget for at least one remediation loop.
- **Phase 4 depends on phase 3** because Tier 2 defaults can only be verified once SwiftUI is in place.
- **Phase 5 depends on phases 1 + 3** (tokens + SwiftUI surface).
- **Phase 6 depends on phases 1–5** for the experience to be representative. Earlier dry runs of the demo are fine but don't satisfy phase 6's validation criteria.
- **Phase 7 depends on phase 6** (cannot baseline screenshots of an incomplete app).

---

## Progress ledger

The team lead updates this table as work proceeds. Each row's `Status` is one of:

- `Not Started` — nothing dispatched
- `Implementer Active` — implementer agent currently working
- `Implementer Returned` — implementer reported done, validator not yet spawned
- `Validator Active` — validator running checklist
- `Failing` — validator returned failures; implementer needs to be re-spawned with the gate report
- `Passed` — all required checks pass; phase complete

| # | Phase | Status | Implementer commit(s) | Validator report | Notes |
|---|---|---|---|---|---|
| 1 | Design Token Foundation | **Passed (2026-05-20)** — tag `phase-01-passed-2026-05-20` | `5b6483b 40e396d 0e3b943 575613a 8ecd37d 006dc70 3874a4e 8b68717` + remediation `a84c6c3 4cefe9f 0988646` | `handoff/phase-01-passed-2026-05-20.md` (iter 2 PASS); `handoff/phase-01-failing-1-2026-05-20.md` (iter 1 FAIL → remediated); `handoff/phase-01-reflection-2026-05-20.md` (architect reflection) | Iter 2 verdict PASS: 19/20 required checks pass; 3 deferred per architect handoff; #20 iOS cascade blocked but Architect-adjudicated satisfied by #19 macOS pivot proof. Merged ff into `feature/utility-first-css-asset-pipeline`. Awaiting Seth checkpoint #3 before Phase 2 dispatch |
| 2 | Responsive Web Fluid Resize | **Passed (2026-05-20)** — tag `phase-02-passed-2026-05-20` | `e17f7b6 b8709ac a82ad02 a710f6b a6ebee4 93205f4 c185f01 44d003f 5a5b52c 36f74f9` + remediation `c735c47 12cf77f 5b996c3 a5beccc` | `handoff/phase-02-passed-2026-05-20.md` (iter 2 PASS); `handoff/phase-02-failing-1-2026-05-20.md` (iter 1 FAIL → remediated); `handoff/phase-02-reflection-2026-05-20.md` | Iter 2 verdict PASS: 25/25 required checks pass. Iter-1's 12 failures all closed by 4 remediation commits. Merged ff into `feature/utility-first-css-asset-pipeline`. Awaiting Seth checkpoint before Phase 3 dispatch |
| 3 | SwiftUI Native Bridge | **Passed (2026-05-21)** — tag `phase-03-passed-2026-05-21` | R1-2 (already listed); R3: `e754104 61e8663 1a77437 8007e8c 9a0bcfd 119004d`; R4: `bc2b246 133da34 92cf0ad 2105cc0 bb9b5d2 1701668 2a431e5`; R5: `a818e7d a1049ea`; R6: `21b1ddd`; R7: `7d0b0d5 90a2d54`; R8: `5fc9dbd 6955460 e351f62 0faf0f0 4f7da71 d352561 9e49083 9a7d78f f469fd0`; R9: `427c50b a2e56bb`; R10: `e3a26c1 376343a 8349809 bfd129d` | `handoff/phase-03-passed-2026-05-21.md` (iter 7 PASS); `handoff/phase-03-reflection-2026-05-21.md` (architect reflection); `handoff/phase-03-iter4-2026-05-21.md` + `phase-03-iter3-2026-05-21.md` + R3/R5 blockers + R8 investigation (failing iters); `handoff/phase-03-state-2026-05-21-codex-context.md` (Codex review framing) | Iter 7 verdict PASS: 49/49 required checks. All 3 load-bearing reactive invariants (BX1 button-tap, BX2 macOS, BX5 override-rerender) empirically proven on both macOS 26.5 + iPhone 17 Pro iOS 26.5. R3 authored 12 probe slugs + XCUITest + AXTest specs; R4 shipped reactive forward bridge; R5+R6 fixed iOS link + require leaks; R7 fixed AX-tree discoverability; R8 fixed 3 of 5 iOS bugs (sprintf, contentShape, frame); R9 fixed BX8 launch crash via class-init workaround + falsified R8 hypotheses with diagnostic-first protocol; R10 shipped UISwitch UIViewRepresentable for BX3 + full reactive Sheet bridge for BX8 (with Codex CLI brief-review + 4-checkpoint critique cycle). Merged ff into `feature/utility-first-css-asset-pipeline`. Phase 5+ inheritances: class-init systematic fix, Groups 4-5 widgets. Awaiting Seth checkpoint before Phase 4 dispatch |
| 4 | Platform Tier Gating | **Passed (2026-05-22)** — tag `phase-04-passed-2026-05-22` | Initial (10 atomic + 2 Codex follow-ups): `bfcb103 958b004 724ca7f 8df0242 cdee220 6da452f 5e27a12 49e48b1 a8db5d9 56dc514 2ce5da6 022dc11`; R1 (6 — test pages + CDP harness): `049da91 259a8d6 ae20a1b f97a57e 5895189 6c20a52`; R2 (2 — renderer accessibility fixes): `8192575 6180a14` | `handoff/phase-04-passed-2026-05-22.md` (iter 2 PASS); `handoff/phase-04-reflection-2026-05-22.md` (architect reflection); `handoff/phase-04-evidence-2026-05-21-iter1/` + `phase-04-evidence-2026-05-22-iter2/` (validator iterations); `handoff/phase-04-implementer-deviations.md`; `handoff/phase-04-r2-evidence-2026-05-22/` | Iter 2 verdict PASS: 31/31 required checks. All 3 Tier-3 gates produce exact compile-error format on wrong platform; all 3 *WithWebFallback siblings cross-compile everywhere. 12/12 CDP behavior probes empirically PASS (focus trap + escape + backdrop + positioning + touch targets + axe-core + IBM Equal Access for ActionSheet and ContextMenu; semantic structure for PathControl). Tier matrix complete (78 widgets: 17 Tier 1 / 55 Tier 2 / 3 Tier 3 gated + 3 fallback companions). Phase 3 regression check clean (iOS XCUITest 10/10, macOS AXTest 2/2, swift test 53/53, crystal spec baseline + 4 pre-existing failures). Codex CLI brief-review + 4-checkpoint critique cadence used throughout; R1 found 12 blocked behavior probes were latent test-coverage gaps; R2 fixed 2 real WCAG-AA renderer-source bugs the CDP harness exposed (color contrast --ap-color-brand-accent→--ap-color-brand-primary at web_renderer.cr:2721 + remove role="group" from action-sheet \<ul\> at web_renderer.cr:2589). Merged ff into `feature/utility-first-css-asset-pipeline`. Phase 5 inheritances: Crystal-iOS class-init systematic fix (carried from Phase 3), HapticFeedback widget (Phase 4 deferred). Awaiting Seth checkpoint before Phase 5 dispatch |
| 5 | Glass Material Tokenization | Not Started | — | — | |
| 6 | Side-by-Side Demo App | Not Started | — | — | |
| 7 | Accessibility & Visual Verification Automation | Not Started | — | — | |

---

## Team lead playbook (how to use this document)

1. **Read this MASTER_PLAN.md fully.** Then read `rubric/trust_pair_protocol.md`, `rubric/implementation_criteria.md`, and `rubric/validation_criteria.md`. Together these are about a 15-minute read; they are the entire surface area of how to do the job.
2. **Identify the next `Not Started` phase** in the progress ledger.
3. **Open that phase's folder** and read its `README.md`. The README orients you to the phase's scope, dependencies, and acceptance criteria. You do **not** need to read `implementation.md` or `validation.md` end-to-end; those are for the agents you spawn.
4. **Spawn the implementer agent** following the trust pair protocol. Pass `implementation.md` as the briefing.
5. **When the implementer returns**, update the ledger to `Implementer Returned`. Spawn the validator agent. Pass `validation.md` as the rubric.
6. **When the validator returns a passing GATE_REPORT**, update the ledger to `Passed`, archive the report under `handoff/phase-XX-passed-YYYY-MM-DD.md`, and move to the next phase.
7. **When the validator returns failures**, update the ledger to `Failing`, archive the report under `handoff/phase-XX-failing-N-YYYY-MM-DD.md`, and re-spawn the implementer with the gate report attached so they can remediate.

Hard rules for the team lead:

- **Never edit the phase folders' `implementation.md` or `validation.md`** without first capturing why in a handoff note. Those documents are contracts.
- **Never skip a validation gate** to "save time." A missed gate means the next phase is building on unverified ground.
- **Always update the progress ledger before context-switching.** The ledger is the only thing that survives a team-lead agent restart with full fidelity.

---

## Out of scope (explicit non-goals)

- Renaming the library or any of its public APIs.
- Migrating Android to Compose. Android remains View-based with Material 3.
- Building a SwiftUI-equivalent for Android or Web. SwiftUI is an Apple-only bridge.
- Replacing the existing `samples/cross_platform/` HIG validation studies. Those continue to serve as fine-grained per-component reference; the new demo app in phase 6 is a different artifact serving a different purpose (side-by-side brand verification, not per-component HIG conformance).
- Performance work. The plan assumes the rendering performance of the existing renderers is acceptable; performance regressions are bugs, not phase work.

---

## Related docs

- **`system-prompt.md`** — The concise identity / role / non-negotiables the project owner pastes as the Architect agent's system prompt. Persistent across every turn.
- **`start-architect.md`** — The operational first-turn protocol the Architect reads after the system prompt. Required reading order, per-phase git rhythm, bookkeeping rhythm, checkpoint moments, first actions.
- **`origin.md`** — **Read this FIRST.** Verbatim prompts from the project owner that shaped this plan; preserves the spirit when the formal docs go silent on an ambiguity.
- `rubric/trust_pair_protocol.md` — how the implementer + validator dance works
- `rubric/implementation_criteria.md` — universal implementer standards
- `rubric/validation_criteria.md` — universal validator standards (incl. presence/behavior/conformance taxonomy)
- `rubric/behavior-simulation-toolkit.md` — concrete recipes for driving real input on macOS / iOS / web; documents the shipped AXTest extensions A1–A7
- `rubric/gate_report_schema.md` — schema for validator reports
- `phases/phase-XX-*/README.md` — per-phase orientation
- `phases/phase-XX-*/implementation.md` — per-phase implementer briefing
- `phases/phase-XX-*/validation.md` — per-phase validator rubric
- `handoff/` — append-only log of all phase transitions and gate reports (incl. `plan-quality-audit-2026-05-20.md`, the audit that drove the first round of revisions)
