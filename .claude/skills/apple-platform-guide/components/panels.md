---
slug: panels
ui_view: UI::Panel
priority: P1
platforms: [macOS, iPadOS, iOS]
hig_page: ../../../apple-hig/pages/panels.md
validation_report: ../validation/reports/panels.md
---

# UI::Panel

> An auxiliary surface for inspector controls, contextual settings, or focused
> secondary detail. The default taste should feel disciplined and supportive:
> clear title hierarchy, calm spacing, and obvious separation from the main
> work area.

## Feel of the flow

Apple's HIG panels are primarily a macOS windowing concept: floating utility
surfaces like inspectors, libraries, and secondary controls that support the
main document without replacing it. `UI::Panel` is the shard's honest shared
expression of that idea for now.

That means this primitive is intentionally not pretending to be `NSPanel`
already. Instead it models the anatomy we need across platforms today:
headline, supporting copy, body content, and a restrained footer/action area.
The important part is the relationship to the main task. A good panel feels
adjacent and useful, not like a full-screen destination wearing smaller clothes.

## Quickstart

```crystal
content = UI::VStack.new(spacing: 12.0, alignment: UI::Alignment::Fill)
content << UI::Toggle.new("Snap to grid", true).as(UI::View)
content << UI::Slider.new(12.0, 0.0, 24.0).as(UI::View)

panel = UI::Panel.new(
  "Inspector",
  content.as(UI::View),
  "Layout",
  "Changes apply to the selected canvas item."
)
panel.add_action(UI::Button.new("Done", style: UI::ButtonStyle::Prominent))
panel.accessibility_label = "Layout inspector"
```

## Customization

| Knob | Type | Default | Effect |
|------|------|---------|--------|
| `title` | `String` | required | Primary heading for the panel surface. |
| `subtitle` | `String?` | `nil` | Optional secondary heading under the title. |
| `auxiliary_text` | `String?` | `nil` | Low-emphasis explanatory copy under the subtitle. |
| `content` | `UI::View?` | `nil` | Main body content for controls or detail. |
| `footer` | `UI::View?` | `nil` | Optional footer content above the action row. |
| `actions` | `Array(UI::Button)` | `[]` | Trailing action buttons shown in the footer area. |
| `preferred_width` | `Float64` | `320.0` | Target width for the fallback panel card. |
| `body_spacing` | `Float64` | `14.0` | Vertical rhythm between header, content, and footer blocks. |
| `action_spacing` | `Float64` | `8.0` | Gap between footer buttons. |
| `style` | `UI::PanelStyle` | `Inspector` | Chooses between `Standard`, `Inspector`, and `Compact` chrome. |
| `shows_separators` | `Bool` | `true` | Whether header/body/footer sections get divider lines. |

## Light / dark appearance notes

Panels should not fight for attention with the main canvas. In both light and
dark appearances, the surface needs to read as a supporting plane with stable
spacing and quiet separators. Strong color usually belongs inside the controls,
not in the panel chrome itself. The title block should anchor the eye quickly,
while the footer stays orderly rather than button-heavy.

## What happens on each platform

- **macOS 26**: Today this is a composed in-app panel surface, not a true
  floating `NSPanel` bridge yet.
- **iPadOS 26 / iOS 26**: Rendered as the same shared auxiliary surface, which
  is useful for inspectors and focused side controls even where the platform
  does not expose a direct panel peer.

## HIG citations (validated)

- Panels support the main task instead of replacing it.
- They work best when they stay focused on a narrow set of related controls or
  details.

Validation report:
[validation/reports/panels.md](../validation/reports/panels.md)

## Related

- `UI::Popover` for transient anchored surfaces.
- `UI::Sheet` for modal secondary tasks.
- `UI::Card` for inline grouped content that does not need panel semantics.
