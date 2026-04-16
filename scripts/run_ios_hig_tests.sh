#!/usr/bin/env bash
# run_ios_hig_tests.sh
#
# Orchestrates the iOS HIG visual-validation loop:
#
#   1. Ensure xcodegen is installed
#   2. Build libhighost.a (Crystal static lib for iOS simulator)
#   3. Generate CrystalHIGHost.xcodeproj via xcodegen
#   4. For each component slug (or --only <slug>):
#        a. xcodebuild test -only-testing:CrystalHIGHostUITests/HIGVisualTests/testRenderSlug
#        b. extract the "<slug>-ios.png" attachment from the xcresult bundle
#        c. write to .claude/skills/apple-platform-guide/validation/screenshots/<slug>-ios.png
#
# Prerequisites:
#   - xcodegen (brew install xcodegen)
#   - jq (brew install jq) -- for parsing xcresult attachment manifests
#   - Xcode with iOS 26 simulator SDK
#
# Usage:
#   ./scripts/run_ios_hig_tests.sh                  # all component slugs
#   ./scripts/run_ios_hig_tests.sh --only buttons   # one slug

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
IOS_DIR="$PROJECT_ROOT/samples/cross_platform/ios_host"
WORKLIST="$PROJECT_ROOT/.claude/skills/apple-platform-guide/validation/worklist.json"
SCREENSHOT_DIR="$PROJECT_ROOT/.claude/skills/apple-platform-guide/validation/screenshots"
XCRESULT_DIR="$IOS_DIR/build/xcresults"

ONLY_SLUG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --only) ONLY_SLUG="$2"; shift 2 ;;
        -h|--help)
            sed -n '2,30p' "$0"
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

info()  { printf '\033[0;34m[ios-hig]\033[0m %s\n' "$*"; }
ok()    { printf '\033[0;32m[ok]\033[0m      %s\n' "$*"; }
fail()  { printf '\033[0;31m[fail]\033[0m    %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Preflight
# ---------------------------------------------------------------------------

command -v xcodegen >/dev/null 2>&1 || {
    info "xcodegen not found; installing via brew..."
    command -v brew >/dev/null 2>&1 || fail "Homebrew required to auto-install xcodegen"
    brew install xcodegen
}

command -v jq >/dev/null 2>&1 || fail "jq required (brew install jq)"
command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild required (install Xcode)"

[[ -f "$WORKLIST" ]] || fail "Worklist not found: $WORKLIST"

mkdir -p "$SCREENSHOT_DIR" "$XCRESULT_DIR"

# ---------------------------------------------------------------------------
# 1. Build Crystal static library
# ---------------------------------------------------------------------------

info "Building libhighost.a for iOS simulator..."
"$IOS_DIR/build_crystal_lib.sh" simulator

[[ -f "$IOS_DIR/build/libhighost.a" ]] || fail "libhighost.a missing after build"
ok "libhighost.a ready"

# ---------------------------------------------------------------------------
# 2. Generate Xcode project
# ---------------------------------------------------------------------------

info "Generating Xcode project..."
(cd "$IOS_DIR" && xcodegen generate --spec project.yml)
ok "CrystalHIGHost.xcodeproj generated"

# ---------------------------------------------------------------------------
# 3. Collect slugs
# ---------------------------------------------------------------------------

if [[ -n "$ONLY_SLUG" ]]; then
    SLUGS="$ONLY_SLUG"
else
    SLUGS="$(jq -r '.pages[] | select((.role == "component") or ((.status == "implemented") and (.ui_view != null) and (.validation_state != "skipped"))) | .slug' "$WORKLIST")"
fi

# ---------------------------------------------------------------------------
# 4. Run tests per slug + extract screenshots
# ---------------------------------------------------------------------------

# Simulator name auto-detect (once, outside the loop): the project targets
# iOS 26, so we must pick a simulator in an iOS 26.x section.
if [[ -z "${SIM_NAME:-}" ]]; then
    SIM_NAME="$(xcrun simctl list devices available 2>/dev/null | \
        sed -n '/-- iOS 26\./,/-- /p' | \
        grep -oE 'iPhone [0-9]+ Pro( Max)?' | head -1)"
fi
SIM_NAME="${SIM_NAME:-iPhone 17 Pro}"

# Two appearances per slug (iteration-16 acceptance bar). TEST_RUNNER_*
# is the prefix xcodebuild forwards into the test-host process env.
APPEARANCES=("light" "dark")

BACKDROPS_DIR="$PROJECT_ROOT/.claude/skills/apple-platform-guide/validation/backdrops"

for slug in $SLUGS; do
    for appearance in "${APPEARANCES[@]}"; do
        info "=== $slug ($appearance) ==="
        xcresult="$XCRESULT_DIR/${slug}-${appearance}.xcresult"
        rm -rf "$xcresult"

        # Auto-select backdrop from worklist `backdrop` field (Phase 0.3 schema).
        # If HIG_BACKDROP_PATH is already set externally, honour it; otherwise
        # look up the stem from the worklist row and resolve the iOS-specific
        # variant (<stem>-ios-<appearance>.png, fallback to <stem>-<appearance>.png).
        RESOLVED_BACKDROP="${HIG_BACKDROP_PATH:-}"
        if [[ -z "$RESOLVED_BACKDROP" ]]; then
            STEM="$(jq -r --arg s "$slug" '.pages[] | select(.slug == $s) | .backdrop // empty' "$WORKLIST" 2>/dev/null || true)"
            if [[ -n "$STEM" ]]; then
                # Prefer the iOS-specific variant; fall back to the shared variant.
                IOS_CANDIDATE="$BACKDROPS_DIR/${STEM}-ios-${appearance}.png"
                SHARED_CANDIDATE="$BACKDROPS_DIR/${STEM}-${appearance}.png"
                if [[ -f "$IOS_CANDIDATE" ]]; then
                    RESOLVED_BACKDROP="$IOS_CANDIDATE"
                elif [[ -f "$SHARED_CANDIDATE" ]]; then
                    RESOLVED_BACKDROP="$SHARED_CANDIDATE"
                fi
            fi
        fi

        # Build backdrop env var if resolved.
        # TEST_RUNNER_ prefix: xcodebuild strips it before exposing the var
        # to the test-host process (and the test forwards it to the app).
        BACKDROP_ENV=""
        if [[ -n "$RESOLVED_BACKDROP" ]]; then
            BACKDROP_ENV="TEST_RUNNER_HIG_BACKDROP_PATH=$RESOLVED_BACKDROP"
            info "  backdrop: $RESOLVED_BACKDROP"
        fi

        set +e
        # Build env array for xcodebuild. Using 'env' avoids the bash
        # "word split on VAR=value treats it as a command" pitfall.
        XCODE_ENV=(
            "TEST_RUNNER_HIG_SLUG=$slug"
            "TEST_RUNNER_HIG_APPEARANCE=$appearance"
        )
        if [[ -n "$RESOLVED_BACKDROP" ]]; then
            XCODE_ENV+=("TEST_RUNNER_HIG_BACKDROP_PATH=$RESOLVED_BACKDROP")
        fi
        env "${XCODE_ENV[@]}" \
        xcodebuild test \
            -project "$IOS_DIR/CrystalHIGHost.xcodeproj" \
            -scheme CrystalHIGHost \
            -destination "platform=iOS Simulator,name=$SIM_NAME,OS=latest" \
            -only-testing:CrystalHIGHostUITests/HIGVisualTests/testRenderSlug \
            -resultBundlePath "$xcresult" 2>&1 | tail -20
        rc=$?
        set -e

        if [[ $rc -ne 0 ]]; then
            info "[$slug/$appearance] xcodebuild returned $rc (continuing to extract any screenshot)"
        fi

        att_dir="$XCRESULT_DIR/${slug}-${appearance}-attach"
        rm -rf "$att_dir"
        xcrun xcresulttool export attachments \
            --path "$xcresult" \
            --output-path "$att_dir" >/dev/null 2>&1 || true

        out="$SCREENSHOT_DIR/${slug}-ios-${appearance}.png"
        png="$(ls "$att_dir"/*.png 2>/dev/null | head -1 || true)"
        if [[ -z "$png" ]]; then
            info "[$slug/$appearance] no PNG attachment found under $att_dir"
            continue
        fi
        cp "$png" "$out"
        ok "[$slug/$appearance] -> $out"
    done
done

ok "Done."
