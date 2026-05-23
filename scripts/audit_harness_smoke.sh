#!/usr/bin/env bash
# Phase 6.5 audit harness smoke shim.
#
# Pre-implementation placeholder for `scripts/audit_harness.cr`. The Phase 6.5
# brief's probe cells reference this file so the brief validator's path-existence
# check passes; the Phase 6.5 Implementer either:
#   (a) replaces the shim with a real bash entry point that exec's
#       `crystal-alpha run scripts/audit_harness.cr -- --invariant "$1" --platform "$2" "${@:3}"`, OR
#   (b) deletes the shim entirely and updates the brief's probe cells to call
#       `crystal-alpha run scripts/audit_harness.cr -- ...` directly.
#
# Until then, invoking this shim exits non-zero with a clear message so any
# downstream Validator that runs it knows the harness isn't ready.
#
# Usage (post-implementation):
#   bash scripts/audit_harness_smoke.sh I-3 ios <slug>
# Pre-implementation: exits 2 with the message below.

set -euo pipefail

INVARIANT="${1:-?}"
PLATFORM="${2:-?}"

cat >&2 <<EOM
Phase 6.5 audit harness smoke shim invoked with invariant=$INVARIANT platform=$PLATFORM.

This is a pre-dispatch placeholder. The Phase 6.5 Implementer must replace this
shim with a real entry point that routes the invariant+platform combination to
the appropriate probe per the architecture in
docs/initiative-cross-platform-ui/handoff/planning-retrospective-2026-05-22.md
Section 5.

Exiting 2 (not-implemented) so downstream validators know the harness is not
ready yet. Once Phase 6.5 ships, this shim returns exit 0 on probe pass.
EOM

exit 2
