# AgentC native account checkpoint — September 5, 2026

Status: **verified local-development progress; full Android goal still active**.
The real AgentC sign-in, account dashboard and settings screens now run as native
Android Views over Crystal-owned state. This replaces the earlier counter
starter. It is not a WebView, fake local identity, public released consumer,
physical-phone result or completion of the full compile-target plan.

## Implemented boundary

- `agentc_app_template_oss/src/app/accounts/session_state.cr` owns a bounded,
  origin-bound protected credential, asynchronous session transitions and
  generation-fenced HTTP callbacks. Sign-in is published only after the vault
  write succeeds. Sign-out serializes behind pending vault work, confirms
  deletion, then reports server revocation separately. A committed write whose
  completion fails/cancels is not assumed rolled back.
- Corrupt or wrong-origin credentials are preserved, never silently overwritten
  or sent to another server. Failed deletion blocks another sign-in and remains
  visibly incomplete/retryable. A kill before deletion acknowledgment is
  interrupted logout; durable user-intent logging is not claimed.
- Passwords, account profiles, drafts and route history are not stored. Password
  drafts clear on submit/background. Activity recreation preserves native editor
  focus/selection and retained settings drafts; a new process reads protected
  credentials and retrieves current account data from the real API.
- `src/platform/android/app.cr` provides three actual native screens using
  Android HTTP/Secrets adapters. Display-name validation and the server operation
  are shared with web settings. No sample revenue/activity is presented as real
  native account data. Grant, mailers, server sessions and Crystal OpenSSL stay
  out of the native application require graph.
- `AGENTC_ANDROID_API_ORIGIN` is validated compile-time HTTPS configuration. Its
  reserved `.invalid` default displays setup instructions and disables sign-in.
  Explicit local proof trust is generated into debug-only resources with
  localhost hostname verification; no permissive trust-manager or release CA.
- The AgentC Android command runs account/service tests and different-process
  restoration instead of starter counter tests. The two obsolete counter
  instrumentation files were removed; their generic generator templates remain.
- Android TextField defaults now resolve the active Material foreground.
  Explicit RGBA overrides, including black, remain honored. Other renderers'
  legacy color getter behavior is unchanged.

See AgentC's `docs/native-account-api.md` and `mobile/android/README.md` for
interfaces, TLS/server setup, preview limits and the guarded test workflow.

## Final native proof

Evidence root: `/tmp/agentc-android-accounts.32oJ8d`.
Final projection: `source-v7/project`; final command log: `redacted-cli-test.txt`;
device/package evidence: `redacted-cli-proof/`. The preceding passing light/dark
run remains at `final-cli-proof/`; the last rerun adds credential-safe test action
descriptions and a mandatory scoped-log credential-pattern rejection gate.

The actual previously built Amber CLI executes:

```sh
amber test android --device emulator-5556 --project /absolute/path/to/projection
```

The invocation explicitly supplies the task-local HTTPS origin, public CA,
verified cross-dependency cache and toolchain. The projection uses current local
Amber V2/AssetPipeline through two explicit shard links. **No public shard
resolution, dependency-lock update or installed-library replacement is claimed.**

- Both ARM64 and x86_64 API 31 native libraries, debug APK, unsigned release APK
  and release App Bundle build from source. Final Gradle build: 42 seconds,
  127 executed tasks. Execution target: isolated ARM64 API 35 emulator-5556.
- All **79 JVM tests** pass, with nonempty reports required by the driver.
- All **13 Android account/platform tests** pass in 43.845 seconds. They cover
  wrong-password response, real TLS sign-in, password obscuring and actual
  framework saved-hierarchy exclusion, password clearing across recreation,
  native navigation/accessibility activation, shared name rejection, exact
  Unicode IME input/save, refresh, sign-out and terminal resource cleanup.
- The account flow switches actual Activity appearance between dark and light.
  Both email/password editors match the active Material foreground and exceed
  4.5:1 contrast against their fill. Light/dark sign-in screenshots were visually
  inspected; dashboard and settings screenshots were also inspected. This does
  not certify every screen/control in every appearance or full TalkBack behavior.
- Settings draft, focus and selection survive background/resume and Activity
  recreation. The settings operation saves `Android 雪 😀 é` (UTF-8 hex
  `416e64726f696420e99baa20f09f98802065cc81`) through the real server.
- A separate **one-test restoration process** loads that exact account through
  protected credentials and real API reads, then signs out (7.43 seconds).
  Main test PID 3027, restoration PID 3165, final signed-out cold-launch PID 3246. The final launch
  does not show account data or the synthetic email. No data-clear/reset was used.
- CheckJNI is enabled; scoped app logs pass crash/JNI/Crystal-error checks.
  Native references/callbacks/services return to zero at the tested boundaries.
- Debug/release manifest permission checks, both ABI ELF/export checks and
  matching packaged/native-debug-symbol build IDs pass. The main debug APK,
  release APK and bundle exclude the synthetic test password. Release manifest,
  resource table and bundle exclude the local test trust resources.

Native build IDs: ARM64 `ddbd500abda0feb1`; x86_64 `79321b92b8f0da3a`.

```text
debug APK     c2042b5afcf082fd4708d7b6a141ecb43c9abf6c91c1565d224d5dda06d2adf9
release APK   0fbd73b3e45010933fe3ea3fe5ad57e43c2ef84c38e48fceda1061e653407267
release AAB   f77c8b1576afebf6ca4aeebc5fa4fe6ee3acf53aa71d28bf873ad524bdfdfd83
```

These are local-origin development artifacts, not deployable production-server
configuration or signed store releases. A release build does not trust the task
CA even when built in the same invocation as its debug proof.

## Web/shared proof and provenance

- The guarded full AgentC suite passes **350 examples**, zero failures/errors,
  three existing pending permission checks (`full-suite-final.txt`, 1:47 minutes;
  the earlier complete run also passes in 2:21 minutes).
  The new state coordinator contributes 15 tests; standalone account tests total
  27. AssetPipeline's field/view regression passes **328 examples**, zero failures,
  errors or pending (`field-regression.txt`).
- `web-after-android.txt` proves the existing Android-saved name appears in real
  authenticated web settings and the API **before** any smoke-test edit. The
  subsequent real TLS smoke passes normal browser CSRF, shared edits both ways,
  escaping, duplicate Authorization rejection, early/chunked body bounds and
  logout. This is real HTTP-rendered web output, not a browser layout audit.
- The server is the earlier verified API binary, SHA-256
  `55d9000544dda762b84544efcc025621a84bd5e39109abac2d4f8eef35e5dc38`;
  its server-side API is unchanged in this screen milestone. Only guarded task
  database `agentc_android_20260905_ivvezn` was used. Post native/web proof records
  zero active native sessions (`database-after-native-web.txt`). Full specs
  intentionally truncate only this disposable database's test tables.
- All **41 attached inputs** remain byte-identical in the original app and final
  native projection (`attached-source-redacted-final.txt`). A selected **239-file**
  AssetPipeline UI/runtime/config ledger also passes its final checksum check.
  These are selected-input records, not a claim that every transitive server or
  compiler dependency was frozen. Four derived Android metadata files match the
  current CLI generator after normalizing only the final newline.

Earlier failed evidence is retained: an initial Gradle script used shadowed
`java.io.File` and was fixed with an import; the first privacy assertion checked
the child's save flag, although the canonical host disables parent traversal for
the whole mounted subtree. The corrected test invokes actual hierarchy saving
and proves the password editor is absent, in addition to metadata-only capture
and recreation checks. The native host's saved-state contract was not weakened.
See Android's [hierarchy saving API](https://developer.android.com/reference/android/view/View#setSaveFromParentEnabled(boolean)).

The final log review found Espresso's standard `replaceText` action description
printing the synthetic fixture password in the test process (not production
application logging). The replacement wrapper retains the actual native edit
action but redacts its description. A final complete CLI rerun passes the new
credential-log gate; both its scoped app logs and the real server log contain
none of the password/bearer patterns checked. Earlier synthetic-only logs are
retained as failed privacy-gate evidence, not presented as credential-clean.
`cleartext-origin-rejected.txt` also records an actual rejected compile-time HTTP
origin; this preflight never proceeds to native compilation for that input.

## Remaining gates

The physical phone is still absent from ADB; both existing emulators remain
available and the user's visible emulator-5554 was preserved. The task's
`tcp:38248` reverse mapping was removed; no other mapping was changed. The owned
HTTPS server was stopped after validation (expected exit 143 after TERM).
CheckJNI was already 1 and remains 1. No global trust store or installed app data
was cleared. The guarded synthetic account is restored in the disposable task
database after the full suite, ready for a separately started proof server.
The installed debug app still opens signed out; sign-in requires restarting
that local HTTPS fixture and its explicit mapping, or rebuilding for a real
configured trusted HTTPS server.

Still open: physical-phone proof; runtime API/ABI/tablet matrix; full TalkBack,
large-font/RTL/control coverage; remaining Tier A dialogs/progress/layout/pickers;
safe CLI metadata regeneration; CI and reproducible/public released-consumer
proof. Account session expiry is enforced on calls, not continuously during a
passive display. Production proxy/abuse/identity-provider policies remain the
explicit API-contract limits. None of these are satisfied merely by this
three-screen emulator result. Continue the full implementation plan.
