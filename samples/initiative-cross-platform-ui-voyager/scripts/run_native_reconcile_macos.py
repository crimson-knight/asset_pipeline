#!/usr/bin/env python3
"""Fail-closed, process-fresh evidence runner for the Voyager macOS lane.

Absolute macOS/iOS times are descriptive only. This runner compares the
versioned all-label baseline and dirty-label production path on the same app,
same source snapshot, same compiler/runtime, and records one JSON object per
process launch in JSONL.
"""
from __future__ import annotations

import argparse, hashlib, json, os, platform, subprocess, sys, time, uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BIN = ROOT / "macos/bin/voyager"
CONTRACT = "asset-pipeline-native-reconcile-v1"
MODES = ("all-label-commit", "dirty-label-commit")

def run(*args: str, env=None) -> str:
    completed = subprocess.run(args, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if completed.returncode:
        raise RuntimeError(f"{' '.join(args)} failed ({completed.returncode}): {completed.stderr[-3000:]}")
    return completed.stdout

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def inputs() -> dict[str, str]:
    repo = ROOT.parents[1]
    files: set[Path] = set()

    def add_tree(path: Path, suffixes: set[str]) -> None:
        if not path.exists():
            return
        for candidate in path.rglob("*"):
            if candidate.is_file() and candidate.suffix in suffixes:
                files.add(candidate.resolve())

    # Mirror the actual Makefile inputs: all transitive Crystal application
    # and renderer sources, ObjC bridge/window helpers, and the local SwiftKit
    # package. Generated objects, binaries, and SwiftPM build products remain
    # excluded because their compiled hashes are recorded separately.
    add_tree(repo / "src", {".cr", ".c", ".h", ".m", ".mm", ".cc", ".cpp"})
    add_tree(ROOT, {".cr"})
    add_tree(repo / "swift/AssetPipelineSwiftKit/Sources", {".swift", ".c", ".h", ".m", ".mm"})
    for explicit in (
        ROOT / "Makefile",
        repo / "swift/AssetPipelineSwiftKit/Package.swift",
        repo / "swift/AssetPipelineSwiftKit/Package.resolved",
        repo / "samples/cross_platform/macos_host/window_helper.m",
        repo / "shard.yml",
        repo / "shard.lock",
    ):
        if explicit.is_file():
            files.add(explicit.resolve())
    return {str(path.relative_to(repo)): digest(path) for path in sorted(files)}

def metadata() -> dict:
    return {
        "source_hashes": inputs(), "app_sha256": digest(BIN),
        "compiler": run("crystal-alpha", "--version").strip(),
        "xcode": run("xcodebuild", "-version").strip(),
        "host_os": platform.platform(), "host_machine": platform.machine(),
        "runtime": {"linked": run("otool", "-L", str(BIN)).strip()},
        "git_commit": run("git", "rev-parse", "HEAD").strip(),
        "git_dirty": bool(run("git", "status", "--porcelain").strip()),
    }

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--frames", type=int, default=600)
    parser.add_argument("--warmups", type=int, default=2)
    parser.add_argument("--trials", type=int, default=15)
    parser.add_argument("--output", type=Path)
    ns = parser.parse_args()
    if min(ns.frames, ns.warmups, ns.trials) < 0 or ns.frames == 0:
        raise SystemExit("frames must be positive; warmups/trials must be non-negative")
    source_before = inputs()
    cache = os.environ.copy(); cache["CRYSTAL_CACHE_DIR"] = "/tmp/asset_pipeline_crystal_cache"
    run("make", "macos", env=cache)
    if source_before != inputs():
        raise RuntimeError("source changed during build; refusing mismatched evidence")
    run_id = f"macos-{uuid.uuid4()}"
    output = ns.output or ROOT / "artifacts/native-reconcile" / run_id / "results.jsonl"
    output.parent.mkdir(parents=True, exist_ok=True)
    base = metadata(); expected_checksum: dict[str, int] = {}
    with output.open("x") as fh:
        for ordinal in range(ns.warmups + ns.trials):
            # Alternate first-run order to make a systematic launch-order or
            # thermal drift visible instead of assigning it to one mode.
            modes = MODES if ordinal % 2 == 0 else tuple(reversed(MODES))
            for rotation_position, mode in enumerate(modes):
                if inputs() != source_before or digest(BIN) != base["app_sha256"]:
                    raise RuntimeError("source or app changed during trials; evidence invalid")
                env = cache | {"VOYAGER_NATIVE_RECONCILE_BENCH_FRAMES": str(ns.frames), "VOYAGER_NATIVE_RECONCILE_COMMIT_MODE": mode}
                started = time.time_ns()
                raw = run(str(BIN), env=env).strip()
                try: result = json.loads(raw)
                except json.JSONDecodeError as exc: raise RuntimeError(f"non-JSON benchmark output: {raw[-1000:]}") from exc
                expected_ops = ns.frames * (2 if mode == "all-label-commit" else 1)
                if not (result.get("success") is True and result.get("contract") == CONTRACT and result.get("commit_mode") == mode and result.get("reconcile_ops_total") == expected_ops and result.get("structural_label_visits_total") == ns.frames * 2):
                    raise RuntimeError(f"invalid benchmark evidence: {result}")
                checksum = result.get("checksum")
                if mode in expected_checksum and checksum != expected_checksum[mode]: raise RuntimeError("checksum drift across identical process-fresh trials")
                expected_checksum[mode] = checksum
                fh.write(json.dumps({"schema": 1, "run_id": run_id, "platform": "macos-native", "trial_kind": "warmup" if ordinal < ns.warmups else "measured", "ordinal": ordinal, "pair_index": ordinal, "rotation_position": rotation_position, "process_fresh": True, "host_elapsed_ns": time.time_ns()-started, "absolute_times_descriptive_only": True, "provenance": base, "result": result}, sort_keys=True) + "\n")
    print(output)
    return 0

if __name__ == "__main__":
    try: raise SystemExit(main())
    except Exception as exc:
        print(f"FAIL-CLOSED: {exc}", file=sys.stderr); raise SystemExit(1)
