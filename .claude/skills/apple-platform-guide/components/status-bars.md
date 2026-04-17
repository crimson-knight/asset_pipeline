---
slug: status-bars
ui_view: UI::StatusBar
priority: P2
platforms: [macOS]
hig_page: ../../../apple-hig/pages/status-bars.md
validation_report: ../validation/reports/status-bars.md
---

# UI::StatusBar

> A small shell model for a macOS status item and its attached menu. The
> actual `NSStatusItem` chrome still belongs to the OS shell; this type keeps
> the item's title, icon, tooltip, and menu intent in Crystal until the bridge
> lands.

## Feel of the flow

Status items are tiny and deliberate. They belong in the shell, not in the
main content hierarchy, and they should do one job clearly: expose a compact
menu or a small amount of always-available app state.

`UI::StatusBar` keeps that intent simple. It describes a single status item
with an optional menu, an icon or title, and a tooltip.

## Quickstart

```crystal
status_item = UI::StatusBar.new(
  identifier: "sync",
  title: "Sync",
  icon: "arrow.triangle.2.circlepath",
  tooltip: "Sync status"
)

status_item.with_menu do |menu|
  menu.add_item("Pause Sync")
  menu.add_item("Open Activity")
  menu.add_item("Quit", icon: "xmark")
end

status_item.install
```

## Customization

| Knob | Type | Default | Effect |
|------|------|---------|--------|
| `identifier` | `String` | `"status-item"` | Stable identifier for the item. |
| `title` | `String?` | `nil` | Optional text label for the item. |
| `icon` | `String?` | `nil` | Optional SF Symbol name for the status item's icon. |
| `tooltip` | `String?` | `nil` | Optional hover text. |
| `menu` | `UI::ContextMenu?` | `nil` | Optional attached menu. |
| `is_template_icon` | `Bool` | `true` | Whether the icon should be treated as a template image. |
| `is_visible` | `Bool` | `true` | Whether the item is conceptually visible. |
| `is_installed` | `Bool` | `false` | Local state flag for whether the model has been installed. |

## What happens on each platform

- **macOS**: The native bridge will later turn this into an `NSStatusItem`
  with an attached `NSMenu`.
- **iOS**: The iPhone status bar is system-controlled and not modeled here.
- **Validation**: Skipped for screenshots because the status item belongs to
  the OS shell, not the in-app view tree.

## HIG citations (validated)

- Keep status-item surfaces compact and focused.
- Use status items for lightweight shell access, not full application chrome.

