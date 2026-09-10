import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "run_native_reconcile_ios.py"
SPEC = importlib.util.spec_from_file_location("voyager_ios_runner", SCRIPT)
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)

def device(**overrides):
    value = {
        "identifier": "coredevice-logical-id",
        "hardwareProperties": {"reality": "physical", "marketingName": "iPhone 15 Pro", "productType": "iPhone16,1", "udid": "hardware-udid"},
        "connectionProperties": {"pairingState": "paired", "transportType": "wired"},
        "deviceProperties": {"developerModeStatus": "enabled", "bootState": "booted", "osVersionNumber": "26.5"},
    }
    for section, changes in overrides.items(): value[section].update(changes)
    return value

def result(**changes):
    value = {
        "evidence_contract": runner.DEVICE_CONTRACT, "contract": runner.RAW_CONTRACT,
        "launch_nonce": "a" * 32, "run_id": "run", "platform": "ios-device", "bundle_id": runner.BUNDLE,
        "success": True, "commit_mode": "dirty-label-commit", "reconcile_ops_total": 12,
        "structural_label_visits_total": 24, "frames": 12, "device_model": "iPhone16,1", "os_version": "26.5",
        "thermal_state_before": "nominal", "thermal_state_after": "nominal",
        "low_power_mode_before": False, "low_power_mode_after": False,
    }
    value.update(changes); return value

class IOSRunnerTests(unittest.TestCase):
    def test_selects_structured_device_and_keeps_logical_and_hardware_ids_separate(self):
        eligible = runner.eligible_devices([device()], None)
        self.assertEqual(eligible[0]["identifier"], "coredevice-logical-id")
        self.assertEqual(eligible[0]["hardwareProperties"]["udid"], "hardware-udid")

    def test_rejects_nonphysical_or_nonready_devices(self):
        for section, changes in (("hardwareProperties", {"reality": "simulator"}), ("connectionProperties", {"transportType": "wireless"}), ("deviceProperties", {"developerModeStatus": "disabled"}), ("deviceProperties", {"bootState": "shutdown"})):
            self.assertEqual(runner.eligible_devices([device(**{section: changes})], None), [])

    def test_result_requires_nominal_device_conditions_and_exact_identity(self):
        self.assertIsNone(runner.evidence_error(result(), frames=12, mode="dirty-label-commit", nonce="a" * 32, run_id="run", device=device()))
        self.assertIsNotNone(runner.evidence_error(result(thermal_state_after="fair"), frames=12, mode="dirty-label-commit", nonce="a" * 32, run_id="run", device=device()))
        self.assertIsNotNone(runner.evidence_error(result(low_power_mode_before=True), frames=12, mode="dirty-label-commit", nonce="a" * 32, run_id="run", device=device()))
        self.assertIsNotNone(runner.evidence_error(result(bundle_id="wrong"), frames=12, mode="dirty-label-commit", nonce="a" * 32, run_id="run", device=device()))

    def test_public_device_provenance_hashes_owner_identifiers(self):
        source = device()
        source["hardwareProperties"]["serialNumber"] = "private-serial"
        public = runner.public_device_provenance(source)
        encoded = str(public)
        self.assertNotIn("private-serial", encoded)
        self.assertNotIn("hardware-udid", encoded)
        self.assertNotIn("coredevice-logical-id", encoded)
        self.assertEqual("iPhone 15 Pro", public["hardware"]["marketing_name"])
        self.assertEqual(64, len(public["identity_hashes"]["hardware_udid_sha256"]))

if __name__ == "__main__": unittest.main()
