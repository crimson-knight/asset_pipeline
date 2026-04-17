# UI::StatusBar

Status: implemented, validation skipped.

This row now documents a macOS status item model with an attached menu. The
API is intentionally small: title, icon, tooltip, menu, and install state. The
actual `NSStatusItem` bridge will land later, but the app-facing shape is
already in place.

Current judgment:

- status-item model: useful and minimal
- system chrome: owned by the OS shell
- screenshots: not applicable

