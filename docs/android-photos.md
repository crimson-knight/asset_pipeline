# Android photo picker contract

Status: development implementation, proven by the `photo-contract` fixture in
the `make test-android` class list (`AndroidPhotoContractTest`).

## What the application gets

An application that takes a photo from the person (the AgentC shell's
identify flow) needs the library picker and the camera behind one polled
contract, the shape its iOS bridge already has:

```crystal
require "asset_pipeline/ui/android/application"

UI::Android::Photos.begin(UI::Android::Photos::Source::Library)   # or Camera
# ... on later host ticks:
case UI::Android::Photos.state
in .ready?     then jpeg = UI::Android::Photos.take; UI::Android::Photos.reset
in .cancelled? then UI::Android::Photos.reset
in .error?     then message = UI::Android::Photos.error_message; UI::Android::Photos.reset
in .active?, .idle? then nil
end
```

- **Polled, one pick at a time.** `begin(source, max_dimension = 2000,
  jpeg_quality = 0.8)` presents the picker and returns false when a pick is
  active, the source is unavailable or the platform refused. `state` moves
  Idle, Active, then Ready, Cancelled or Error; `take` hands over the JPEG
  bytes while Ready; `width` and `height` are the encoded photo's pixels;
  `error_message` names an Error; `reset` clears the way for the next pick.
  The application's host tick drains it, as on iOS.
- **The library** is the system photo picker (`PickVisualMedia`, images only;
  no permission on any supported API level).
- **The camera** is `TakePicture` into `capture.jpg` under the app's private
  cache, which needs the application's manifest to declare a `FileProvider`
  with authority `<applicationId>.assetpipeline.photos` over the runtime's
  `@xml/ap_photo_paths`; `available?(Source::Camera)` is false without it or
  without a camera. The camera permission is not needed for `TakePicture`.
- **The result** is decoded off the main looper: sampled down, rotated by
  its EXIF orientation, fitted so the longest edge is at most the requested
  dimension, and encoded JPEG at the requested quality; anything over 10 MB
  is an Error. The state changes on the main looper.
- **Lifecycle.** The launchers register with the Activity's result registry
  when the runtime attaches the host, before it starts; a recreation
  re-registers under the same key and receives an outstanding result; a
  detached host that is not recreating cancels an active pick.

## Boundary

`PhotoPicker` (Kotlin) holds the state and the launchers;
`android_host_photo_*` are the host-pull exports Crystal calls on the main
looper (`available`, `begin`, `state`, `byte_count`, `copy_bytes`,
`dimension`, `error`, `reset`); `UI::Android::Photos` is the Crystal face.
`PhotoPicker.debugDeliver(uri)` feeds a content URI through the same path a
picker result takes, for tests that do not drive the system UI;
`debugLaunches()` counts real launches.

## What the fixture proves

`photo-contract` prints the state, the encoded byte count, the pixel size,
which sources are available and the last error, with a button per source
and a reset; the sample bridge polls the picker on its tick while the
fixture is on screen. The device test inserts a 3000 by 2000 JPEG into the
media store, delivers it, and asserts Ready, a 2000 by 1333 result, a
plausible byte count and a clean reset; then it launches the real library
picker, waits for its window and presses Back, and asserts Cancelled.

## Not proven here

The camera on a device (the emulator has no capture provider proof in this
suite), a photo larger than 10 MB after encoding, and a pick that survives a
recreation while the picker is up.
