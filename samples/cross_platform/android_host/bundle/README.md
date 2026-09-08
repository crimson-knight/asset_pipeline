# Sample host bundle

Everything under `ap_bundle/` is packaged into the sample APK's `assets/` and
extracted once, per install, into the application's private files directory
by `BundledAssets` (see `docs/android-assets.md`). The `assets-contract`
fixture loads the mark by file path, registers the TTF under the family name
`Inter-SemiBold`, and reads the note.

`fonts/Inter_semibold.ttf` is Inter by Rasmus Andersson, under the SIL Open
Font License 1.1 (https://github.com/rsms/inter); it is here as a fixture.

`ap_bundle/art/photo-1200x900.jpg` is the mark stretched to a 1200 by 900 JPEG
(ImageMagick), a stand-in for a product photo over the one-megapixel bitmap
budget; the `async-image-contract` fixture hands its bytes over as a photo.
