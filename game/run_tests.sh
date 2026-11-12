#!/usr/bin/env bash
# Run every headless test. Usage: ./run_tests.sh   (set GODOT=/path/to/godot if it isn't on PATH)
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
# The runner's own 120 s watchdog can't fire if a test blocks the main loop, so each run also
# gets a wall-clock limit (Story 1.1: a missed path can hang Godot instead of failing).
LIMIT=150
TIMEOUT="$(command -v timeout || true)"
fail=0
for t in test_chain_state test_log test_clock test_tuning test_state test_deferred_owners smoke_shaft smoke_shaft_state; do
	echo "== $t"
	out=$(${TIMEOUT:+$TIMEOUT $LIMIT} "$GODOT" --headless --path . res://tests/runner.tscn -- "res://tests/$t.gd" 2>&1)
	rc=$?
	# Error lines and their `at:` traces too: the runner fails on them (D3), so show why.
	echo "$out" | grep -E "^(ok|FAIL)|PASS|FAILED|SCRIPT ERROR|ERROR:|^ +at: "
	[ $rc -eq 124 ] && echo "FAILED (run_tests.sh: killed after ${LIMIT} s)"
	[ $rc -ne 0 ] && fail=1
done
[ $fail -eq 0 ] && echo "== ALL GREEN" || { echo "== SOMETHING FAILED"; exit 1; }
