---
slug: web-views
ui_view: UI::WebViewComponent
priority: P2
platforms: [iOS, iPadOS, macOS]
hig_page: ../../../apple-hig/pages/web-views.md
validation_report: ../validation/reports/web-views.md
---

# UI::WebViewComponent

> An inline browser surface that loads and displays rich web content -- HTML or a
> remote URL -- directly within an app window using WKWebView (WebKit); no Liquid
> Glass material is applied because the surface renders HTML content, not an app-native
> overlay.

## Feel of the flow
_What this component "means" in a UI, and when to reach for it._

Reach for `UI::WebViewComponent` when your app needs to display content that lives on
the web or is authored in HTML -- a help center article, a terms-of-service page, a
rich-text email body, or a product detail page fetched from a CMS. The component
embeds a full WebKit rendering engine in a native view, giving users familiar web
scrolling and link behavior without leaving your app's chrome.

It is NOT for building a general-purpose web browser. The HIG is explicit: "Attempting
to replicate the functionality of Safari in your app is unnecessary and discouraged."
Use it for bounded, contextual web content that supplements your app's native UI, not
as a primary navigation surface.

(HIG: "Avoid using a web view to build a web browser. Using a web view to let people
briefly access a website without leaving the context of your app is fine, but Safari
is the primary way people browse the web." -- Web views / Best practices.)

## Quickstart

```crystal
# Embed a help page URL inside an app detail view.
wv = UI::WebViewComponent.new(url: "https://example.com/help")
wv.title = "Help Center"
wv.allows_navigation = true
wv.accessibility_label = "Help Center web view"
```

Renders: on macOS, an NSView placeholder framing the WKWebView content area (WebKit
framework required for production link); on iOS, a UIView placeholder framing the
WKWebView content area. No Liquid Glass material is applied; WKWebView renders
standard HTML content with a white/system background that tracks the page's own
CSS color scheme.

## Customization

| Knob | Type | Default | Effect |
|------|------|---------|--------|
| `url` | `String` | `""` | The URL string to load; passed to `WKWebView.load(URLRequest(...))` in production. |
| `title` | `String?` | `nil` | Optional title string stored as `accessibilityLabel` on the native view; useful for screen readers and validation. |
| `allows_navigation` | `Bool` | `true` | Whether forward and back navigation are permitted; set to false for bounded single-page content per HIG guidance. |
| `allows_scripts` | `Bool` | `true` | Whether JavaScript execution is enabled; disable for static content that does not require scripting. |
| `accessibility_label` | `String?` | `nil` | Accessibility label inherited from `UI::View`; mandatory for interactive elements per HIG. |

**Theming**: `UI::WebViewComponent` does not consume `UI::Theme` color tokens directly.
The rendered web content applies its own CSS color scheme. The surrounding host labels
("Embedded web content", description) in the showcase arm use `Theme.apple_default`
label colors via NSColor.labelColor / UIColor.labelColor. See
`foundations/color-and-theming.md`.

## Light / dark appearance notes

`UI::WebViewComponent` is a content view, not a system surface, so its background is
determined by the web page's own CSS rather than a platform material.

**macOS light**: The NSView placeholder renders with the default white window background
(NSColor.windowBackgroundColor ~1.0 RGB). The 1pt border uses RGB(0.55, 0.55, 0.55)
-- a mid-gray visible at ~4:1 contrast on white. In a production WKWebView integration,
the page background follows the page's `background-color` CSS; for system-aware
rendering you would set `webView.underPageBackgroundColor` to
`NSColor.windowBackgroundColor` so the scroll overscroll region matches the host.

**macOS dark**: DarkAqua host (~0.12 RGB). The placeholder interior fills with the host
dark color; the 0.55 gray border reads at ~3.8:1 contrast against the dark background.
In production, WKWebView's HTML content will render in whatever color scheme its CSS
declares; Apple's WKWebView 26 honors `prefers-color-scheme` media queries
automatically, so system-color-scheme-aware web content adapts without any Crystal
code changes.

**iOS light**: White card background. The UIView placeholder's 0.55 gray border is
faint (~4:1 contrast) against white -- visible but thin. Labels use
UIColor.labelColor (near-black in light, ~21:1 contrast).

**iOS dark**: Black system background. The 0.55 gray border has ~3:1 contrast against
black -- visible. Labels use UIColor.labelColor dark variant (near-white). In
production, WKWebView honors `prefers-color-scheme: dark` for pages that declare
dark-mode CSS variables.

No SF Symbols are used by this component. No Liquid Glass material is used; WKWebView
surfaces are plain content areas. No contrast caveats specific to the view itself
(contrast is the responsibility of the embedded HTML/CSS).

## Customization / brand override
_How to go from the HIG-default look to your brand voice, without giving
up HIG's legibility, hit targets, or appearance-tracking._

**Inject brand CSS into the web content.**
```crystal
# Load HTML with brand typography and color scheme already embedded.
# The WebViewComponent renders whatever the HTML declares.
wv = UI::WebViewComponent.new(url: "")
wv.title = "Brand content"
# In production, pass HTML via loadHTMLString:baseURL: from Swift/ObjC:
# webView.loadHTMLString("<html><body style='font-family: BrandFont; color: #1A2B3C;'>...</body></html>", baseURL: nil)
```
Note: CSS injection is the recommended brand override path for WKWebView content.
The Crystal view model controls the container; the content styling belongs to the HTML.

**Disable navigation for bounded single-page content.**
```crystal
# For terms-of-service or static help content that should not navigate away.
wv = UI::WebViewComponent.new(url: "https://example.com/terms")
wv.allows_navigation = false   # Disables WKNavigationDelegate forward/back
wv.allows_scripts = false      # Disables JavaScript for static content
wv.accessibility_label = "Terms of Service"
```
HIG guidance: "If people are likely to use your web view to visit multiple pages,
allow forward and back navigation, and provide corresponding controls." Setting
`allows_navigation = false` is appropriate only for single bounded pages.

**Provide a custom accessibility label for VoiceOver.**
```crystal
# VoiceOver reads the accessibilityLabel. Always set it when the URL alone
# is not meaningful to a screen reader user.
wv = UI::WebViewComponent.new(url: "https://cdn.example.com/content/12345.html")
wv.title = "Product description"
wv.accessibility_label = "Product description web view"
```
Hit target note: `UI::WebViewComponent` fills its parent container; no minimum
hit target constraint applies (it is a scroll surface, not a button).

## Feel recipes
Short examples that map design intent to code.

**"I want to show a contextual help article inside my app without a modal sheet."**
Place the `UI::WebViewComponent` directly in a `UI::VStack` or `UI::ScrollView` as
a peer to native views. Set `allows_navigation = true` so the user can follow links
within the help system. Set `accessibility_label` to describe the help topic.

**"I want to embed a rich-text email message body (HIG: Mail uses web views for HTML)."**
Set `url = ""` and in production call `loadHTMLString:baseURL:` with the message HTML.
Set `allows_navigation = false` (the user should not navigate away from the email).
Set `allows_scripts = false` (email HTML should not run JavaScript).

## What happens on each platform
- **iOS 26**: UIView placeholder sized to fill parent, 1pt mid-gray border, 4pt corner
  radius. Production integration: allocate WKWebView from WebKit framework and load
  via `loadRequest:` or `loadHTMLString:baseURL:`. WKWebView honors `prefers-color-scheme`
  automatically on iOS 26.
- **iPadOS 26**: Same as iOS 26. On iPadOS, WKWebView benefits from the larger screen
  with no additional Crystal changes required.
- **macOS 26**: NSView placeholder sized to fill parent, 1pt mid-gray border, 4pt
  corner radius. Production integration: allocate WKWebView from WebKit framework.
  Set `underPageBackgroundColor` to `NSColor.windowBackgroundColor` to match the
  host window appearance for overscroll regions.

## HIG citations (validated)
- Web views: "A web view loads and displays rich web content, such as embedded HTML
  and websites, directly within your app."
- Web views -- Best practices: "Support forward and back navigation when appropriate.
  Web views support forward and back navigation, but this behavior isn't available by
  default."
- Web views -- Best practices: "Avoid using a web view to build a web browser. Using
  a web view to let people briefly access a website without leaving the context of
  your app is fine, but Safari is the primary way people browse the web."
- Web views -- Platform considerations: "No additional considerations for iOS, iPadOS,
  macOS, or visionOS. Not supported in tvOS or watchOS."

Validation report with side-by-side HIG ref / live screenshots:
[validation/reports/web-views.md](../validation/reports/web-views.md)

## Related
- `UI::ScrollView` -- when you need a native scrollable content area (not HTML)
- `UI::Sheet` -- when the web content should appear in a modal overlay presentation
- `recipes/help-center.md` -- multi-component pattern combining NavigationStack
  with WebViewComponent for an in-app help center
