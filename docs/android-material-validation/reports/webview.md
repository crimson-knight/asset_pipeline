# WebView

- Study purpose: replace the placeholder web surface with a real Android-native web container inside the validation host.
- Native classes involved: `android.webkit.WebView`, `android.widget.LinearLayout`, `android.widget.TextView`.
- Current renderer status: renderer-backed in the Android host with a fresh phone/light capture from April 18, 2026.
- Light appearance notes: the study now mounts a real `WebView` and loads inline HTML content so the capture shows genuine Android web rendering rather than an empty box.
- Dark appearance notes: not captured yet.
- Phone and tablet observations: phone capture refreshed after wiring inline HTML loading; tablet validation has not started.
- Open deviations and promotion impact: dark evidence is still missing, and a representative external-content path still needs follow-up before this surface can be considered fully validated.
