# Text Fields

- Study purpose: validate the first shared Material default pass for text entry, placeholder treatment, and combo-box selection.
- Native classes involved: `android.widget.EditText`, `android.widget.Spinner`, `android.widget.LinearLayout`.
- Current renderer status: renderer-backed in the Android host with a fresh phone/light capture from April 18, 2026.
- Light appearance notes: field chrome and spacing are now intentional instead of generic placeholder boxes, and the combo box mounts as a real Android spinner.
- Dark appearance notes: not captured yet.
- Phone and tablet observations: phone capture is current; tablet validation has not started.
- Open deviations and promotion impact: the study is still using `EditText` and `Spinner` rather than `TextInputLayout`-driven Material fields, so the screenshot can inform review but not promotion.
