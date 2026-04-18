# Cards

- Study purpose: validate elevated, outlined, and tonal card defaults driven by shared tokens on Android.
- Native classes involved: `android.widget.FrameLayout`, `android.widget.LinearLayout`, `android.widget.TextView`.
- Current renderer status: renderer-backed in the Android host with a fresh phone/light capture from April 18, 2026.
- Light appearance notes: surface separation, outline treatment, and content padding are visible and materially better than the prior placeholder treatment.
- Dark appearance notes: not captured yet.
- Phone and tablet observations: phone capture is current; tablet validation has not started.
- Open deviations and promotion impact: the renderer still composes cards from `FrameLayout` plus shared shape styling rather than using `MaterialCardView`, and missing dark plus tablet coverage keeps promotion blocked.
