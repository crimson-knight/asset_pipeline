# AgentC account boundary checkpoint — September 5, 2026

Status: verified development progress on the shared account use case, server
authentication API and native-safe client. **The full Android goal remains
active.** The AgentC native entrypoint remains the earlier counter starter; no
account APK is built or installed here. The required sign-in, dashboard and
settings screens are not implemented or claimed by this checkpoint.

## Implemented

- Shared account values and Unicode display-name validation; the same server
  use case is called by real authenticated web settings and the mobile API.
- Four private endpoints over direct TLS: sign-in, account read, display-name
  update and logout. Session tokens are opaque 256-bit random values; only their
  digests are persisted. Absolute/idle expiry, revocation, deleted-account and
  password-change invalidation are covered.
- Amber pre-routing ingress registration and literal transport-method access.
  This is earlier than form method-override parsing. Late/duplicate registration
  and calling an unprepared ingress fail explicitly instead of bypassing policy.
- Bounded strict JSON input, no ambient cookie authentication, fixed private API
  errors, and bounded process-local login admission. Existing web CSRF remains.
- An asynchronous native-safe HTTP client with explicit HTTPS origin, bounded
  encoded requests, strict bounded responses, cancellation-operation forwarding
  and non-sensitive failure values. No Grant, PostgreSQL or Crystal OpenSSL
  belongs in this client require graph.
- Task-only migration/seed/smoke entrypoints and a scoped `build/.gitignore` for
  AgentC Android build artifacts. Installed libraries and dependency lockfiles
  remain untouched by this work.

The current installed AgentC Amber shard is older than the development ingress
API. Verification continues to use the explicit local dependency projection at
`/tmp/agentc-android-reference.ivvEzN/shards`; this is not public release or fresh
dependency-resolution proof.

## Evidence

Root: `/tmp/agentc-native-accounts-proof`. Only the previously verified task-owned
database `agentc_android_20260905_ivvezn` is in scope. Its third forward migration
adds the optional display-name columns and native session table; no database is
dropped and no rollback is run.

- Amber routing/request/test-helper regression: **126 examples**, zero failures,
  errors or pending, 560.44 ms (`amber-regression-final.txt`). Seven ingress tests
  cover ordering, body-read avoidance, existing form overrides and fail-closed
  registration/preparation. The request helper now preserves duplicate headers
  instead of silently replacing the first value in tests.
- AgentC final guarded full regression: **335 examples**, zero failures/errors,
  three existing pending permission checks, 1:23 minutes (`full-suite-final.txt`).
  Earlier 327- and 334-example passes are retained as intermediate evidence.
- Four shared value tests and eight client contracts also pass independently:
  **12 examples**, zero failures/errors/pending, 2.38 ms
  (`shared-client-final.txt`).
- The actual TLS server and synthetic account pass a real transport smoke test:
  trusted/untrusted certificate behavior, normal browser CSRF, mobile sign-in,
  exact Unicode updates visible in both interfaces, escaped HTML, duplicate
  Authorization rejection, pre-body input rejection and empty logout/revocation.
  The final `live-account-final.txt` run also passes the chunked, unknown-length
  4 KiB limit. These results come from real HTTP/TLS sockets, not a mock adapter.
- The actual client methods execute in the no-OpenSSL host boundary fixture.
  Both Android API 31 objects are ELF relocatables for their correct ARM64/x86_64
  architectures (`account-client-arm64.o`, `account-client-x86_64.o`). x86_64 uses
  AssetPipeline's canonical generated libc overlay. No Android runtime/HTTP
  exchange is inferred from these object builds.

The server-only session implementation is rejected by an actual Android
cross-compile with Amber's intended server-import diagnostic. A mismatched
expected database is also rejected before forward migration. The final database
inspection shows all three expected migration versions and **zero native
sessions** after logout. No token/password pattern is found in the final server
runtime log. The synthetic account and task-only certificate remain in private
task storage for the next emulator integration; no system trust store changed.
The final server was stopped after proof (exit 143 from the requested TERM);
read-only listener checks confirm task ports 38247 and 38248 are closed.

The 28 selected account/framework source and test inputs have an explicit hash
ledger (`selected-account-inputs.sha256`) and pass the final read-only check.
This is a selected-input ledger, not a claim that the entire dependency graph
was frozen or that the historical attachment ledger still describes these edits.

Final artifact SHA-256 values:

```text
server-final                 55d9000544dda762b84544efcc025621a84bd5e39109abac2d4f8eef35e5dc38
account-client-arm64.o        e2d9e604dcdfd13ed15e0018809485a75dd633dcfb2b1c412bfde90cdaa81d75
account-client-x86_64.o       516507db58df8f6e4745d04679d23de208a2e4365f198a24893ab0212153335a
full-suite-final.txt         38aadcb0defb5e2d8e83de7338850f4e26e21d976c4ed393769048d7cff9c157
live-account-final.txt       b05550b82cc9f9ce89af2b81f8e7c1056f5faaf61c61dfa02a29fc5e54e9382e
```

The earlier 83-file attachment preservation ledger is historical evidence for
that additive operation, not proof that this new migration leaves web files
unchanged. This checkpoint intentionally changes settings/routes, adds the
shared settings operation and extends both user models and test cleanup.

## Findings retained rather than hidden

The first source pass exposed concrete compile issues in Grant union-model save,
optional flash text and bounded IO reading; these were corrected. A negative
duplicate-header test exposed Amber's test builder overwriting repeated headers,
not an authorization bypass in the real transport. Its helper was corrected and
the actual TLS duplicate-header check also passes.

The broader Amber test run initially lacked sandbox permission for its localhost
WebSocket listener. Its specifically identified stuck processes were terminated
after the explicit bind failure; the permission-enabled regression passes.

The legacy AgentC settings loader did not apply the v2 TLS environment overrides.
The app now explicitly honors both TLS file settings. During the incorrect
configuration the API stayed closed with 426; the final real server announces an
HTTPS listener. Native request handling does not trust forged proxy headers.

A raw x86_64 object command without the canonical libc overlay failed. Both
canonical object builds subsequently succeed with the overlay. An attempted
standalone shared-library link correctly failed for the absent application
initializer: the boundary fixture is not a complete Android app. No fake runtime
export or relaxed undefined-symbol link was added to disguise this.

## Still required

1. Protected session storage bound to the configured origin, generation-fenced
   asynchronous state, explicit error/retry/logout behavior and lifecycle tests.
   Interrupted or late vault writes must not resurrect a signed-out session.
2. Real native sign-in, account dashboard/list and settings/detail screens. The
   template's illustrative web revenue/activity must not become fake native data.
3. Actual Android HTTP/secrets injection, explicit INTERNET opt-in and safe
   compile-time API origin. Any local test CA belongs only in debug test resources,
   never global trust, cleartext overrides or a release package.
4. The shared operation exercised on the emulator, recreation/process restoration,
   password privacy, cancellation, failure and logout proof; then physical phone.
5. Remaining renderer Tier A, device/API/ABI matrix, generator/CI, public release
   and released-consumer gates in the full implementation plan.

Both existing emulators remain visible; the physical phone is still absent from
the current ADB inventory. No emulator was cleared or replaced in this checkpoint.
See `agentc_app_template_oss/docs/native-account-api.md` for bounded security and
deployment semantics, including direct-TLS-only and process-local throttling.
