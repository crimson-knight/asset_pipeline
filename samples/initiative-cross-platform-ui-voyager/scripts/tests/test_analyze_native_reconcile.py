import importlib.util
from pathlib import Path
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "analyze_native_reconcile.py"
SPEC = importlib.util.spec_from_file_location("voyager_native_analyzer", SCRIPT)
analyzer = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(analyzer)


def provenance():
    digest = "a" * 64
    return {
        "codesign_verified": True,
        "codesign_details_sha256": digest,
        "coredevice_logical_id_sha256": digest,
        "xcode_hardware_udid_sha256": digest,
        "crystal_target": "arm64-apple-ios",
        "crystal_mcpu": "generic",
        "device": {
            "identity_hashes": {
                "coredevice_logical_id_sha256": digest,
                "hardware_udid_sha256": digest,
            },
            "hardware": {
                "reality": "physical",
                "marketing_name": "iPhone 15 Pro",
                "product_type": "iPhone16,1",
            },
            "software": {
                "os_version": "26.5.2",
                "developer_mode": "enabled",
                "boot_state": "booted",
            },
            "connection": {"pairing_state": "paired", "transport": "wired"},
        },
    }


class NativeReconcileAnalyzerTests(unittest.TestCase):
    def test_accepts_public_safe_physical_device_provenance(self):
        self.assertEqual(("iPhone16,1", "26.5.2"), analyzer.ios_device_identity(provenance()))

    def test_rejects_invalid_public_identity_hash(self):
        value = provenance()
        value["device"]["identity_hashes"]["hardware_udid_sha256"] = "raw-device-id"
        with self.assertRaisesRegex(RuntimeError, "public iOS device/signing/target provenance gate failed"):
            analyzer.ios_device_identity(value)


if __name__ == "__main__":
    unittest.main()
