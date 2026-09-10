# Android appearance (development contract)

An iOS host tells Crystal whether it is drawing in the dark through its trait
collection, and a brand theme picks its dark or light identity from that. On
Android the host answers the same question when Crystal asks before a render:
`UI::Android::Application.dark_appearance?` reads `HostAppearance.dark()`, the
night mode of the attached host's configuration (the activity's, which
`AppCompatDelegate.setDefaultNightMode` changes; the application's when no
host is attached). A night-mode change recreates the activity, which attaches
again and renders again, so a tree that reads the answer at render time
follows the system setting without a listener. Before the services initialize
the answer is light.

`HostAppearanceTest` pins the configuration mask; the `appearance-contract`
fixture prints the answer and `AndroidAppearanceContractTest` launches the
sample host in dark and in light and reads it back.
