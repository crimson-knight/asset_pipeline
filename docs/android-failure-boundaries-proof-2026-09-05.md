# Android failure-boundary checkpoint — September 5, 2026

Status: **verified development progress; the full Android target goal is active**.
The [bounded contract](android-failure-boundaries.md) describes terminal-session
semantics and the safety paths not covered by this checkpoint.

## Implemented

- Five checked Crystal callback exports contain application exceptions and
  return explicit success/failure. Matching JNI and Kotlin methods carry the
  result rather than assuming a void callback succeeded.
- Callback diagnostics omit exception messages and callback input. Legacy
  Android callback exports are guarded while preserving their old ABI; the
  canonical clipboard path also consumes the checked string result.
- Kotlin marks failed native UI calls terminal and rejects further callback,
  render and activation entry. The owning Activity can still stop and detach,
  and explicit close drains services. No production reset hook was added.
- Every native view created during a render is explicitly owned until success;
  a partial Crystal render failure tears down even unattached containers and
  callback-bearing leaves immediately.
- A shared callback-registry bug is corrected: an explicit string-policy
  `false` no longer becomes `true`; only a missing callback defaults to true.
  The Apple runtime itself was not exercised by this Android checkpoint.
- The sample has opt-in deliberate-failure fixtures and a separate six-process
  runner. Ordinary sample/generated runtime gates reject callback-error logs.
  Generated package inspection requires the five checked exports in both ABIs.

## Native regression and deliberate failures

Retained evidence:
`/tmp/amber-android-safety-proof/failure-matrix-first`.

The clean `positive` lane passes:

- **30 Crystal callback/registry examples**, **21 navigation examples** and
  **eight image-compiler examples**.
- **60 JVM tests**, including the two new failed-session contracts.
- **18 Android tests in 91.626 seconds** on API 35 ARM64, covering native
  interaction, image/layout/theme, Unicode input, navigation/recreation and
  app-private storage, secrets and files.
- Sanitizer-backed C file-backend checks and all **1,112,064 Unicode scalar**
  codec round trips. These C checks run on the host, not inside Android.
- Fresh APK/test APK/AAB output, both packaged ABIs and a separate ordinary
  cold launch, PID **17047**, with runtime probe 42 and clean CheckJNI logs.

Then the six deliberate cases all pass independently:

| Error kind | Android process | Duration |
| --- | ---: | ---: |
| Void callback | 17125 | 5.497 s |
| String callback | 17184 | 5.996 s |
| Bool callback | 17238 | 6.384 s |
| Float callback | 17292 | 5.781 s |
| Int callback | 17349 | 5.821 s |
| Partial application render | 17405 | 5.600 s |

Each case first triggers **100 partial renders** after real native containers,
a Material toolbar and callback-bearing controls have been created. All **600**
return references/callbacks to the exact pre-probe baseline immediately, without
forcing garbage collection. After the terminal error, reuse is rejected; normal
Activity cleanup and explicit close leave references, callbacks and pending
services at zero.

Each process reports runtime probe 42 and CheckJNI, with exactly its expected
error diagnostic. The callback cases do not leak the private input/message
marker. There are no native signals, uncaught JVM exceptions or CheckJNI errors
in these tested cases. A final separate ordinary process, PID **17454**, mounts
the native interaction screen with clean diagnostics.

Native debug APK SHA-256:
`e50cd6505ebc023d7f9390e176436d5256bc603fe72d0e8d0d866c2e47b0f163`.
Native test APK SHA-256:
`0252404c19524bc5e370bf1edfa3fabe0ee35bbcc557ea64f8e78365fbf8729f`.
Native release AAB SHA-256:
`75894f735e3e6c514c18b1629ae61eeef8a84b953227cb377f029e14e71d595a`.
Native source ledger SHA-256:
`49ad083da65ce765c766cf381b940a9b523360a322b51f32f7737f2de49c3eae`.

The earlier `/tmp/amber-android-safety-proof/positive-first` also passed the
18-test regression with these same package hashes. It preceded adding the
callback-spec gate and stricter diagnostic filter to the runner. The completed
matrix above supersedes it. The runtime README was then updated before the fresh
consumer below; the native ledger intentionally identifies its earlier snapshot.

## Fresh actual-CLI consumer

CLI: `/tmp/amber-android-safety-proof/amber`.
SHA-256: `6868ef686d7b7f86479779740cdf890202f7c963fbca81cd2fd1db0c5ab8d64c`.
All **159 generator/configuration examples** pass, including required checked
callback symbols and the generated positive-run diagnostic filter.

Completed fresh consumer:
`/private/var/folders/81/8xr46ykx0p350l1g_v0nk7hr0000gn/T/amber-generated-android.Ujcvnz`.

- **Two shared examples** and actual web state/validation/CSRF/escaping checks
  pass, followed by **60 JVM tests** and **13 Android tests in 28.385 seconds**.
- The separate read-only restoration test passes in **4.941 seconds**.
  PID **17592** saves count **10** and `Android 雪 😀 é` (decomposed final
  accent); PID **17724** verifies the exact saved state. Final cold-launch PID
  **17778** restores it and remains foreground on `emulator-5556`.
- All **698 source entries** are unchanged before/after: **36 generated,
  242 Amber and 420 AssetPipeline**. No generated-source repairs were made.
- Both ABI ELF/JNI exports and native debug symbols, image payloads, explicit
  permission policy and compiled predictive-Back manifest opt-in pass artifact
  inspection. Android interaction, restoration and final launch logs contain no
  callback failure, application error, crash or CheckJNI diagnostics.
- `android-runtime/relaunch.png` was visually inspected: the native counter,
  bundled image, restored Unicode name, save action and details link are visible.

Consumer debug APK SHA-256:
`b797439c5f17943d5adcb68c60ebe252285a40176730a164cb61e9bf896a63a7`.
Consumer unsigned release APK SHA-256:
`a557427a3f98a84eb832ffef1dce031a0105068f8596fea72714072d3a6458e0`.
Consumer release AAB SHA-256:
`91e7eef0a01982864e5bf266215b22081e9770876ebdf2884925cfec5b037061`.

This is explicit **local-development Shards resolution**, not public release or
released-consumer proof. The dedicated deliberate failures are tested in the
canonical sample, not injected into the generated application.

## Scope and next work

Crystal callback containment and partial-render cleanup are now exercised on
the ARM64 emulator. This does not prove arbitrary pending Java exceptions,
native allocation/cleanup failures, low memory, malformed pointers or signals.
Individual C view helpers and the existing application/service logging paths
need a separate safety audit. Asynchronous service-completion failure policy
must preserve legitimate background/terminal cancellation delivery.

Broader layout/reconciliation/focus, Tier A accessibility/theme/modal behavior,
route restoration, CLI metadata workflows, AgentC's three reference screens,
CI/public releases and released-consumer proof remain open. Both libraries are
built and packaged, but x86_64 runtime and full API/phone/tablet matrices are not
claimed. A fresh ADB check still shows only `emulator-5554` and `emulator-5556`;
the physical phone is not visible. The original visible emulator was left intact.

The platform-level exception obligation is documented separately in Android's
[official JNI guidance](https://developer.android.com/ndk/guides/jni-tips#exceptions).
Do not treat passing the intentional Crystal exceptions as proof of every JNI
failure path or as completion of the full target plan.
