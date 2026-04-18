# Map View

- Study purpose: eliminate the Android map placeholder family and keep the validation host stable while the platform bridge grows.
- Native classes involved: `android.widget.LinearLayout`, `android.widget.TextView`, `android.view.View`.
- Current renderer status: renderer-backed in the Android host with a fresh phone/light capture from April 18, 2026, and the prior crash path is fixed.
- Light appearance notes: the study now captures reliably and summarizes map mode, pins, and user-location state without falling back to the launcher.
- Dark appearance notes: not captured yet.
- Phone and tablet observations: phone capture is current; tablet validation has not started.
- Open deviations and promotion impact: this is still a composed preview surface rather than an SDK-backed map widget, so promotion stays blocked even though the crash is resolved.
