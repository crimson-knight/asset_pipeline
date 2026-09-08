# Bundled Android images (development contract)

`UI::Image` now uses application-owned Android resources. This is a native
`ImageView`, not a WebView or a network loader. The showcase and the Android
CLI generator run the same host-side compiler on every Gradle build.

## Application catalog

Create `config/android_assets.yml` in the application root:

```yaml
schema_version: 1
images:
  brand/logo:
    source: src/assets/logo.png
    dark_source: src/assets/logo-dark.png
    density: nodpi
  app_mark:
    source: src/assets/app_mark.android.xml
```

```crystal
mark = UI::Image.new("brand/logo")
mark.content_mode = UI::ContentMode::Fit
mark.minimum_width = mark.maximum_width = 80.0
mark.minimum_height = mark.maximum_height = 80.0
# Optional, independently applied to this view's drawable:
mark.tint_color = UI::Color.new(r: 0.0, g: 1.0, b: 0.0)
```

`source` is required for each logical image; `dark_source` is optional. Names
may contain Unicode, spaces and slashes, but not ASCII control characters or a
leading `@`/`?`; the UTF-8 name limit is 1,024 bytes. Runtime JNI uses explicit
UTF-8 bytes, not JNI's modified-UTF-8 string constructor. The compiler hashes
logical names into stable Android resource identifiers, preserving the original
name in a packaged lookup catalog. Names remain app-defined; the one other
accepted source is an absolute path inside the application's private storage,
see [bundled assets and fonts](android-assets.md).

Sources must be explicit project-relative regular files without symlinks,
absolute paths, `.`/`..` or empty path components. Supported source containers
are PNG, JPEG (`.jpg`/`.jpeg`), WebP and Android VectorDrawable XML. AAPT2 performs
Android resource validation. SVG, animated formats, nine-patch and arbitrary
drawable XML are not accepted as equivalent static-image support. Export SVG
to a supported Android representation explicitly; no silent conversion occurs.

## Native behavior and bounds

- Fit uses `FIT_CENTER`, Fill uses `CENTER_CROP`, Stretch uses `FIT_XY`.
- Tint uses `SRC_IN` and a separate mutated drawable; siblings do not inherit it.
- Android resolves night variants and drawable resources against the current
  View configuration/theme. Only resource IDs are cached, not Activities or
  decoded drawables. Existing mounted views must be rebuilt/rebound after a
  configuration change; the host recreation path does this.
- Density defaults to `nodpi`. Explicit source density may be `ldpi`, `mdpi`,
  `hdpi`, `xhdpi`, `xxhdpi` or `xxxhdpi`. One base density is supported per logical
  entry; this is not a full multi-density asset-set importer.
- Each source is at most 8 MiB, the declared source total at most 64 MiB, the
  catalog at most 1 MiB/512 logical images, and vector XML at most 1 MiB.
- Bitmap bounds are inspected before decoding: each dimension must be 1–4,096
  pixels and total area at most 1,048,576 pixels, both before and after Android
  density scaling. Loading remains synchronous on the main looper and is for
  small bundled UI images, not photos, streams or an asynchronous image cache.
- A missing/invalid `UI::Image` produces an explicit Crystal render diagnostic
  instead of an empty successful image. The Kotlin binding reports failure and
  leaves an already-loaded drawable unchanged. A legacy simple app-local
  drawable name is still resolved when absent from the catalog; arbitrary
  packages, resource types, URLs and paths are never resolved.

Android documents the [scale modes](https://developer.android.com/reference/android/widget/ImageView.ScaleType),
[resource qualifiers](https://developer.android.com/guide/topics/resources/providing-resources)
and [drawable formats](https://developer.android.com/guide/topics/resources/drawable-resource).
Compiled PNG/XML bytes may differ from source bytes after AAPT2 processing; source
checksums are provenance, not a promise of byte-identical APK resource payloads.

## Build ownership and evidence

`scripts/compile_android_assets.cr` accepts application root, relative catalog
path and output directory. Output is confined to that application's `build`
tree in a directory named `assetPipelineImages`. Gradle adds its `res` subtree
to the main resource set. `manifest.json` records catalog/source checksums and
generated files; it is retained as build evidence, not packaged as app content.

Publishing stages a complete tree, swaps it into place and removes stale
compiler-owned resources. Empty Gradle-created output directories are accepted.
Any nonempty destination must have an intact compiler ledger; handwritten files,
hidden additions, symlinks and modified generated payloads stop the build and
are preserved. Edit the catalog/source assets, not generated output. Concurrent
builds against the same project output are not a supported workflow.

Standalone compiler checks: `crystal spec spec/android_assets_spec.cr`.
Real native contracts run through `scripts/run_android_smoke.sh <serial>`.
The CLI-generated counter uses its own `app_mark` and verifies the actual native
drawable during its mandatory application test. This remains development support:
WebP-specific decoding, malformed/animated bitmap policy, full accessibility,
physical-device/runtime-matrix tests, fonts and general media packaging still
need their respective proof before a complete Tier A asset surface is claimed.

## AsyncImage

The Android renderer has no network loader. An application that shows
photos it fetched itself (the AgentC shell prefetches a customer document's
product photos and hands the bytes over) sets `UI::AsyncImage#preloaded_data`,
and the renderer decodes those bytes into the `ImageView` at the view's
`content_mode` (Fit, Fill, Stretch as `FIT_CENTER`, `CENTER_CROP`, `FIT_XY`)
with the catalog's decode limits (4096 px an edge, one megapixel); the
photo keeps its own pixels, one per pixel. An `AsyncImage` with no bytes
and a `placeholder` renders as a container of that placeholder view at the
image's frame, so a card shows "Loading" where the photo will be instead
of an empty box. `url`, `is_loading`, `error_message`, `on_load` and
`on_error` are the loader's attributes and are not read on Android. The
`async-image-contract` fixture and `AndroidAsyncImageContractTest` pin
this.

A preloaded photo larger than the catalog's one-megapixel bitmap budget
(a 1200 by 900 product photo already is) decodes at the power-of-two sample
size that fits the budget and the 4096 px edge (`ImageDecodePolicy`, with a
JVM test); only a declared size beyond 16,384 px on an edge, or bytes the
decoder cannot read, are refused. A refused photo is logged under `APImages`
and the view falls back to its `placeholder` (or an empty ImageView), the
way a nil UIImage does on iOS; it never raises. The `async-image-contract`
fixture covers both: the bundle's `art/photo-1200x900.jpg` decodes at 600 by
450, and 300 bytes of noise show "Photo unavailable".
