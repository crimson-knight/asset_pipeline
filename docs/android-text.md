# Android text and editor contract (development)

The Android bridge now converts standard UTF-8 to/from JNI UTF-16 explicitly.
JNI's `NewStringUTF`/`GetStringUTFChars` use a different encoding; they are not a
safe direct transport for Crystal strings. See Android's
[JNI string guidance](https://developer.android.com/ndk/guides/jni-tips#utf-8-and-utf-16-strings)
and the [JNI string API](https://docs.oracle.com/en/java/javase/17/docs/specs/jni/functions.html#string-operations).

## Preserved content and ownership

- Length-aware UI setters preserve NUL, supplementary characters (including
  emoji), combining marks and ZWJ sequences. There is no NFC normalization or
  application-side grapheme splitting. Rendering/glyph availability is still
  Android's responsibility; preserving a NUL does not give it a visible glyph.
- Native route names and text callbacks use new length-delimited exports.
  The old C-string exports remain for compatibility; an explicitly C-string
  caller still has C-string termination semantics.
- Crystal `UI::JNI::JString.from_string`/`to_string` copy standard UTF-8 using
  explicit lengths. `JString.length` is the Java UTF-16 code-unit count, not
  Crystal bytes or Unicode scalar count. `from_cstr` is explicitly the legacy
  NUL-terminated path, not the API for arbitrary text.
- `UI::JNI.hashmap_from_strings` now passes separate key/value byte lengths.
  Embedded NULs do not truncate typed map entries. Replaced values/local
  references are released during construction.
- Copied UTF-8 buffers belong to `malloc/free`; callers continue using
  `jni_string_release_utf8`, which now frees that copy rather than releasing a
  JNI modified-UTF-8 view. JNI UTF-16 buffers are released before returning.
- Each malformed UTF-8 byte and each unpaired UTF-16 surrogate becomes U+FFFD.
  Valid neighbouring characters remain intact. This is a defined text-repair
  policy, not a binary transport or a promise to preserve ill-formed encodings.
  The existing service/file byte protocols retain their independent contracts.

## Editing and submission

```crystal
field = UI::TextField.new("Name", text: current_name) do |value|
  current_name = value
end
field.on_submit = ->(value : String) { save_name(value); nil }

notes = UI::TextEditor.new("Notes") { |value| current_notes = value }
notes.text = current_notes
notes.is_editable = false # native read-only editor; programmatic updates remain possible
```

`on_change` receives the current editable text, including intermediate composing
text; it is not a committed-message event. Text callbacks update Crystal state
without replacing the editor. Android's selection offsets, composing spans and
input connection remain owned by the platform during this edit sequence.

`TextField.on_submit` is now connected to the native editor-action listener.
The field advertises Done. Done, Send, Go and Search actions submit the current
text; Next/Previous retain native traversal. Hardware Enter submits on its first
down event, consumes repeats/release, and does not invoke the callback twice.
The host schedules its ordinary refresh after the submit callback returns.
The action-policy branches have JVM tests; the Done path and current text are
also exercised through a real native `InputConnection`.

`TextArea` and `TextEditor` share the same plain multiline Android implementation:
text, placeholder, font/color properties, change callbacks, multiline input and
read-only mode. The old `TextEditor` raw-view placeholder did not wire these
behaviors. `is_editable: false` removes the native key listener, rather than
merely making the control look disabled. The native contract uses Android's
[input connection APIs](https://developer.android.com/reference/android/view/inputmethod/InputConnection)
for composition/commit and supplementary-code-point deletion.

## Evidence and limits

The sanitizer-backed host codec test covers all **1,112,064 Unicode scalar
values**, embedded NUL, empty input and malformed sequences. Native tests cover
actual Crystal string/map wrappers, labels, route names, editor callbacks,
composing Japanese/emoji text, combining/ZWJ/Arabic content, selection offsets,
code-point deletion, Done submission, multiline persistence across recreation,
read-only state and zero remaining native references/callbacks.

The generated counter test enters a Unicode name and a separate read-only test
process verifies the exact saved native text. An XML dump alone is not used as
exact supplementary-character proof. See the
[dated checkpoint](android-text-proof-2026-09-05.md) for final run results;
implementation alone is not passing consumer evidence.

This is not a complete rich editor or full Tier A UI surface. Syntax highlighting,
line-number chrome, TextArea line/scroll-limit semantics, all keyboard families,
complete accessibility and dark-theme/typography parity remain separate work.
Selection, focus and composing spans are not restored across a whole-tree
replacement or Activity recreation. The tests preserve text across recreation;
they do not claim full editor-state or arbitrary process-state restoration.
General callback-exception and JNI-allocation-failure handling still need a
broader boundary audit. No clipboard-content or external-intent runtime proof is
claimed merely because their shared string conversion is corrected.

## Field styles and the placeholder color

`UI::TextField#style` and `placeholder_color` are read on Android as the
SwiftUI facade reads them. `RoundedBorder` (the default) keeps the Material
filled box; `Plain` and `Underline` both drop the box (`BOX_BACKGROUND_NONE`)
so a brand paints the field from its own container (a filled box layers its
color over the surface, so a transparent filled box is the surface, and an
underline-only field would need a drawable the bridge does not have), which is how the AgentC shell's form fields are drawn after
an earlier build's unreadable system fields. An explicit `placeholder_color`
replaces the Material hint color. Fixture `text-field-styles`
(`AndroidTextFieldStyleFixture`), host spec, and `AndroidTextFieldStyleContractTest`
read each layout's box mode, box color and hint color.
