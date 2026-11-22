#!/usr/bin/env bash
# Run every headless test. Usage: ./run_tests.sh   (set GODOT=/path/to/godot if it isn't on PATH)
# Tests are found by name (AR47, Story 1.9): every tests/test_*.gd (unit), then every
# tests/smoke_*.gd (scene), each through tests/runner.tscn. Name a new test to match and it runs;
# anything else in tests/ is a helper. TESTS_DIR (default tests; a folder relative to game/, since
# tests run as res://$TESTS_DIR/…) exists only so the empty-glob check can be red-checked; leave it unset.
set -u
cd "$(dirname "$0")"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
TESTS_DIR="${TESTS_DIR:-tests}"
"$GODOT" --headless --path . --import >/dev/null 2>&1
# The import regenerates text/*.translation whenever its CSV changed since the last import (an
# edit, or a pull), so a CSV committed without its re-imported .translation is repaired before
# test_strings could see it (Story 1.17 code review, probed). What is left to see is the tree's
# state: a .translation that differs from the commit while its CSV is as committed means the
# committed one is stale. Mid-edit both differ, which is the workflow. Without git (an unpacked
# copy) there is no commit to compare with.
stale_translation=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
		&& [ -n "$(git status --porcelain -- 'text/*.translation')" ] \
		&& [ -z "$(git status --porcelain -- 'text/*.csv' 'text/*.csv.import')" ]; then
	echo "FAIL text/*.translation differs from the commit while its CSV is as committed: the committed .translation is stale. Commit the regenerated one."
	stale_translation=1
fi
# The runner's own 120 s watchdog can't fire if a test blocks the main loop, so each run also
# gets a wall-clock limit (Story 1.1: a missed path can hang Godot instead of failing).
LIMIT=150
TIMEOUT="$(command -v timeout || true)"
shopt -s nullglob
# Unit tests first (fast, fail early); C collation so the order never depends on the locale.
tests=()
for pattern in "test_*.gd" "smoke_*.gd"; do
	while IFS= read -r f; do
		[ -n "$f" ] && tests+=("$f")
	done < <(cd "$TESTS_DIR" 2>/dev/null && for f in $pattern; do echo "$f"; done | LC_ALL=C sort)
done
if [ ${#tests[@]} -eq 0 ]; then
	echo "== NO TESTS FOUND in $TESTS_DIR/ (test_*.gd, smoke_*.gd)"
	exit 1
fi
fail=$stale_translation
failed=()
[ $stale_translation -eq 0 ] || failed+=("import (a stale committed .translation)")
for f in "${tests[@]}"; do
	t="${f%.gd}"
	echo "== $t"
	out=$(${TIMEOUT:+$TIMEOUT $LIMIT} "$GODOT" --headless --path . res://tests/runner.tscn -- "res://$TESTS_DIR/$f" 2>&1)
	rc=$?
	# Error lines and their `at:` traces too: the runner fails on them (D3), so show why.
	echo "$out" | grep -E "^(ok|FAIL)|PASS|FAILED|SCRIPT ERROR|ERROR:|^ +at: "
	[ $rc -eq 124 ] && echo "FAILED (run_tests.sh: killed after ${LIMIT} s)"
	if [ $rc -ne 0 ]; then
		fail=1
		failed+=("$t")
	fi
done
if [ $fail -eq 0 ]; then
	echo "== ALL GREEN (${#tests[@]} tests)"
else
	echo "== SOMETHING FAILED"
	echo "== failed: ${failed[*]}"
	exit 1
fi
