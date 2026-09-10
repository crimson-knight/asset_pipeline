# Android buttons (development contract)

`UI::Button` renders as a `MaterialButton`. Its `style` and `role` pick the
Material role colors (a prominent button is `primary` under `on_primary`, a
destructive one `error`, and so on), and that is the whole look of a button
that sets nothing else. A customer brand kit sets more: the QuiltPerfect
call to action is BERNINA red under white, its secondary buttons carry a
hairline in the brand's ink, and content buttons wrap their label. The
SwiftUI facade honors those on iOS; this page names what the Android
renderer reads so the same tree looks the same on both phones.

## What the renderer reads

| Attribute | Android | Rule |
|---|---|---|
| `background` | background tint | Applied when set; it replaces the style's role color. |
| `foreground_color` | text color | Applied unless it is the declared default (`r 0.0, g 0.478, b 1.0`, the iOS system blue), which means "unset" on both platforms. |
| `border_width`, `border_color` | stroke | A border becomes the MaterialButton stroke at the declared width in dp (rounded, at least 1); the color falls back to the foreground. Without a border the style keeps its own hairline (`outline` or `outline_variant`) or none. |
| `number_of_lines` | `setSingleLine`, `setMaxLines`, `setEllipsize` | `1` is a single line truncated with an ellipsis (the iOS call to action); `0` wraps without a cap; `n` caps the wrap and truncates the last line with an ellipsis, as UILabel does at `numberOfLines`. Android otherwise keeps the whole layout and clips it by height, so `lineCount` would report every line. `UI::Label` caps gained the same ellipsis. |
| `text_alignment` | gravity | `Leading` is `START`, `Trailing` is `END`, `Center` is the default, all vertically centered. iOS ignores this attribute on buttons and centers the label. |
| `font` | text size, typeface | As before: size in sp, a registered family by name (see `docs/android-assets.md`). |
| `corner_radius`, `padding`, `disabled`, `on_tap` | as before | The corner radius, the style padding, the enabled state and the click listener are unchanged. |

Unread on Android: `symbol` (an SF Symbol name; Android has no such glyph
catalog, and an `IconButton` carries a drawable), and `type` (the web
form-submission role).

## Fixture and test

`button-contract` (`AndroidButtonFixture` in `samples/cross_platform/android_host/`)
renders a brand button, a default button, an outlined one, a wrapping one, a
capped one and two aligned ones. `spec/web/ui/android_button_fixture_spec.cr`
pins the fixture's attributes; `AndroidButtonContractTest` reads each
`MaterialButton`'s background tint, text color, stroke width and color, line
cap and line count, and gravity, and checks the leading and trailing labels
against the text area's edges.

## Evidence and limits

- `docs/view-parity-matrix.md` lists `Button` at 11 of 13 attributes on
  Android after this change (`symbol` and `type` unread), with
  `text_alignment` read on Android only.
- A brand button's pressed and focused states still come from the Material
  ripple over the tint; the brand kit's own hover and pressed colors are not
  modeled by `UI::Button` on any platform.
