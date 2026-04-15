# Validation tree

This tree is the **audit trail** for `apple-platform-guide`, not the primary
deliverable. The primary deliverables are the component usage docs in
`../components/*.md` and the foundations in `../foundations/*.md`. The files in
here exist so that every claim in a component doc can be traced back to four
rendered screenshots (macOS light/dark + iOS light/dark) and a prose verdict
that cites concrete visual attributes in both appearances.

## Acceptance bar (beauty-by-default)

A slug reaches `PASS` only when all five conditions hold:

1. **Four fresh screenshots.** `<slug>-macos-light.png`, `<slug>-macos-dark.png`,
   `<slug>-ios-light.png`, `<slug>-ios-dark.png` — each captured in the current
   iteration, each > 10 KB, each non-black.
2. **Liquid Glass on every surface capture.** Surface components (sheets,
   alerts, popovers, menus, sidebars, toolbars, nav bars, tab bars, activity
   views) must show translucent material with backdrop visibility in all four
   captures. A solid opaque fill anywhere is `NEEDS_WORK`.
3. **Legibility verified in both appearances.** Text contrast, separator
   visibility, role-color distinguishability — checked independently in light
   and dark. An impairment in either appearance is `NEEDS_WORK`.
4. **Component doc carries both mandatory sections.** `components/<slug>.md`
   must include a "Light / dark appearance notes" section and a
   "Customization / brand override" section. Missing either means
   `docs_written: false`.
5. **Evidence chain is current.** `audit_evidence.py` must pass for the slug:
   the report links all four appearance-specific screenshots, no screenshot is
   newer than the report that evaluates it, and the evidence manifest records
   SHA256 hashes, mtimes, byte sizes, and pixel dimensions for the current PNGs.

`PASS_WITH_NOTES` is reserved for at most one minor, documented, non-
legibility-impairing deviation. Do not use it as a dumping ground. Stale
screenshots, missing captures, clipped primary content, debug labels, visible
letterboxing, and absent Liquid Glass on a glass-required surface are not notes;
they are `INSUFFICIENT_EVIDENCE` or `NEEDS_WORK`.

See `.claude/agents/apple-platform-designer/agent.md` for the full
per-iteration playbook and the strict report / component-doc templates.

## Layout

```
validation/
  worklist.json       Ralph-loop state machine (one row per HIG component page)
  screenshots/        <slug>-{macos,ios}-{light,dark}.png per validated slug
  evidence/           <slug>.json screenshot/report hashes and freshness checks
  reports/            <slug>.md — HIG ref + 4 screenshots + verdict + citations
  gaps.md             Slugs the loop could not validate, queued for human review
  progress.log.md     Iteration-by-iteration ledger
  index.html          Generated dashboard (python3 /tmp/build_hig_index.py)
  README.md           This file
```

## Evidence audit

Run the audit before asking design-critic to review a slug and again after
writing the report:

```bash
python3 .claude/skills/apple-platform-guide/validation/audit_evidence.py \
  --slug <slug> --write-manifest
```

Run the whole dashboard audit:

```bash
python3 .claude/skills/apple-platform-guide/validation/audit_evidence.py
```

The script exits nonzero when any pass/pass_with_notes component row is invalid.
Use `--requeue-invalid` only when intentionally resetting those rows to
`pending`; it writes `worklist.json`.

## How to read a report

Each file in `reports/<slug>.md` has this structure (see `agent.md` for the
strict verbatim template):

```markdown
---
slug: popovers
verdict: PASS_WITH_NOTES
validated_at: 2026-04-12T21:50:00Z
iteration: 3
verdict_per_appearance:
  macos_light: PASS
  macos_dark:  PASS_WITH_NOTES
  ios_light:   PASS
  ios_dark:    PASS_WITH_NOTES
---

# <slug> — Visual validation

## HIG reference
![HIG ref](../../../apple-hig/images/<slug>-intro.png)

## Rendered — macOS (light)
![macOS light](../screenshots/<slug>-macos-light.png)

## Rendered — macOS (dark)
![macOS dark](../screenshots/<slug>-macos-dark.png)

## Rendered — iOS (light)
![iOS light](../screenshots/<slug>-ios-light.png)

## Rendered — iOS (dark)
![iOS dark](../screenshots/<slug>-ios-dark.png)

## Verdict: PASS_WITH_NOTES

### Evidence manifest
- Manifest path, screenshot hashes, and freshness result

### Liquid Glass check
- Required for this slug: yes (HIG Presentation / overlay)
- Observed: ... material in all four captures

### Light appearance observations
- <prose>

### Dark appearance observations
- <prose>

### Deviations
- <prose, each deviation sourced to a code line>

### Source citations
- HIG "<Component> — Best practices": <quoted guidance>

### Remediation (if NEEDS_WORK)
<prose, or "N/A — notes only">
```

Read a report when: (a) a component doc's claim looks off, (b) you're doing a
second-pass review of a slug, or (c) you want to see the exact HIG guidance the
agent was citing when it made a design call.

## Re-queuing a slug

When a `UI::View` changes or its HIG page is updated and you want the loop to
re-validate:

1. Open `worklist.json`.
2. Find the row for the slug.
3. Set `validation_state` back to `"pending"`.
4. Optionally set `docs_written: false` to force the component doc to be
   regenerated too (default behavior: docs are only regenerated if the old
   verdict was `NEEDS_WORK` or if the usage doc is missing).
5. Re-run the Ralph loop — it will pick up the pending row on the next pass.

Old screenshots and reports are overwritten. Historical versions live in git.

## Why VLM judgment, not pixel-diff

HIG illustrations in `apple-hig/images/` are stylized renders — many are
tinted, gridded, or abstracted rather than photographically accurate. A
pixel-perfect diff against them would produce false negatives on every row.
Instead, Claude compares the three images (HIG ref, macOS screenshot, iOS
screenshot) and writes a prose verdict citing specific attributes: material
symbol, corner-radius estimate in pt, hit-target dimensions, typography weight
and size, spacing in pt, color token used. The verdict is qualitative but
grounded in HIG-citable attributes — not "looks fine."

## Regenerating the worklist

The worklist is generated, not hand-edited. To regenerate (e.g. after adding
HIG pages or new `UI::View` files):

```bash
python3 ../../apple-hig/_build/triage.py
```

The script walks `../../apple-hig/pages/*.md`, classifies each as
`component | pattern | platform-guide | foundation`, cross-references against
`src/ui/views/*.cr`, and emits one row per component with priority and mapping
metadata. Non-component pages don't go in the worklist — they stay in the HIG
corpus only.
