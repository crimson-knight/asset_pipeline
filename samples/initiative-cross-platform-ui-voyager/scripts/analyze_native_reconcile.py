#!/usr/bin/env python3
"""Fail-closed paired analysis for Voyager native-reconciliation JSONL.

Reports only within-platform baseline-versus-dirty comparisons. It rejects
mixed provenance, bad correctness gates, checksum drift, missing pairs, and an
unbalanced rotation before calculating paired bootstrap median-ratio intervals.
"""
from __future__ import annotations

import argparse, json, math, random, statistics, sys
from collections import Counter, defaultdict
from pathlib import Path

BASELINE = "all-label-commit"; DIRTY = "dirty-label-commit"
RAW_CONTRACT = "asset-pipeline-native-reconcile-v1"

def percentile(values, p):
    values = sorted(values); index = (len(values)-1)*p; lo = math.floor(index); hi = math.ceil(index)
    return values[lo] if lo == hi else values[lo] + (values[hi]-values[lo])*(index-lo)

def key_provenance(row):
    p = row["provenance"]
    # Fields common to Mac/iOS. Device conditions intentionally vary per trial
    # and live inside result; source/compiler/runtime/app must not.
    return json.dumps({k:p.get(k) for k in ("source_hashes","app_sha256","app_bundle_sha256","app_executable_sha256","bridge_archive_sha256","boehm_sha256","compiler","compiler_executable","compiler_executable_sha256","crystal_target","crystal_mcpu","xcode","git_commit","codesign_verified","codesign_details_sha256","coredevice_logical_id","xcode_hardware_udid","device_discovery","coredevice_logical_id_sha256","xcode_hardware_udid_sha256","device")}, sort_keys=True)

def fail(message): raise RuntimeError(message)

def sha256_string(value):
    return isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value)

def ios_device_identity(provenance):
    """Read either retained private audit provenance or public-safe evidence."""
    private = provenance.get("device_discovery")
    if isinstance(private, dict):
        return (
            private.get("hardwareProperties", {}).get("productType"),
            private.get("deviceProperties", {}).get("osVersionNumber"),
        )
    public = provenance.get("device")
    if not isinstance(public, dict):
        fail("iOS device provenance is missing")
    hardware = public.get("hardware", {})
    software = public.get("software", {})
    connection = public.get("connection", {})
    hashes = public.get("identity_hashes", {})
    if not (
        hardware.get("reality") == "physical"
        and hardware.get("marketing_name") == "iPhone 15 Pro"
        and hardware.get("product_type") == "iPhone16,1"
        and connection.get("pairing_state") == "paired"
        and connection.get("transport") == "wired"
        and software.get("developer_mode") == "enabled"
        and software.get("boot_state") == "booted"
        and sha256_string(hashes.get("coredevice_logical_id_sha256"))
        and sha256_string(hashes.get("hardware_udid_sha256"))
        and sha256_string(provenance.get("coredevice_logical_id_sha256"))
        and sha256_string(provenance.get("xcode_hardware_udid_sha256"))
        and provenance.get("codesign_verified") is True
        and sha256_string(provenance.get("codesign_details_sha256"))
        and provenance.get("crystal_target") == "arm64-apple-ios"
        and provenance.get("crystal_mcpu") == "generic"
    ):
        fail("public iOS device/signing/target provenance gate failed")
    return hardware.get("product_type"), software.get("os_version")

def validate(rows):
    if not rows: fail("empty JSONL")
    platforms = {r.get("platform") for r in rows}
    if len(platforms) != 1 or None in platforms: fail("input must contain exactly one named platform")
    platform = next(iter(platforms))
    if any(not r.get("absolute_times_descriptive_only") for r in rows): fail("missing descriptive-only platform guard")
    if any(not r.get("process_fresh") for r in rows): fail("non-fresh process trial present")
    if len({key_provenance(r) for r in rows}) != 1: fail("mixed source/compiler/runtime/app provenance")
    checksums = defaultdict(set)
    for r in rows:
        v = r.get("result", {}); mode = v.get("commit_mode"); frames = v.get("frames")
        expected = frames * (2 if mode == BASELINE else 1) if isinstance(frames, int) else None
        if not (v.get("success") is True and v.get("contract") == RAW_CONTRACT and mode in (BASELINE, DIRTY) and v.get("reconcile_ops_total") == expected and v.get("structural_label_visits_total") == frames*2): fail(f"correctness gate failed: {v}")
        if platform == "ios-device":
            expected_model, expected_os = ios_device_identity(r["provenance"])
            if not (
                v.get("evidence_contract") == "asset-pipeline-native-reconcile-device-v1"
                and v.get("bundle_id") == "com.assetpipeline.voyager.VoyagerDemo"
                and v.get("device_model") == "iPhone16,1" == expected_model
                and v.get("os_version") == expected_os
                and v.get("thermal_state_before") == "nominal" and v.get("thermal_state_after") == "nominal"
                and v.get("low_power_mode_before") is False and v.get("low_power_mode_after") is False
                and isinstance(v.get("launch_nonce"), str)
            ): fail("iOS environment/device-identity gate failed")
        checksums[mode].add(v.get("checksum"))
    if any(len(v) != 1 for v in checksums.values()) or set(checksums) != {BASELINE,DIRTY}: fail("checksum drift or missing mode")
    # The benchmark identity has an intentionally mode-independent checksum.
    if next(iter(checksums[BASELINE])) != next(iter(checksums[DIRTY])): fail("baseline and dirty workloads do not match")
    return platform

def paired(rows, metric):
    measured = [r for r in rows if r.get("trial_kind") == "measured"]
    groups = defaultdict(dict)
    for r in measured:
        pair = r.get("pair_index")
        if not isinstance(pair, int) or r.get("rotation_position") not in (0,1): fail("missing pair/rotation metadata")
        mode = r["result"]["commit_mode"]
        if mode in groups[pair]: fail("duplicate mode in pair")
        groups[pair][mode] = r
    if not groups or any(set(v) != {BASELINE,DIRTY} for v in groups.values()): fail("incomplete measured pairs")
    first = Counter(next(mode for mode,row in pair.items() if row["rotation_position"] == 0) for pair in groups.values())
    if abs(first[BASELINE]-first[DIRTY]) > 1: fail(f"rotation imbalance: {dict(first)}")
    ratios = []
    for pair in groups.values():
        base = pair[BASELINE]["result"]; dirty = pair[DIRTY]["result"]
        b = sum(base[k] for k in ("build_ns_total","diff_ns_total","commit_ns_total")) if metric == "total_measured_phase" else base["commit_ns_total"]
        d = sum(dirty[k] for k in ("build_ns_total","diff_ns_total","commit_ns_total")) if metric == "total_measured_phase" else dirty["commit_ns_total"]
        if b <= 0 or d <= 0: fail("non-positive timing")
        ratios.append(d/b)
    rng = random.Random(20260813); samples=[]
    for _ in range(20000): samples.append(statistics.median(rng.choice(ratios) for _ in ratios))
    median = statistics.median(ratios); ci=[percentile(samples,.025), percentile(samples,.975)]
    return {"n_pairs":len(ratios),"dirty_over_baseline_median_ratio":median,"bootstrap_95pct_ci":ci,"median_change_pct":(median-1)*100,"within_plus_minus_3pct_band":.97 <= median <= 1.03,"ci_entirely_within_plus_minus_3pct_band":.97 <= ci[0] and ci[1] <= 1.03,"rotation_first_counts":dict(first)}

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("results",type=Path); ap.add_argument("--output",type=Path); ns=ap.parse_args()
    rows=[json.loads(line) for line in ns.results.read_text().splitlines() if line.strip()]
    platform=validate(rows)
    report={"schema":1,"platform":platform,"absolute_platform_comparisons_descriptive_only":True,"input":str(ns.results),"gates":"passed","metrics":{"total_measured_phase":paired(rows,"total_measured_phase"),"commit_phase":paired(rows,"commit_phase")}}
    rendered=json.dumps(report,indent=2,sort_keys=True)
    if ns.output: ns.output.write_text(rendered+"\n")
    print(rendered)

if __name__ == "__main__":
    try: main()
    except Exception as exc: print(f"FAIL-CLOSED: {exc}",file=sys.stderr); raise SystemExit(1)
