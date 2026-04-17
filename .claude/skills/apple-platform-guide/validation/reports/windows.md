---
slug: windows
verdict: SKIPPED
validated_at: 2026-04-17T00:00:00Z
iteration: 1
verdict_per_appearance:
  macos_light: "n/a (window chrome)"
  macos_dark:  "n/a (window chrome)"
  ios_light:   "n/a (window chrome)"
  ios_dark:    "n/a (window chrome)"
---

# Windows -- Validation note

## HIG reference
![HIG ref](../../../apple-hig/images/components-window-intro.png)

## Verdict: SKIPPED

`UI::Windows` is a configuration service for top-level shell intent, not a
drawable in-app component. The HIG windows family is window chrome managed by
`NSWindow` / `UIWindow`, so screenshot validation is not the right proof shape
for this row.

### What is implemented

- top-level window title
- optional subtitle
- preferred, minimum, and maximum sizing
- titlebar style intent for macOS
- toolbar / full-screen / resizable flags for host integration

### Why validation stays skipped

The shard does not own the actual OS window chrome yet, and it should not fake
that ownership with a pretend card. The correct bridge work still belongs in
the host layer, so this row stays `window-chrome-not-view` until the native
shell integration lands.
