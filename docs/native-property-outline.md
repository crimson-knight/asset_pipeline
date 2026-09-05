# Native property outline (G4 candidate)

Status: local implementation candidate; simulator acceptance is still in progress.
Not released, not wired into Green Wave pricing, and not a premium entitlement.

## Boundaries

This UIKit/MapKit control edits an approximate user-drawn lawn/service outline,
including excluded sheds, paths, beds, etc. It does **not** identify cadastral
boundaries, assert imagery accuracy, measure slope, geocode an address, request
location permission, calculate a trusted price, create an account, or write to
any service. The caller supplies a resolved center/address label, controls
authorization, and decides what to do with a validated save callback.

The first slice is explicitly UIKit-only. Using `property_editor` or
`property_outline` on another renderer raises `NotImplementedError`; an inert
placeholder is not a supported fallback. Ordinary MapView remains unchanged.

## Caller API

```crystal
map = UI::MapView.new
map.latitude = resolved_latitude
map.longitude = resolved_longitude
map.address_label = submitted_address
map.zoom_level = 19.0
map.map_type = :hybrid # or :satellite
map.camera_revision = 1_i64

editor = UI::PropertyMapEditor.new("request-draft-stable-key")
editor.initial_outline = prior_validated_outline # optional
editor.on_draft_change = ->(raw : String) { draft_store.update(raw); nil }
editor.on_save = ->(outline : AssetPipeline::PropertyOutline::Outline) {
  quote_controller.submit_outline(outline.to_json)
  nil
}
map.property_editor = editor
```

Use `UIKit::Renderer.new(reuse_from: previous_native_root)` and call
`retire_prior!(fresh_native_root)` after swapping roots, following the existing
native host contract. Stable editor keys preserve the native view, draft, camera,
and keyed polygon overlays. An initial outline is read once, not imposed again
on every render. Use a new draft key to deliberately begin a different request.
The camera moves only when `camera_revision` changes. Unchanged draft callbacks
are suppressed before dispatch. Changed drafts are coalesced onto the next main
queue turn, after mounting, allowing the caller to rerender even from the first
callback without a recursive initial-mount loop. Validation/save remain disabled
until that latest draft is validated. Read-only and editable identities are
separate, so changing presentation mode cannot retain editing controls.

`on_draft_change` may receive incomplete/invalid geometry; it is **not** a save or
quote authorization. `on_save` receives independently revalidated canonical
geometry. If there is no save handler, the save button is disabled. A server must
revalidate/recompute even this canonical output; a modified client can fabricate
any request. The caller owns loading/busy/error behavior for its network request.

For a read-only native Polygon, set `map.property_outline` and a stable `map.id`.
The control shows keyed overlays without editing controls.

## Wire contract: `ap.property-outline.v1`

`geometry.type` is `Polygon`; `geometry.coordinates` contains one closed outer
ring then zero or more closed exclusion rings. Pairs are `[longitude, latitude]`
in WGS84 decimal degrees, not screen coordinates. `ring_ids` is a parallel array
of unique stable IDs (ASCII letters/digits/underscore/hyphen; 1–64 characters).
Revision is a nonnegative signed 64-bit integer. Source is `user_drawn_map`,
imagery is `satellite` or `hybrid`, and units are `m2`.

Canonical output includes `measurement` with method, radius, gross/excluded/net
square meters and plain-language `assumptions`. The parser ignores supplied
measurement, price, and entitlement fields and derives fresh measurements.
Coordinates are not rounded to display precision during serialization.

### Validation limits and geometry

- At most 16 exclusions, 512 vertices total (excluding closing duplicates).
- Payload at most 131,072 bytes; JSON nesting at most 12.
- Finite longitude in ±180°, latitude in ±85°; no antimeridian crossing.
- Maximum local equirectangular bounding-box diagonal: 5,000 meters.
- Every ring has at least three distinct vertices and at least 0.01 m² area.
- Repeated, doubled-back/collinear, self-crossing/touching edges are refused.
- Exclusions must be strictly inside; overlapping, touching, or nested holes
  are refused. Invalid/incomplete drafts cannot be saved.

Area method `spherical_cylindrical_equal_area_v1` uses sphere radius 6,371,008.8m.
Project longitude to λ and latitude to sin(φ); apply shoelace with an origin
translation to minimize floating-point cancellation. Multiply absolute projected
area by R²/2. Edges are straight in that projection, **not geodesic/survey edges**.
Excluded area is the sum of hole areas; net is gross minus excluded. Orientation
does not change area. Positional/imagery/terrain uncertainty dominates numerical
precision. Do not describe the numeric agreement tolerance as physical accuracy.

The portable no-dependency module is `src/geometry/property_outline.cr`; it can
be required directly by a Crystal server without the UI/renderer tree. Canonical
JSON cases are in `spec/fixtures/property_outline_v1.json`; analytic rectangle
expected values use a numerical tolerance of 0.00001 m². Server implementations
must pass the same fixtures before accepting this version.

## Native usability and visual checks

Draw mode adds vertices by tapping. Edit mode selects a nearby vertex, then moves
it on a second map tap; the Point menu provides accessible sequential selection,
coordinate editing/removal and coordinate addition. Coordinate fields support
Previous/Next/Done; negatives are supported. Pan mode never changes the outline.
Exclusions have dashed borders as well as a distinct label; the distinction is
not color-only. Undo is bounded to 64 snapshots; reset asks for confirmation and
is undoable. System map gestures and Apple map attribution remain visible.

Visual plate: content/data recipe F, with only the map and its related editing
controls. UIKit semantic text/backgrounds, caller tint, 16pt side rails, 8pt gaps,
44pt minimum control heights. Light/dark captures must show meaningful drawn and
invalid states. The fixture's refresh/status row is test instrumentation, not
production navigation. Platform-guides influenced native controls, map legal-link
visibility, accessibility labels, layout rails and actual interaction testing.

MapKit references: [MKPolygon](https://developer.apple.com/documentation/mapkit/mkpolygon),
[map overlays](https://developer.apple.com/documentation/mapkit/displaying-overlays-on-a-map),
[Apple map guidance](https://developer.apple.com/design/human-interface-guidelines/maps).

## Reproducible local gates

The complete native gate is one command on an explicitly selected, already
booted **dedicated simulator**. It never resets other simulator state or a real
customer app. Its source-hash receipt distinguishes a dirty local candidate from
published source. Build products stay in task-private temporary storage, avoiding
Finder/file-provider attributes from synced Documents; evidence is retained in
the chosen new output directory. Prior evidence is never overwritten.

```sh
ruby samples/property_measurement/ios/test.rb \
  --simulator DEDICATED-SIMULATOR-UUID \
  --native-deps /absolute/path/to/ios-simulator-c-libraries \
  --output /absolute/path/to/new-evidence-directory
```

This rebuilds the native library, app and tests; ad-hoc signs only the synthetic
app/test bundles; runs every discovered XCTest with zero permitted skips; then
explicitly repeats the saved-outline cold-launch test last. It independently
reads the app's real simulator preferences file and retains the canonical saved
outline. Results, failures and code/dependency hashes remain in `receipt.json`,
the logs, XCTest result bundles and `outline-from-simulator-disk.json`.

The startup fixture must initialize GC, the Crystal runtime **and top-level
constants** once before any other C-ABI call. Its explicit startup export passes
valid argv to `Crystal.main_user_code`; thread-only initialization crashes the
first floating-point serialization even though compilation succeeds.

Lower-level commands, for investigating a failed step:

```sh
CRYSTAL_CACHE_DIR=/private/tmp/property-geometry-cache crystal-alpha spec \
  spec/geometry/property_outline_spec.cr spec/web/ui/property_map_spec.cr \
  spec/web/ui/native/native_view_spec.cr spec/web/ui/native/callback_registry_spec.cr

CRYSTAL_CACHE_DIR=/private/tmp/property-native-cache \
  bash samples/property_measurement/ios/build.sh

xcodebuild build-for-testing \
  -project samples/property_measurement/ios/PropertyMeasurementFixture.xcodeproj \
  -scheme PropertyMeasurementFixture -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/property-measurement-derived-data \
  AP_NATIVE_DEPS_DIR=/absolute/path/to/ios-simulator-c-libraries CODE_SIGNING_ALLOWED=NO

xcodebuild test-without-building \
  -project samples/property_measurement/ios/PropertyMeasurementFixture.xcodeproj \
  -scheme PropertyMeasurementFixture -destination 'platform=iOS Simulator,id=DEDICATED-SIMULATOR-ID' \
  -derivedDataPath /private/tmp/property-measurement-derived-data \
  -resultBundlePath /private/tmp/property-measurement-unique.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

Native dependencies are the existing iOS-simulator Boehm GC/PCRE2 archives,
read-only. No package downloads are required for the library-only Swift build.
The fixture uses a separate bundle ID and writes only its own simulator
UserDefaults. Its `--fresh-fixture` flag clears only that synthetic saved outline;
the persistence gate then restarts **without** the flag and compares the actual
saved canonical JSON. No provider emails, customer data, or backend are involved.

Release acceptance requires the real XCUITest run, persisted-data receipt and
reviewed screenshots. A compile result or standalone geometry test is not that
acceptance. `Property outline contract` CI targets the actual `phase-10-c-0`
branch and checks portable geometry/native-lifecycle contracts; it does not
pretend the historical placeholder iOS CI lane is runtime proof.
Green Wave integration, web map credentials, quote policy, permission
checks, shared fixtures on the server, and end-to-end quote delivery remain caller
work and must be gated separately.
