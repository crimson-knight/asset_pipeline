# App Bars

- Study purpose: validate top app bar structure, title emphasis, and trailing utility actions for the shared Android renderer.
- Native classes involved: `android.widget.LinearLayout`, `android.widget.TextView`, `android.widget.Button`, `android.widget.Space`.
- Current renderer status: renderer-backed in the Android host with a fresh phone/light capture from April 18, 2026.
- Light appearance notes: this batch tightened borderless button padding so trailing actions have a better chance of fitting on phone width without obvious truncation.
- Dark appearance notes: not captured yet.
- Phone and tablet observations: phone capture refreshed after the padding adjustment; tablet validation has not started.
- Open deviations and promotion impact: the surface is still a composed toolbar row rather than `MaterialToolbar`, and it needs another visual review pass before promotion can be considered.
