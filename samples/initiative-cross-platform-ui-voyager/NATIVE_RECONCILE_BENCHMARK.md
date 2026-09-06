# Native reconciliation benchmark

This is a collector-neutral, production-path microbenchmark for the Voyager
sample's real AppKit/UIKit renderers and its shared in-place reconciliation
walk. It does not serialize a widget tree through JSON.

For every measured update it changes the ReconcileProbe's echo state, then
records three separate totals:

- `build_ns_total`: build a fresh `UI::View` tree from the new state.
- `diff_ns_total`: walk that tree against the mounted `UI::NativeView` tree.
- `commit_ns_total`: call the real SwiftKit label-property setters.

Every result includes operation counts and a deterministic checksum. The trial
is invalid when `success` is false. The outer harness, not this code, must
record the compiler, target CPU, runtime, collector, device, thermal state, and
trial order.

## Scope

The runner mounts a real native object tree in the renderer and performs its
actual property commits. It intentionally does **not** attach that root to an
AppKit/UIKit window or measure Auto Layout, display-list creation, GPU work, or
vsync. Treat it as a widget-build/reconcile/native-property-commit benchmark,
not a full screen-render or scrolling benchmark.

The ReconcileProbe has two labels. The versioned `all-label-commit` baseline
writes both; the production `dirty-label-commit` mode walks both but writes
only the changing echo label. `structural_label_visits_total` must therefore
remain two per frame in both modes, while `reconcile_ops_total` is two per
frame for the baseline and one per frame for the optimized path. The checksum
must agree across modes: it represents the workload, not the number of writes.

## Running

On macOS, build the Voyager host with the ordinary open-source runtime and set:

```sh
VOYAGER_NATIVE_RECONCILE_BENCH_FRAMES=600 \
VOYAGER_NATIVE_RECONCILE_COMMIT_MODE=dirty-label-commit macos/bin/voyager
```

For repeatable evidence, use `scripts/run_native_reconcile_macos.py`; it runs
two warmups and 15 process-fresh trials in each mode and writes provenance-rich
JSONL. For a physical iPhone 15 Pro, use
`scripts/run_native_reconcile_ios.py` only after reviewing the connected
device. It builds and signs a generic arm64 app, collects nonce-bound atomic
results from the app data container, and fails closed on stale/malformed data.
It never uses a simulator. iOS results include thermal and Low Power Mode state.
Both runners alternate which mode launches first and invalidate the run if the
source snapshot or compiled app changes mid-trial. Analyze one platform's JSONL
with `scripts/analyze_native_reconcile.py results.jsonl`; it fails closed unless
provenance, correctness, checksums, pairs, and launch-order rotation agree,
then reports paired bootstrap confidence intervals for the total measured and
native-commit phases. A ±3% band is reported as an indistinguishability guard,
not as a marketing claim.

The bridge export is
`voyager_native_reconcile_benchmark(int frames, const char *commit_mode)`.
Cross-platform absolute times are descriptive, not a CPU-vs-iPhone comparison.

## Results

The verified Mac and physical-iPhone analyses each passed their gates: 15
process-fresh paired measurements per mode after two warmups per mode, with
rotated launch order (8 `all-label-commit` first, 7 `dirty-label-commit`
first). Both compare the versioned `all-label-commit` baseline with the
`dirty-label-commit` path. Every accepted trial reported `success: true` and
the same workload checksum, `12170945312527215007`, across modes; the analysis
therefore reports `gates: passed` for both platforms.

- **Mac:** dirty / baseline total measured time had a median ratio of **0.907**
  (**-9.3%**), with a paired-bootstrap 95% CI of **[0.888, 0.929]**. This is
  meaningful under the ±3% guard. Native-commit time had a median ratio of
  **0.599** (**-40.1%**), 95% CI **[0.577, 0.615]**.
- **Physical iPhone 15 Pro:** dirty / baseline total measured time had a median
  ratio of **0.9780** (**-2.20%**), 95% CI **[0.9695, 0.9826]**. This total result
  is inconclusive: its point estimate is within the ±3% band and its CI spans
  the practical threshold. Native-commit time had a median ratio of **0.6086**
  (**-39.14%**), 95% CI **[0.6037, 0.6202]**: a clear but narrow commit-phase
  result, not a claim about the whole screen.

The iPhone evidence records the Alpha Crystal executable
`/opt/homebrew/Cellar/agent-crystal/HEAD-9c1e8ec/bin/acrystal` and its SHA-256,
an explicit `--mcpu=generic` target profile, and the Boehm artifact SHA-256;
device and signing identifiers are retained only as SHA-256 values so the
accepted evidence is safe to hand to a publication team. The Mac evidence
records a linked
`libgc.1.dylib`. These are public/default-Boehm build-provenance boundaries
only, not evidence for any premium collector configuration or claim. The scope
remains widget build, reconciliation walk, and native-property commit only; it
does not measure full-screen rendering, GPU work, dropped frames, or GC.
