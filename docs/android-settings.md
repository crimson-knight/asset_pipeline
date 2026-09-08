# Android host settings (development contract)

An iOS archive bakes a customer's identity into Info.plist (a demo id, a
display name, a theme, a palette, an API base) and the Swift host reads each
key into a Crystal setter before the first render. `HostSettings` is the
Android side of that channel: key-value settings the host application
registers with the runtime before Crystal starts, read by key from Crystal.

## Contract

- Keys are 1 to 64 characters of `[A-Za-z0-9_.]`; values are UTF-8 up to
  4096 bytes. A later registration under the same key replaces the value.
- `HostSettings.register(key, value)`, `register(map)` and
  `registerSerialized(text)` (Kotlin) register before `CrystalBridge`
  initializes. The serialized form is one `KEY=value` per line: blank lines
  and lines starting with `#` are skipped, the first `=` splits, both sides
  are trimmed. `HostSettingsTest` pins the rules.
- `UI::Android::Application.setting(key) : String?` (Crystal) returns the
  value or nil when the build carries none; it raises on a key outside the
  contract or when the host is unavailable. Read at startup, not per render.
- Settings are public build metadata, like Info.plist keys: never a secret.

## The generated application

The Amber CLI's Android project carries
`app/src/main/res/values/host_settings.xml`, one string resource named
`ap_host_settings`, empty in a fresh project, and its `MainActivity` calls
`HostSettings.registerSerialized(getString(R.string.ap_host_settings))`
before `CrystalBridge.initialize`. A release step writes the customer's
lines into that resource (the AgentC shell's
`mobile/android/scripts/release_lead_demo.rb` writes `AGENTC_DEMO_ID`,
`AGENTC_DEMO_DISPLAY_NAME`, `AGENTC_DEMO_THEME`, `AGENTC_DEMO_PALETTE`,
`AGENTC_DEMO_API_BASE` and `AGENTC_DEMO_NATIVE_IDENTIFY`, the keys the iOS
archive bakes), so the same branch builds the same identity on both phones.

## Fixture and test

`settings-contract` (`AndroidSettingsFixture`) prints two values the sample
host registers (`SAMPLE_DISPLAY_NAME`, `SAMPLE_DEMO_ID`) and one absent
key; `spec/web/ui/android_settings_fixture_spec.cr` pins the labels and
`AndroidSettingsContractTest` reads them back on the device.
