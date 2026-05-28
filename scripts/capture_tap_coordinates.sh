#!/usr/bin/env bash
# scripts/capture_tap_coordinates.sh
#
# Guided helper for capturing tap coordinates for the interaction-contracts
# harness. Used when a demo-app screen layout changes (which invalidates
# the existing coordinate map per source-hash freshness gate).
#
# Inputs (env):
#   APIC_DEVICE   — simulator device name (default: "iPhone 17 Pro")
#   APIC_RUNTIME  — runtime version (default: "iOS 26.5")
#   APIC_SCENARIO — scenario YAML path (e.g. spec/native_ios/ui_interaction/scenarios/voyager.yml)
#
# Workflow:
#   1. Boot the simulator.
#   2. Install the demo app (caller must have built the .app bundle).
#   3. Launch the app and pause on the screen we need to capture.
#   4. For each placeholder coordinate in the scenario, the operator
#      taps the element in the simulator using the host mouse, the
#      script grabs the (x,y) from the simulator's pointer log, and
#      writes it back to the YAML with captured: true.
#
# This is a thin helper around `xcrun simctl io` and `cliclick` — neither
# of which expose accessibility-identifier-based tap. Until the URL-scheme
# query mechanism lands (Phase 12.B follow-up), this is the honest path
# for keeping coordinates current.

set -euo pipefail

APIC_DEVICE="${APIC_DEVICE:-iPhone 17 Pro}"
APIC_RUNTIME="${APIC_RUNTIME:-iOS 26.5}"
APIC_SCENARIO="${APIC_SCENARIO:-spec/native_ios/ui_interaction/scenarios/voyager.yml}"

if [[ ! -f "$APIC_SCENARIO" ]]; then
  echo "FATAL: scenario file $APIC_SCENARIO does not exist" >&2
  exit 1
fi

echo "==> Capture tap coordinates for $APIC_SCENARIO"
echo "    Device:   $APIC_DEVICE"
echo "    Runtime:  $APIC_RUNTIME"
echo ""
echo "Prerequisites:"
echo "  1. Simulator booted with $APIC_DEVICE / $APIC_RUNTIME"
echo "  2. Demo app installed and visible on the screen you want to capture"
echo "  3. The screen state matches the scenario's expected pose (sign-in"
echo "     screen for sign-in IDs, todos screen for todos IDs, etc.)"
echo ""
echo "For each placeholder id in the scenario, this script will:"
echo "  - Show the id + description"
echo "  - Wait for you to position the simulator pointer on the element"
echo "  - On <Enter>, capture the current cursor (x, y)"
echo "  - Update the YAML with the captured coordinate"
echo ""
echo "Press <Enter> to begin, or Ctrl+C to abort."
read -r

# Extract placeholder ids from the YAML (entries with captured: false).
PLACEHOLDERS=$(grep -B 3 "captured: false" "$APIC_SCENARIO" | grep "^  - id:" | sed 's/.*id: "\(.*\)".*/\1/')

if [[ -z "$PLACEHOLDERS" ]]; then
  echo "No placeholders found. Scenario is fully captured."
  exit 0
fi

echo "$PLACEHOLDERS" | while IFS= read -r id; do
  echo "==> Capturing: $id"
  # Pull the description for this id.
  desc=$(grep -A 1 "id: \"$id\"" "$APIC_SCENARIO" | grep "description:" | sed 's/.*description: "\(.*\)".*/\1/' || true)
  if [[ -n "$desc" ]]; then
    echo "    Description: $desc"
  fi
  echo "    Position pointer on the element in the simulator, then press <Enter>."
  read -r
  # cliclick p prints current cursor position as "X,Y" (requires cliclick).
  if ! command -v cliclick >/dev/null 2>&1; then
    echo "FATAL: cliclick not installed. Run: brew install cliclick" >&2
    exit 1
  fi
  pos=$(cliclick p)
  x=$(echo "$pos" | cut -d, -f1)
  y=$(echo "$pos" | cut -d, -f2)
  echo "    Captured: ($x, $y)"

  # Update YAML in-place. This is a coarse sed — assumes the placeholder
  # block matches the structure we wrote. For robustness, a Crystal-side
  # YAML round-trip would be cleaner; Phase 12.B follow-up.
  python3 -c "
import sys
import re
path = '$APIC_SCENARIO'
target_id = '$id'
new_x, new_y = $x, $y
with open(path) as f:
    content = f.read()
pattern = re.compile(
    r'(- id: \"' + re.escape(target_id) + r'\"\n)'
    r'(    x: )-?\d+(\n)'
    r'(    y: )-?\d+(\n)'
    r'(    description: \".*?\"\n)'
    r'(    captured: )false',
    re.DOTALL
)
def repl(m):
    return (m.group(1) + m.group(2) + str(new_x) + m.group(3) +
            m.group(4) + str(new_y) + m.group(5) + m.group(6) +
            m.group(7) + 'true')
content2 = pattern.sub(repl, content)
with open(path, 'w') as f:
    f.write(content2)
"
  echo "    Wrote to $APIC_SCENARIO"
done

echo ""
echo "==> Capture complete."
echo "    Run: crystal spec spec/native_ios/ui_interaction/ -Dios"
echo "    to exercise the contracts against the new coordinates."
