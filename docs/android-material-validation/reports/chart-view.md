# Chart View

- Study purpose: eliminate the highest-visibility Android chart placeholder while the renderer and validation host mature together.
- Native classes involved: `android.widget.LinearLayout`, `android.widget.TextView`, `android.view.View`.
- Current renderer status: renderer-backed in the Android host with a fresh phone/light capture from April 18, 2026.
- Light appearance notes: the study captures cleanly and communicates the intended data story using shared view primitives.
- Dark appearance notes: not captured yet.
- Phone and tablet observations: phone capture is current; tablet validation has not started.
- Open deviations and promotion impact: the surface is still composed from generic Android views rather than a dedicated chart implementation, so it remains blocked from promotion.
