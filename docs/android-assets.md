# Android bundled assets and fonts contract

Status: development implementation, proven by the `assets-contract` fixture in
the `make test-android` class list (`AndroidAssetsContractTest`) and the
`BundlePolicyTest` and `FontPolicyTest` JVM suites.

## What the application gets

An application authored against the iOS host resolves its art by file path
under a directory the host names, and registers the TTFs it bundles under
the family names its views use. The Android host now provides both:

```crystal
require "asset_pipeline/ui/android/application"

if bundle = UI::Android::Application.bundled_assets_dir
  App::Assets.dir = bundle                                  # art by path, as on iOS
  UI::Android::Fonts.register("Inter-SemiBold", File.join(bundle, "fonts/Inter_semibold.ttf"))
end
```

- **The bundle.** Everything the APK packages under `assets/ap_bundle/` is
  copied once, per install, into the application's private files directory
  (`<files>/asset_pipeline_bundle/ap_bundle/`) when the runtime initializes,
  before the first render. The copy is stamped with the package's version
  code and install time; the next launch of the same install finds the stamp
  and skips the copy, a new version or a reinstall replaces the tree. An APK
  without a bundle reports `nil`.
- **Images by path.** `UI::Image#source` may be an absolute path to a file
  inside the application's own private data directory (the bundle, the files
  directory, the cache). The name declares the density the iOS way: `@2x`
  and `@3x` before the extension, plain names are one pixel per dp. Paths
  outside private storage, symlinks that leave it, and images beyond the
  catalog limits (4096 px an edge, one megapixel) are refused, and the
  render fails the way an unknown catalog name does. Catalog names keep
  working unchanged.
- **Fonts by family.** `UI::Android::Fonts.register(family, path)` loads a TTF
  or OTF file inside private storage under a family name; `UI::Font#family`
  then resolves, in order, to the registered face (which keeps its own weight,
  only italic is synthesized), to the Android family of that name (`serif`,
  `sans-serif-light`, `monospace`), or to the platform default, which is what
  an unknown name gets on iOS too. `"system"` is the default at the requested
  weight and slant.

## Private directories

`UI::Android::Application.files_dir` and `cache_dir` are the application's
private files directory (durable) and cache directory (purgeable by the
system), canonical, as the host hands them over when the runtime
initializes. An application puts its payload caches, cookie jars and
documents under them instead of guessing a home directory, which Android
does not set. The `directories-contract` fixture prints both and writes a
marker under each; its device test compares them with the activity's own
and finds the markers.

## Packaging

The CLI's generated project stages the directory named by
`android.bundled_assets` in `config/native.yml` (a project-relative
directory, the same tree the iOS target copies as a folder reference) into
the APK as `assets/ap_bundle/`. The sample host packages
`samples/cross_platform/android_host/bundle/` the same way.

## Boundary

`BundledAssets.initialize` runs from `CrystalServices.initialize`;
`android_host_bundled_assets_dir` and `android_host_font_register` are the
host-pull exports Crystal calls (JNI environment from the host's JavaVM);
`android_imageview_set_image_file` and `android_textview_set_typeface_family`
are the renderer bridge functions, calling `ImageAssets.setFile` and
`FontAssets.apply`. `BundlePolicy` (names, stamps, storage boundary,
density) and `FontPolicy` (family names, the style a registered face
takes) are the pure rules, pinned by the JVM suites.

## What the fixture proves

`assets-contract` prints the bundle path and the registered font count,
shows the bundle's 64 px `mark@2x.png` loaded by path, reads a note file from
the bundle, and sets four labels in a registered face, a generic serif, the
system face and an unknown name. The device test asserts that the bundle
lives under the files directory, that the mark measures 32 dp, that the
registered label wears the registered typeface and the serif label the
generic one, that the unknown name resolves the way Android resolves it,
and that a recreated host does not extract again.

## Not proven here

Extraction time for a large bundle on a slow device (it runs on the main
looper before the first render), a bundle that changes between installs on
a device, OTF-specific features, and variable fonts.
