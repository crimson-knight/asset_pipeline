#!/usr/bin/env bash
# Falsification harness for scripts/ci/report_outcome.sh: a stub gh on PATH
# records every call, and each scenario asserts the exact calls the script
# must and must not make. No network, no token.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$ROOT/scripts/ci/report_outcome.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/gh.log"

mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Records argv (and stdin for --body-file -) and answers the two queries the
# reporter makes. STUB_OPEN_ISSUE is the open issue number, if any.
{ printf 'gh'; printf ' %q' "$@"; printf '\n'; } >> "$STUB_LOG"
for arg in "$@"; do
  if [ "$arg" = "-" ]; then
    { printf 'STDIN<<\n'; cat; printf '\n>>STDIN\n'; } >> "$STUB_LOG"
  fi
done
case "$1 $2" in
  "api repos/example/repo") printf '%s' "${STUB_HAS_ISSUES:-true}" ;;
  "api repos/example/repo/issues?state=open&labels=ci-failure,lane:android-native&per_page=50")
    if [ -n "${STUB_OPEN_ISSUE:-}" ]; then printf '%s' "$STUB_OPEN_ISSUE"; fi ;;
  "issue create")
    if [ "${STUB_REFUSE_ASSIGNEE:-0}" = "1" ]; then
      for arg in "$@"; do [ "$arg" = "--assignee" ] && { echo "stub: assignee refused" >&2; exit 1; }; done
    fi
    echo "https://github.com/example/repo/issues/99" ;;
esac
exit 0
STUB
chmod +x "$TMP/bin/gh"

failures=0
check() { # check <name> <condition...>
  local name="$1"; shift
  if "$@"; then echo "ok   $name"; else echo "FAIL $name"; failures=$((failures + 1)); fi
}
log_has() { grep -q -- "$1" "$LOG"; }
log_lacks() { ! grep -q -- "$1" "$LOG"; }
count_in_log() { [ "$(grep -c -- "$1" "$LOG" || true)" = "$2" ]; }

run_reporter() { # run_reporter <outcome> [env assignments...]
  : > "$LOG"
  env PATH="$TMP/bin:$PATH" STUB_LOG="$LOG" OUTCOME="$1" LANE="android-native" \
    WORKFLOW_NAME="Android native validation" RUN_URL="https://github.com/example/repo/actions/runs/1" \
    REPOSITORY="example/repo" EVENT_NAME="schedule" REF_NAME="android-target" SHA="abc123" \
    GH_TOKEN="stub" "${@:2}" bash "$SCRIPT" > "$TMP/out.txt" 2> "$TMP/err.txt"
}

echo "# scenario 1: failure with no open issue opens one and tags the owner by default"
run_reporter failure STUB_OPEN_ISSUE=""
check "labels are ensured with --force" count_in_log "gh label create" 2
check "the lane label names the lane" log_has "lane:android-native"
check "one issue is created" count_in_log "gh issue create" 1
check "the maintainers default to the repository owner" log_has "--assignee example"
check "the body mentions the owner" log_has "@example the \*\*Android native validation\*\* lane failed"
check "the body carries the run URL" log_has "Run: https://github.com/example/repo/actions/runs/1"
check "nothing is commented or closed" log_lacks "issue comment"
check "the title names the workflow and the lane" log_has 'validation\\ failed\\ on'
check "the script reports success on stdout" grep -q "opened an issue tagging @example" "$TMP/out.txt"

echo "# scenario 2: failure with an open issue comments instead of opening another"
run_reporter failure STUB_OPEN_ISSUE="7"
check "no second issue is created" log_lacks "issue create"
check "the open issue gets the comment" log_has "gh issue comment 7"
check "the comment says it failed again" log_has "Failed again"

echo "# scenario 3: success with an open issue closes it with a recovery comment"
run_reporter success STUB_OPEN_ISSUE="7"
check "the issue is closed" log_has "gh issue close 7"
check "the close carries the recovery comment" log_has "Recovered"
check "labels are not touched on success" log_lacks "label create"

echo "# scenario 4: success with nothing open does nothing"
run_reporter success STUB_OPEN_ISSUE=""
check "only the issue-setting and open-issue queries ran" count_in_log "^gh" 2
check "the query is the issues endpoint, not the search listing" log_has "gh api repos/example/repo/issues"

echo "# scenario 5: a cancelled run is not a verdict"
run_reporter cancelled STUB_OPEN_ISSUE="7"
check "no gh call at all" [ ! -s "$LOG" ]
check "stdout says why" grep -q "not a verdict" "$TMP/out.txt"

echo "# scenario 6: explicit maintainers, with @ and commas, are mentioned and assigned"
run_reporter failure STUB_OPEN_ISSUE="" MAINTAINERS="@alice, bob"
check "both are assigned" log_has '--assignee alice\\,bob'
check "both are mentioned" log_has "@alice @bob the"

echo "# scenario 7: a refused assignment retries without assignees, so the report still lands"
run_reporter failure STUB_OPEN_ISSUE="" STUB_REFUSE_ASSIGNEE=1
check "two create attempts" count_in_log "gh issue create" 2
check "the second has no assignee" [ "$(grep -- 'gh issue create' "$LOG" | tail -1 | grep -c -- '--assignee' || true)" = "0" ]
check "stderr explains the retry" grep -q "assignment to example refused" "$TMP/err.txt"

echo "# scenario 8: an unknown outcome is an error, not silence"
if run_reporter bogus STUB_OPEN_ISSUE=""; then echo "FAIL unknown outcome exited 0"; failures=$((failures + 1)); else echo "ok   unknown outcome exits nonzero"; fi

echo "# scenario 10: a repository with issues disabled is named, not guessed at"
if run_reporter failure STUB_OPEN_ISSUE="" STUB_HAS_ISSUES=false; then echo "FAIL disabled issues exited 0"; failures=$((failures + 1)); else echo "ok   disabled issues exit nonzero"; fi
check "the message names the setting to flip" grep -q "enable them with: gh repo edit example/repo --enable-issues" "$TMP/err.txt"
check "nothing was created" log_lacks "issue create"

echo "# scenario 9: dry run prints commands and touches nothing"
run_reporter failure REPORT_DRY_RUN=1 REPORT_DRY_RUN_OPEN_ISSUE=""
check "no gh call in dry run" [ ! -s "$LOG" ]
check "the dry run prints the create" grep -q "DRY RUN: gh issue create" "$TMP/out.txt"

if [ "$failures" = "0" ]; then echo "report_outcome harness: all checks passed"; else echo "report_outcome harness: $failures check(s) failed"; exit 1; fi
