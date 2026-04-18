# Dialogs

- Study purpose: validate the first Material-style pass for alert and confirmation actions in the Android renderer.
- Native classes involved: `android.widget.LinearLayout`, `android.widget.TextView`, `android.widget.Button`, `android.widget.Space`.
- Current renderer status: renderer-backed in the Android host with a fresh phone/light capture from April 18, 2026.
- Light appearance notes: title, body copy, and action ordering are all visible, and the study now reads like a dialog surface rather than a raw placeholder box.
- Dark appearance notes: not captured yet.
- Phone and tablet observations: phone capture is current; tablet validation has not started.
- Open deviations and promotion impact: both alert and confirmation flows are still inline renderer compositions instead of platform or Material dialog APIs, so the study remains blocked from promotion.
