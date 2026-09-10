#!/usr/bin/env bash
# Test double only, copied into an isolated Makefile-routing fixture.
set -euo pipefail
[[ $# == 2 ]] || exit 88
printf '%s\0' "$1" "$2" "${CRYSTAL_CACHE_DIR:-}" > "${AP_ROUTE_TRACE:?}"
exit "${AP_ROUTE_STATUS:-0}"
