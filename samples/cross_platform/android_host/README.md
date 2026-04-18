# Android Material Host

This host is the Android validation shell for the `asset_pipeline` Material
phase. It is intentionally scoped to `asset_pipeline` ownership:

- renderer behavior lives in `src/ui/renderers/android_renderer.cr`
- shared validation truth lives under `docs/android-material-validation/`
- this host owns the Android showcase shell, capture entry point, and renderer
  mount surface

The shell is honest about current state. Until the Crystal/JNI render mount is
wired, the host shows study metadata and a dedicated native mount card instead
of pretending screenshots are renderer-complete.

## Local expectations

- canonical SDK root on this machine:
  `/opt/homebrew/share/android-commandlinetools`
- recommended AVDs:
  - `crystal_test`
  - `Pixel_3a_API_34_extension_level_7_arm64-v8a`
  - `pixel_tablet_api35`

## Build

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
cd samples/cross_platform/android_host
./gradlew :app:installDebug
```

The host accepts these activity extras:

- `study_slug`
- `study_appearance`
- `study_story`

Example launch:

```bash
adb shell am start -S \
  -n dev.assetpipeline.androidhost/.MainActivity \
  --es study_slug buttons \
  --es study_appearance light
```
