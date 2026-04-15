#!/usr/bin/env python3
"""Audit HIG validation screenshot evidence.

The validation loop is only trustworthy when a report evaluates the exact PNGs
currently linked from it. This script checks that relationship and can write a
small evidence manifest containing screenshot hashes, mtimes, sizes, and pixel
dimensions.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


VALIDATION_ROOT = Path(__file__).resolve().parent
REPORTS_DIR = VALIDATION_ROOT / "reports"
SCREENSHOTS_DIR = VALIDATION_ROOT / "screenshots"
EVIDENCE_DIR = VALIDATION_ROOT / "evidence"
WORKLIST_PATH = VALIDATION_ROOT / "worklist.json"
REQUIRED_PLATFORMS = ("macos", "ios")
REQUIRED_APPEARANCES = ("light", "dark")
MIN_SCREENSHOT_BYTES = 10 * 1024
MTIME_TOLERANCE_SECONDS = 1.0


def iso_from_mtime(path: Path) -> str:
    return datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def png_dimensions(path: Path) -> tuple[int, int] | None:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return struct.unpack(">II", header[16:24])


def screenshot_name(slug: str, platform: str, appearance: str) -> str:
    return f"{slug}-{platform}-{appearance}.png"


def load_worklist() -> dict[str, Any]:
    with WORKLIST_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def iter_rows(worklist: dict[str, Any], slug: str | None, include_pending: bool) -> list[dict[str, Any]]:
    rows = []
    for row in worklist.get("pages", []):
        if row.get("role") != "component":
            continue
        if slug and row.get("slug") != slug:
            continue
        if not include_pending and row.get("validation_state") not in ("pass", "pass_with_notes"):
            continue
        rows.append(row)
    return rows


def audit_row(row: dict[str, Any]) -> dict[str, Any]:
    slug = row["slug"]
    errors: list[str] = []
    warnings: list[str] = []
    report_path = REPORTS_DIR / f"{slug}.md"

    report: dict[str, Any] = {
        "path": str(report_path.relative_to(VALIDATION_ROOT)),
        "exists": report_path.exists(),
    }
    report_text = ""
    report_mtime = None
    if report_path.exists():
        report_mtime = report_path.stat().st_mtime
        report.update(
            {
                "size_bytes": report_path.stat().st_size,
                "mtime": iso_from_mtime(report_path),
                "sha256": sha256(report_path),
            }
        )
        report_text = report_path.read_text(encoding="utf-8")
    else:
        errors.append(f"missing report: {report_path}")

    screenshots: dict[str, Any] = {}
    for platform in REQUIRED_PLATFORMS:
        for appearance in REQUIRED_APPEARANCES:
            name = screenshot_name(slug, platform, appearance)
            key = f"{platform}_{appearance}"
            path = SCREENSHOTS_DIR / name
            item: dict[str, Any] = {
                "path": str(path.relative_to(VALIDATION_ROOT)),
                "exists": path.exists(),
            }
            if not path.exists():
                errors.append(f"missing screenshot: {name}")
                screenshots[key] = item
                continue

            size = path.stat().st_size
            item["size_bytes"] = size
            item["mtime"] = iso_from_mtime(path)
            item["sha256"] = sha256(path)
            dims = png_dimensions(path)
            if dims:
                item["pixel_width"], item["pixel_height"] = dims
            else:
                errors.append(f"not a readable PNG: {name}")

            if size < MIN_SCREENSHOT_BYTES:
                errors.append(f"screenshot under {MIN_SCREENSHOT_BYTES} bytes: {name} ({size})")

            if report_mtime is not None and path.stat().st_mtime > report_mtime + MTIME_TOLERANCE_SECONDS:
                errors.append(f"screenshot newer than report: {name}")

            if report_text and name not in report_text:
                errors.append(f"report does not link required screenshot: {name}")

            screenshots[key] = item

    if report_text:
        for legacy_name in (f"{slug}-macos.png", f"{slug}-ios.png"):
            if legacy_name in report_text:
                errors.append(f"report still links legacy two-capture screenshot: {legacy_name}")
        if "../screenshots/" not in report_text:
            warnings.append("report contains no screenshot links")

    return {
        "slug": slug,
        "validation_state": row.get("validation_state"),
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "valid": not errors,
        "errors": errors,
        "warnings": warnings,
        "report": report,
        "screenshots": screenshots,
    }


def write_manifest(result: dict[str, Any]) -> None:
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    path = EVIDENCE_DIR / f"{result['slug']}.json"
    path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def requeue_invalid(worklist: dict[str, Any], results: list[dict[str, Any]]) -> None:
    invalid_by_slug = {result["slug"]: result for result in results if not result["valid"]}
    if not invalid_by_slug:
        return

    for row in worklist.get("pages", []):
        result = invalid_by_slug.get(row.get("slug"))
        if not result:
            continue
        if row.get("validation_state") not in ("pass", "pass_with_notes"):
            continue
        row["validation_state"] = "pending"
        row["evidence_state"] = "invalid"
        row["evidence_errors"] = result["errors"]
        row["remediation_hint"] = "Evidence audit failed; regenerate all four screenshots, report, and evidence manifest before design-critic review."

    WORKLIST_PATH.write_text(json.dumps(worklist, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slug", help="Audit a single slug")
    parser.add_argument("--include-pending", action="store_true", help="Also audit pending/skipped component rows")
    parser.add_argument("--write-manifest", action="store_true", help="Write validation/evidence/<slug>.json")
    parser.add_argument("--json", action="store_true", help="Print JSON results")
    parser.add_argument("--requeue-invalid", action="store_true", help="Set invalid pass/pass_with_notes rows back to pending")
    args = parser.parse_args(argv)

    worklist = load_worklist()
    rows = iter_rows(worklist, args.slug, args.include_pending)
    if args.slug and not rows:
        print(f"No component row found for slug: {args.slug}", file=sys.stderr)
        return 2

    results = [audit_row(row) for row in rows]
    if args.write_manifest:
        for result in results:
            write_manifest(result)
    if args.requeue_invalid:
        requeue_invalid(worklist, results)

    invalid = [result for result in results if not result["valid"]]

    if args.json:
        print(json.dumps(results, indent=2, sort_keys=True))
    else:
        print(f"audited={len(results)} invalid={len(invalid)}")
        for result in invalid:
            print(f"INVALID {result['slug']}")
            for error in result["errors"][:8]:
                print(f"  - {error}")
            remaining = len(result["errors"]) - 8
            if remaining > 0:
                print(f"  - ... {remaining} more")

    return 1 if invalid else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
