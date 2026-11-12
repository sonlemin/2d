#!/usr/bin/env bash
# Run every headless test. Usage: ./run_tests.sh   (set GODOT=/path/to/godot if it isn't on PATH)
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
fail=0
for t in test_chain_state test_deferred_owners smoke_shaft; do
	echo "== $t"
	out=$("$GODOT" --headless --path . res://tests/runner.tscn -- "res://tests/$t.gd" 2>&1) || fail=1
	echo "$out" | grep -E "^(ok|FAIL)|PASS|FAILED"
done
[ $fail -eq 0 ] && echo "== ALL GREEN" || { echo "== SOMETHING FAILED"; exit 1; }
