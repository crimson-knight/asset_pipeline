#!/usr/bin/env python3
"""Physical-iPhone-only evidence runner. It never uses simulators.

Builds a generic arm64 app, signs it for exactly one wired iPhone 15 Pro,
installs it, then collects nonce-bound atomic appDataContainer JSON after each
process-fresh launch. Do not use this script to publish a collector claim:
cross-platform absolute times are explicitly descriptive only.
"""
from __future__ import annotations

import argparse, hashlib, json, os, shutil, subprocess, sys, tempfile, time, uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]; IOS = ROOT / "ios"
BUNDLE = "com.assetpipeline.voyager.VoyagerDemo"
DEVICE_CONTRACT = "asset-pipeline-native-reconcile-device-v1"; RAW_CONTRACT = "asset-pipeline-native-reconcile-v1"
MODES = ("all-label-commit", "dirty-label-commit")

def command(*args: str, cwd=ROOT, env=None, timeout=180) -> str:
    p = subprocess.run(args, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    if p.returncode:
        detail = (p.stdout + "\n" + p.stderr)[-8000:]
        raise RuntimeError(f"{' '.join(args)} failed ({p.returncode}): {detail}")
    return p.stdout
def inspect(*args: str, cwd=ROOT, env=None, timeout=180) -> str:
    p = subprocess.run(args, cwd=cwd, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    if p.returncode: raise RuntimeError(f"{' '.join(args)} failed ({p.returncode}): {p.stderr[-4000:]}")
    return p.stdout + p.stderr

def sha(path: Path) -> str: return hashlib.sha256(path.read_bytes()).hexdigest()
def text_sha(value: str) -> str: return hashlib.sha256(value.encode()).hexdigest()
def tree_sha(path: Path) -> str:
    h = hashlib.sha256()
    for child in sorted(p for p in path.rglob("*") if p.is_file()):
        h.update(str(child.relative_to(path)).encode()); h.update(sha(child).encode())
    return h.hexdigest()
def source_hashes() -> dict[str, str]:
    """Hash every repository input that can affect this benchmark binary.

    The Crystal bridge pulls the sample application and the Asset Pipeline
    source tree transitively. The build also compiles the ObjC trampolines and
    the local Swift package. Hashing only the benchmark entrypoints would let a
    dependency change during a run without invalidating its evidence.
    Generated build products and evidence artifacts are deliberately excluded.
    """
    repo = ROOT.parents[1]
    files: set[Path] = set()

    def add_tree(path: Path, suffixes: set[str]) -> None:
        if not path.exists():
            return
        for candidate in path.rglob("*"):
            if candidate.is_file() and candidate.suffix in suffixes:
                files.add(candidate.resolve())

    add_tree(repo / "src", {".cr", ".c", ".h", ".m", ".mm", ".cc", ".cpp"})
    add_tree(ROOT, {".cr"})
    add_tree(IOS / "Sources", {".swift", ".c", ".h", ".m", ".mm", ".plist"})
    swiftkit = repo / "swift/AssetPipelineSwiftKit"
    add_tree(swiftkit / "Sources", {".swift", ".c", ".h", ".m", ".mm"})
    for explicit in (
        IOS / "bridge.cr",
        IOS / "project.yml",
        IOS / "build_crystal_lib.sh",
        swiftkit / "Package.swift",
        swiftkit / "Package.resolved",
        repo / "shard.yml",
        repo / "shard.lock",
    ):
        if explicit.is_file():
            files.add(explicit.resolve())
    return {str(path.relative_to(repo)): sha(path) for path in sorted(files)}

def public_device_provenance(device: dict) -> dict:
    """Keep the physical-device gates without publishing owner identifiers."""
    hardware = device["hardwareProperties"]
    properties = device["deviceProperties"]
    connection = device["connectionProperties"]
    cpu_types = hardware.get("supportedCPUTypes", [])
    return {
        "identity_hashes": {
            "coredevice_logical_id_sha256": text_sha(device["identifier"]),
            "hardware_udid_sha256": text_sha(hardware["udid"]),
        },
        "hardware": {
            "reality": hardware.get("reality"),
            "marketing_name": hardware.get("marketingName"),
            "product_type": hardware.get("productType"),
            "cpu_type": hardware.get("cpuType", {}).get("name"),
            "supported_cpu_types": [entry.get("name") for entry in cpu_types],
        },
        "software": {
            "os_version": properties.get("osVersionNumber"),
            "os_build": properties.get("osBuildUpdate"),
            "developer_mode": properties.get("developerModeStatus"),
            "boot_state": properties.get("bootState"),
        },
        "connection": {
            "pairing_state": connection.get("pairingState"),
            "transport": connection.get("transportType"),
        },
    }

def device_inventory() -> list[dict]:
    """Return only CoreDevice's top-level device records, never fuzzy matches."""
    with tempfile.NamedTemporaryFile(prefix="voyager-native-devices-", suffix=".json") as output:
        command("xcrun", "devicectl", "list", "devices", "--json-output", output.name, timeout=90)
        return json.loads(Path(output.name).read_text()).get("result", {}).get("devices", [])

def eligible_devices(inventory: list[dict], selector: str | None) -> list[dict]:
    """Strictly select real, wired, ready iPhone 15 Pros from structured fields."""
    candidates = [
        device for device in inventory
        if device.get("hardwareProperties", {}).get("reality") == "physical"
        and device.get("connectionProperties", {}).get("pairingState") == "paired"
        and device.get("connectionProperties", {}).get("transportType") == "wired"
        and device.get("deviceProperties", {}).get("developerModeStatus") == "enabled"
        and device.get("deviceProperties", {}).get("bootState") == "booted"
        and device.get("hardwareProperties", {}).get("marketingName") == "iPhone 15 Pro"
        and device.get("hardwareProperties", {}).get("productType") == "iPhone16,1"
        and isinstance(device.get("identifier"), str)
        and isinstance(device.get("hardwareProperties", {}).get("udid"), str)
        and isinstance(device.get("deviceProperties", {}).get("osVersionNumber"), str)
    ]
    if selector:
        candidates = [
            device for device in candidates
            if selector in {
                device.get("identifier"), device.get("deviceProperties", {}).get("name"),
                device.get("hardwareProperties", {}).get("productType"),
                device.get("hardwareProperties", {}).get("udid"),
            }
        ]
    return candidates

def select_device(selector: str | None) -> tuple[str, str, dict]:
    candidates = eligible_devices(device_inventory(), selector)
    if len(candidates) != 1:
        raise RuntimeError(
            "expected exactly one physical, wired, paired, Developer-Mode-enabled, booted iPhone 15 Pro; "
            f"found {len(candidates)}"
        )
    device = candidates[0]
    # CoreDevice uses this opaque logical ID for devicectl. Xcode destinations
    # instead require the physical hardware UDID; do not interchange them.
    return device["identifier"], device["hardwareProperties"]["udid"], device

def build_and_sign(signing_udid: str, env: dict, derived: Path) -> Path:
    command("bash", "build_crystal_lib.sh", "device", cwd=IOS, env=env, timeout=600)
    command("xcodegen", "generate", cwd=IOS, env=env)
    command("xcodebuild", "build", "-project", "VoyagerDemo.xcodeproj", "-scheme", "VoyagerDemo", "-sdk", "iphoneos", "-destination", f"id={signing_udid}", "-derivedDataPath", str(derived), "-allowProvisioningUpdates", cwd=IOS, env=env, timeout=900)
    app = derived / "Build/Products/Debug-iphoneos/VoyagerDemo.app"
    if not app.is_dir(): raise RuntimeError("signed generic-arm64 app product was not created")
    return app

def evidence_error(result: dict, *, frames: int, mode: str, nonce: str, run_id: str, device: dict) -> str | None:
    expected_ops = frames * (2 if mode == "all-label-commit" else 1)
    expected_os = device["deviceProperties"]["osVersionNumber"]
    expected_model = device["hardwareProperties"]["productType"]
    required = (
        result.get("evidence_contract") == DEVICE_CONTRACT and result.get("contract") == RAW_CONTRACT
        and result.get("launch_nonce") == nonce and result.get("run_id") == run_id
        and result.get("platform") == "ios-device" and result.get("bundle_id") == BUNDLE
        and result.get("success") is True and result.get("commit_mode") == mode
        and result.get("reconcile_ops_total") == expected_ops
        and result.get("structural_label_visits_total") == frames * 2 and result.get("frames") == frames
        and result.get("device_model") == expected_model and result.get("os_version") == expected_os
        and result.get("thermal_state_before") == "nominal" and result.get("thermal_state_after") == "nominal"
        and result.get("low_power_mode_before") is False and result.get("low_power_mode_after") is False
    )
    return None if required else f"invalid/stale/non-nominal device result: {result}"

def main() -> int:
    ap = argparse.ArgumentParser(); ap.add_argument("--device-id"); ap.add_argument("--frames", type=int, default=600); ap.add_argument("--warmups", type=int, default=2); ap.add_argument("--trials", type=int, default=15); ap.add_argument("--output", type=Path); ns = ap.parse_args()
    if ns.frames <= 0 or min(ns.warmups, ns.trials) < 0: raise SystemExit("invalid frame/trial count")
    device, signing_udid, device_info = select_device(ns.device_id); run_id = f"ios-{uuid.uuid4()}"; output = (ns.output or ROOT/"artifacts/native-reconcile"/run_id/"results.jsonl").resolve(); output.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy() | {"CRYSTAL_CACHE_DIR":"/tmp/asset_pipeline_crystal_cache", "CLANG_MODULE_CACHE_PATH":"/tmp/asset_pipeline_clang_modules", "SWIFTPM_MODULECACHE_OVERRIDE":"/tmp/asset_pipeline_swift_modules", "CRYSTAL_MCPU":"generic"}
    compiler_lookup = shutil.which("crystal-alpha", path=env.get("PATH"))
    if compiler_lookup is None:
        raise RuntimeError("crystal-alpha is required for Alpha-Crystal evidence")
    compiler_path = Path(compiler_lookup).resolve()
    env["CRYSTAL"] = str(compiler_path)
    before = source_hashes(); app = build_and_sign(signing_udid, env, output.parent/"DerivedData")
    if before != source_hashes(): raise RuntimeError("source changed during build; refusing mismatched evidence")
    codesign_details = inspect("codesign", "-dvv", str(app), timeout=60)
    command("codesign", "--verify", "--deep", "--strict", str(app), timeout=60)
    provenance = {"source_hashes": before, "app_executable_sha256": sha(app/"VoyagerDemo"), "app_bundle_sha256": tree_sha(app), "bridge_archive_sha256": sha(IOS/"build/libvoyager_device.a"), "boehm_sha256": sha(Path("/tmp/crystal-cross-deps/ios-device/lib/libgc.a")), "codesign_verified":True, "codesign_details_sha256":text_sha(codesign_details), "compiler": command(str(compiler_path),"--version").strip(), "compiler_executable":str(compiler_path), "compiler_executable_sha256":sha(compiler_path), "crystal_target":"arm64-apple-ios", "crystal_mcpu":env["CRYSTAL_MCPU"], "xcode": command("xcodebuild","-version").strip(), "coredevice_logical_id_sha256":text_sha(device), "xcode_hardware_udid_sha256":text_sha(signing_udid), "device":public_device_provenance(device_info), "git_commit":command("git","rev-parse","HEAD").strip(), "git_dirty":bool(command("git","status","--porcelain").strip())}
    command("xcrun", "devicectl", "device", "install", "app", "--device", device, str(app), timeout=180)
    checksums: dict[str, int] = {}
    app_bundle_sha = provenance["app_bundle_sha256"]
    with output.open("x") as fh:
      for ordinal in range(ns.warmups + ns.trials):
       modes = MODES if ordinal % 2 == 0 else tuple(reversed(MODES))
       for rotation_position, mode in enumerate(modes):
        if source_hashes() != before or tree_sha(app) != app_bundle_sha:
            raise RuntimeError("source or signed app changed during trials; evidence invalid")
        nonce = uuid.uuid4().hex; trial_dir = output.parent/"device-results"; trial_dir.mkdir(exist_ok=True); local = trial_dir/f"{nonce}.json"
        launch_env = json.dumps({"VOYAGER_NATIVE_RECONCILE_BENCH_FRAMES":str(ns.frames), "VOYAGER_NATIVE_RECONCILE_COMMIT_MODE":mode, "VOYAGER_NATIVE_RECONCILE_LAUNCH_NONCE":nonce, "VOYAGER_NATIVE_RECONCILE_RUN_ID":run_id})
        started = time.time_ns(); command("xcrun","devicectl","device","process","launch","--device",device,"--terminate-existing","--console","--timeout","90","--environment-variables",launch_env,BUNDLE, timeout=120)
        command("xcrun","devicectl","device","copy","from","--device",device,"--domain-type","appDataContainer","--domain-identifier",BUNDLE,"--source",f"Documents/native-reconcile-results/{nonce}.json","--destination",str(local), timeout=90)
        result = json.loads(local.read_text())
        if error := evidence_error(result, frames=ns.frames, mode=mode, nonce=nonce, run_id=run_id, device=device_info): raise RuntimeError(error)
        if mode in checksums and result["checksum"] != checksums[mode]: raise RuntimeError("checksum drift across process-fresh device trials")
        checksums[mode]=result["checksum"]
        fh.write(json.dumps({"schema":1,"run_id":run_id,"platform":"ios-device","trial_kind":"warmup" if ordinal<ns.warmups else "measured","ordinal":ordinal,"pair_index":ordinal,"rotation_position":rotation_position,"process_fresh":True,"host_elapsed_ns":time.time_ns()-started,"absolute_times_descriptive_only":True,"provenance":provenance,"result":result},sort_keys=True)+"\n")
    print(output); return 0

if __name__ == "__main__":
 try: raise SystemExit(main())
 except Exception as exc: print(f"FAIL-CLOSED: {exc}", file=sys.stderr); raise SystemExit(1)
