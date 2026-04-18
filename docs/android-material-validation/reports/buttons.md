# Buttons

- Study purpose: validate default emphasis, destructive treatment, and low-emphasis actions for shared Android buttons.
- Native classes involved: `android.widget.Button`, `android.widget.LinearLayout`, `android.widget.Space`.
- Current renderer status: renderer-backed in the Android host with a fresh phone/light capture from April 18, 2026.
- Light appearance notes: primary, tonal, outlined, and text actions read clearly; borderless button padding was tightened in this batch to reduce cramped layouts in downstream surfaces.
- Dark appearance notes: not captured yet.
- Phone and tablet observations: phone capture refreshed on the Pixel 6 API 35 host; tablet validation has not started.
- Open deviations and promotion impact: the study still relies on `android.widget.Button` plus shared styling rather than `MaterialButton`, and missing dark plus tablet evidence keeps promotion blocked.
