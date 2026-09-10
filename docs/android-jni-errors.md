# Checked Android JNI error handling

Status: development implementation. This extends the
[Crystal callback/render failure contract](android-failure-boundaries.md); it
does not certify every native failure mode or complete the Android target plan.

## Two cooperating boundaries

`android_jni_guard.h` owns 31 explicit checked JNI operations used by the native
View and collection bridges. It does not replace `JNIEnv`, install a proxy
function table, or change the VM's exception machinery. Before a non-cleanup
operation it checks for an existing exception and validates required non-null
receivers/classes/member IDs. A pending exception prevents further non-cleanup
calls; a throwing call's result is not treated as valid data. Null required
arguments produce a fixed-message Java argument exception instead of reaching
CheckJNI with an invalid receiver or method ID.

On the Crystal side, the public `LibAndroidBridge` and
`UI::JNI::LibJNICollectionBridge` modules generate forwarding methods directly
from their raw lib declarations. Each operation checks pending-exception status
before and after the native call. A failure raises `PendingJavaException` only
inside Crystal, allowing the renderer's rescue and ownership cleanup to execute.
The VM's original Throwable stays pending throughout; returning through JNI
delivers that same Throwable to Kotlin, where `HostSession.nativeCall` marks the
session terminal. The checked status symbol is required by generated package
inspection for both Android ABIs.

Delete-global/local-reference, string-buffer release and local-frame-pop calls
remain available during cleanup. VM bookkeeping and counter reads do not pretend
to take a JNIEnv parameter. The public forwarding surface is unchanged at call
sites; raw declarations are implementation details and must not be used to bypass
the error boundary in application code.

Android expressly requires checking pending exceptions before most subsequent
JNI calls, and managed exceptions do not unwind native frames. The two boundaries
handle those separate obligations. See the official
[JNI exception guidance](https://developer.android.com/ndk/guides/jni-tips#exceptions).

## Typed fallback, text allocation and privacy

Optional method/field lookups may clear only `NoSuchMethodError` or
`NoSuchFieldError`. A missing optional glass helper may clear only
`ClassNotFoundException`; an unavailable URL handler may clear only
`ActivityNotFoundException`. Callers check for an existing exception before
starting an optional lookup. Unexpected errors are restored, including when
checking the error type itself fails. Required Material classes and actual
constructor/method failures are not silently converted into fallback success.

Native UTF-8/UTF-16 conversion allocation/size failures now set an explicit Java
error rather than returning an unexplained null buffer. This does not guarantee
recovery from memory exhaustion or a process killed by Android.

The shared application exception logger now reports only the exception class,
with a fixed fallback if diagnostic formatting fails. It no longer formats app
messages or backtraces during render/lifecycle/service error handling. Callback
diagnostics retain their existing type-only policy. Toolchain, bootstrap and
Android's own platform logs are separate diagnostic paths, not covered by a
blanket privacy guarantee.

### Debuggable builds log the whole exception

The type-only rule above is the release contract. A debuggable host (the
manifest's `android:debuggable`, which every debug build sets) opts into the
full diagnostics: `CrystalBridge.initialize` passes the flag to the native
side (`debuggableNative`, a plain global so it reads on any thread), and
`UI::Android::Application.log_exception` then logs a second line,
`Crystal application diagnostics: ...`, holding `inspect_with_backtrace`
(capped at 8000 bytes) under the same `AssetPipelineNative` tag; the
`Crystal application error: <type>` line stays exactly as it is, since the
failure lanes count one such line per contained failure. Standard error goes
nowhere on a phone, so this is how a developer sees why a screen failed:
`adb logcat -d | grep -A40 "Crystal application"`. A release build keeps the
type only.

## Repeatable validation

```sh
bash scripts/tests/android_jni_guard.sh <host-evidence-directory>
bash scripts/test_android_java_failures.sh <adb-serial> <device-evidence-directory>
```

The host test uses the pinned NDK's VM-neutral JNI declaration, not an installed
JDK's optional headers. Address/undefined-behavior sanitizers exercise all 31
guard entrypoints while an exception is pending, invalid method-result rejection,
null receiver handling, typed fallback and preservation of the original error
when fallback inspection fails. A source check rejects newly introduced raw
non-cleanup calls in the View/collection bridges. This is a mock JNI table on the
host; actual VM behavior is proved separately below.

The device script first runs the complete clean regression and six isolated
Crystal-failure cases. It then runs a separate terminal-session Java test with
**50 partial renders for each of eight cases**:

1. Missing native View class.
2. A valid View missing a required TextView method.
3. A real Java View constructor that throws.
4. A real Java text setter that throws.
5. Missing collection element class.
6. ArrayList index out of bounds.
7. Null required View receiver.
8. An existing Java exception passed into optional theme/glass fallback calls.

Each failure occurs after a partial native tree exists and requires immediate
exact global-reference/callback baseline restoration. Then the public host
renders with a throwing Context, verifies original Throwable identity, terminal
state, rejected reuse and normal zero-resource cleanup. The script requires
runtime initialization, CheckJNI and the single expected application diagnostic,
rejects private error-message markers and crashes, and ends with a clean ordinary
app launch. The throwing JVM classes are sample-debug fixtures, not generated
application runtime classes.

## Remaining scope

This is coverage of the canonical View/collection operation layer and the tested
public render path. It is not arbitrary invalid-pointer/type safety, universal
allocation recovery, a transaction rollback or same-process recovery after
failure. Direct native platform-service paths, asynchronous completion policy,
bootstrap diagnostics, teardown failures, full ABI/API/device coverage and the
broader renderer/template/release gates still need their own evidence. Existing
preview/unsupported component fallbacks are not promoted to supported merely
because their JNI calls are checked.
