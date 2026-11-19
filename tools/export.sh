#!/usr/bin/env bash
# Builds every target with one command and proves each build boots (AR52, AR53; Story 1.13).
# Usage, from anywhere: tools/export.sh   (set GODOT=/path/to/godot if it isn't on PATH)
# Steps, in order; the first failure stops the build: preflight (Godot 4.7.2, its templates,
# Node, Playwright, the browser), version, import, content (every room file, before any export),
# the four exports, the PCK checks (no dev or test content in a release), the web download size,
# the Linux release boot, the web smoke (both web builds in headless Chromium), summary.
# Output: builds/<yyyymmdd>-<sha7>[-dirty]/{windows,linux,web,web_debug,logs}; a rebuild of the
# same version replaces the folder. Last line: `== BUILD OK builds/<version> …` or
# `== BUILD FAILED: <step>: <reason>`, with the matching exit code. docs/build.md has the setup.
# No flags and no partial modes: later stories add steps (string keys and licences 1.17,
# flags and lengths 5.7).
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
GODOT_VERSION="4.7.2.stable"  # editor and templates are frozen on 4.7.x for M2 (AR7)
TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_VERSION"
# The four this script uses: the web ones are single-threaded (export_presets.cfg).
TEMPLATE_FILES=(linux_release.x86_64 windows_release_x86_64.exe web_nothreads_release.zip web_nothreads_debug.zip)
NODE_MIN=24
PLAYWRIGHT_VERSION="1.65.1"  # tools/web_smoke/package.json pins it exactly
SMOKE="$ROOT/tools/web_smoke"
SMOKE_PORT=8061  # 8060 is the laptop tunnel's serve.js (docs/build.md): a tunnel never fails a build
# NFR5: the web download stays under 30 MB. The download is what itch.io's CDN sends: it gzips
# html, js, wasm and pck, so the measure is the sum of each file's gzip -9 size (D6, sonlm).
WEB_DOWNLOAD_MAX_BYTES=30000000
BOOT_S=5  # the Linux release boot runs this long; still running when timeout ends it = booted (D5)
# What fails a step besides a non-zero exit. Godot exits 0 on some errors (a missing options
# section, a parse error in a release build), so every log is scanned (D13).
ERROR_RE='^FAIL|FAILED|SCRIPT ERROR|ERROR:'

STEP=""
OUT=""
LOGS=""
RC=0
START_S=$SECONDS

step() {
	STEP="$1"
	echo "== step $1"
}

# Prints the end line last, after the log path, and keeps it in logs/summary.txt.
fail() {
	local line="== BUILD FAILED: $1" log="${2:-}"
	[ -n "$log" ] && echo "   log: ${log#"$ROOT"/}"
	echo "$line"
	if [ -n "$LOGS" ] && [ -d "$LOGS" ]; then
		{ echo "$line"; [ -n "$log" ] && echo "log: ${log#"$ROOT"/}"; } > "$LOGS/summary.txt"
	fi
	exit 1
}

# Anything set -e would end silently still gets an end line. set -E also runs this trap inside a
# $(…) subshell, where fail() would print its end line into the captured text and leave the build
# running (code review, probed on bash 5.2: BUILD FAILED, then BUILD OK and exit 0). So a subshell
# only exits with the status, and the command that captured it fails here, in the main shell.
trap '_rc=$?; [ "$BASHPID" = "$$" ] || exit "$_rc"; fail "${STEP:-setup}: unexpected error (exit $_rc) at tools/export.sh:$LINENO"' ERR
# A Ctrl-C or a TERM mid-build still leaves the end line and logs/summary.txt.
trap 'fail "${STEP:-setup}: interrupted"' INT TERM

# Prints a log's error lines (at most 5) and succeeds when it has any. Read from the file, never a
# pipe into grep -q: under pipefail a SIGPIPE'd writer turns a match into "no match" (D13).
errors_in() {
	local hits
	hits="$(grep -En "$ERROR_RE" "$1" || true)"
	[ -n "$hits" ] || return 1
	sed -n '1,5s/^/   /p' <<<"$hits"
}

# Runs Godot under a wall-clock limit (its own watchdogs can't fire if it hangs). The output goes
# to the log with ANSI colours stripped, so the scan sees plain `ERROR:` text. Sets RC.
godot_run() {
	local log="$1" limit="$2"
	shift 2
	RC=0
	timeout -k 5 "$limit" "$GODOT" "$@" > "$log.raw" 2>&1 || RC=$?
	sed -r 's/\x1b\[[0-9;]*m//g' "$log.raw" > "$log"
	rm -f -- "$log.raw"
}

# A Godot step passes on exit 0 with no error line.
check_run() {
	local what="$1" log="$2"
	if [ "$RC" -eq 124 ] || [ "$RC" -eq 137 ]; then
		fail "$what: no result before its time limit" "$log"
	fi
	if errors_in "$log"; then
		fail "$what: error lines in its log (exit $RC)" "$log"
	fi
	[ "$RC" -eq 0 ] || fail "$what: exit $RC" "$log"
}

mb() {
	awk -v b="$1" 'BEGIN { printf "%.1f", b / 1000000 }'
}

# --- 1. preflight: every missing piece is named before anything is built ---------------------
step preflight
missing=()
if [ ! -x "$GODOT" ]; then
	missing+=("Godot $GODOT_VERSION: no godot on PATH (or set GODOT=/path/to/godot)")
else
	gv="$("$GODOT" --version 2>/dev/null | head -n 1 || true)"
	[[ "$gv" == "$GODOT_VERSION"* ]] || missing+=("Godot $GODOT_VERSION: $GODOT is '${gv:-unknown}'")
fi
tv="$(cat "$TEMPLATES/version.txt" 2>/dev/null || true)"
[ "$tv" == "$GODOT_VERSION" ] || missing+=("export templates: $TEMPLATES/version.txt is '${tv:-missing}', not $GODOT_VERSION")
for f in "${TEMPLATE_FILES[@]}"; do
	[ -f "$TEMPLATES/$f" ] || missing+=("export template $f in $TEMPLATES (docs/build.md: templates)")
done
for c in timeout gzip git; do
	command -v "$c" > /dev/null || missing+=("the $c command")
done
# Each check runs whatever failed before it, so one run names everything (AC2). Only the browser
# needs Node and Playwright to be checked at all; without them it is named as unchecked.
nv=""
if command -v node > /dev/null; then
	nv="$(node -p 'process.versions.node' 2>/dev/null || true)"
fi
node_ok=false
if [ "${nv%%.*}" -ge "$NODE_MIN" ] 2>/dev/null; then
	node_ok=true
else
	missing+=("Node $NODE_MIN or later (got '${nv:-none}')")
fi
command -v npx > /dev/null || missing+=("npx (it ships with Node's npm)")
# Read without Node: the "version" field near the top of the installed package.json.
pv="$(sed -nE 's/^[[:space:]]*"version":[[:space:]]*"([^"]+)".*/\1/p' "$SMOKE/node_modules/@playwright/test/package.json" 2>/dev/null | head -n 1 || true)"
if [ "$pv" != "$PLAYWRIGHT_VERSION" ]; then
	missing+=("Playwright $PLAYWRIGHT_VERSION in tools/web_smoke (got '${pv:-none}'; run: cd tools/web_smoke && npm ci)")
	missing+=("Chromium headless shell: not checked until Playwright $PLAYWRIGHT_VERSION is installed")
elif ! $node_ok; then
	# An older Node can't load Playwright's registry, which would misreport the shell as missing.
	missing+=("Chromium headless shell: not checked until Node $NODE_MIN or later is installed")
else
	# chromium.executablePath() names the full Chromium, which an --only-shell install lacks;
	# a headless run uses the headless shell, so check that one, by Playwright's own registry
	# (an internal module, stable for the exact pin above; recheck it when the pin moves).
	shell="$(cd "$SMOKE" && node -e "const e = require('playwright-core/lib/coreBundle').registry.registry.findExecutable('chromium-headless-shell'); process.stdout.write((e && e.executablePath()) || '')" 2>/dev/null || true)"
	[ -n "$shell" ] && [ -x "$shell" ] || missing+=("Chromium headless shell for Playwright $PLAYWRIGHT_VERSION (run: cd tools/web_smoke && npx playwright install --only-shell --no-remove chromium)")
fi
# The smoke's webServer won't reuse a running server, so a busy port would fail it at step 9,
# after the whole build. The laptop tunnel uses 8060, never this one.
if (exec 3<> "/dev/tcp/127.0.0.1/$SMOKE_PORT") 2> /dev/null; then
	missing+=("a free port $SMOKE_PORT for the web smoke's serve.js (something listens there)")
fi
if [ ${#missing[@]} -gt 0 ]; then
	for m in "${missing[@]}"; do
		echo "   missing: $m"
	done
	fail "preflight: ${#missing[@]} missing (nothing was built)"
fi
echo "   Godot $gv, templates $tv, Node $nv, Playwright $pv"

# --- 2. version: computed before the export, which can create .godot/ and .uid files (D3) ----
step version
V="$(date +%Y%m%d)-$(git rev-parse --short=7 HEAD)"
# An assignment, so a failed git status fails the build instead of reading as a clean tree.
porcelain="$(git status --porcelain)"
[ -z "$porcelain" ] || V="$V-dirty"
# The guard on the one delete: never anything outside builds/<version>/.
[[ "$V" =~ ^[0-9]{8}-[0-9a-f]{7,}(-dirty)?$ ]] || fail "version: unexpected version '$V'"
OUT="$ROOT/builds/$V"
rm -rf -- "$OUT"
mkdir -p "$OUT/windows" "$OUT/linux" "$OUT/web" "$OUT/web_debug" "$OUT/logs"  # Godot refuses a missing folder
LOGS="$OUT/logs"
# The game's user:// for the runs of a build (the PCK listings and the Linux boot): a fresh one
# per build, so a boot never reads what an earlier build left (a newer settings or save schema)
# and never writes the server's own (code review, decided by sonlm). Exports keep the real
# XDG_DATA_HOME: the templates live there.
RUN_DATA="$LOGS/xdg_data"
mkdir -p "$RUN_DATA"
echo "   builds/$V"

# --- 3. import ----------------------------------------------------------------------------------
step import
godot_run "$LOGS/import.log" 600 --headless --path "$ROOT/game" --import
check_run "import" "$LOGS/import.log"

# --- 4. content: every room file, before any export (AR52, D12) --------------------------------
# smoke_rooms validates every rooms/**/*.txt (legend, unique ids, exit links) and runs the
# per-room guarantees, in ~12 s; the whole suite (~2 min) is run_tests.sh's job. The runner's
# exit code is the verdict; the scan is a second net. 1.17 adds string keys here, 5.7 flags and
# lengths.
step content
godot_run "$LOGS/content.log" 150 --headless --path "$ROOT/game" res://tests/runner.tscn -- res://tests/smoke_rooms.gd
check_run "content" "$LOGS/content.log"
grep -qx 'SMOKE PASS' "$LOGS/content.log" || fail "content: smoke_rooms printed no SMOKE PASS line" "$LOGS/content.log"

# --- 5. exports: absolute paths only (a relative one resolves against game/, not here) ---------
step export
export_one() {
	local preset="$1" mode="$2" key="$3" file="$4"
	godot_run "$LOGS/export_$key.log" 600 --headless --path "$ROOT/game" "$mode" "$preset" "$OUT/$key/$file"
	check_run "export $preset" "$LOGS/export_$key.log"
	[ -f "$OUT/$key/$file" ] || fail "export $preset: no $key/$file" "$LOGS/export_$key.log"
	echo "   $preset -> $key/$file"
}
export_one "Windows" --export-release windows unbroken_chain.exe
export_one "Linux" --export-release linux unbroken_chain.x86_64
# index.html: its base name names every web file, and itch.io wants it at the zip's top level.
export_one "Web" --export-release web index.html
export_one "Web debug" --export-debug web_debug index.html

# --- 6. PCK checks: no release PCK carries dev or test content (AR53, D4) -----------------------
step pck
declare -A PCK=([windows]=windows/unbroken_chain.pck [linux]=linux/unbroken_chain.pck [web]=web/index.pck [web_debug]=web_debug/index.pck)
declare -A PCK_FILES=()
# Every room file in the repo, as the exporter sees it (dot folders skipped, the match ignores
# case), so the listings prove "every room in every preset", not only test_export_presets' model.
ROOMS_ALL="$(cd "$ROOT/game" && find rooms -name '.*' -prune -o -type f -iname '*.txt' -print | sed 's|^|res://|' | LC_ALL=C sort)"
[ -n "$ROOMS_ALL" ] || fail "pck: found no room files under game/rooms/"
for key in windows linux web web_debug; do
	log="$LOGS/pck_$key.log"
	list="$LOGS/pck_$key.txt"
	[ -f "$OUT/${PCK[$key]}" ] || fail "pck: no ${PCK[$key]}"
	# The engine reads its own pack (pck_list.gd); -s must be absolute or it resolves inside the pack.
	XDG_DATA_HOME="$RUN_DATA" godot_run "$log" 60 --headless --main-pack "$OUT/${PCK[$key]}" -s "$ROOT/tools/pck_list.gd"
	check_run "pck $key: listing" "$log"
	grep -E '^res://' "$log" > "$list" || true  # the output starts with the engine banner
	rm -f -- "$log"
	n="$(wc -l < "$list")"
	PCK_FILES[$key]=$n
	# By prefix, not extension: scripts ship as .gdc plus .gd.remap. Test content is in no build,
	# Web debug included; dev content is in no release. scenes/dev/ has no files yet, but the
	# dev_ref lint already treats it as dev: its first file fails here until its exclusion is in
	# the presets and test_export_presets.
	if [ "$key" = web_debug ]; then
		forbidden='^res://tests/'
		what="test content (under res://tests/)"
		required=('^res://rooms/dev/perf_worst\.txt$' '^res://scripts/dev/dev_tools\.gd')
		want_rooms="$ROOMS_ALL"
	else
		forbidden='^res://(rooms/dev/|scenes/dev/|scripts/dev/|tests/)'
		what="dev or test content (under res://rooms/dev/, res://scenes/dev/, res://scripts/dev/ or res://tests/)"
		required=('^res://rooms/l1/m1_shaft\.txt$' '^res://scripts/world/world\.gd')
		want_rooms="$(grep -v '^res://rooms/dev/' <<<"$ROOMS_ALL" || true)"
	fi
	hits="$(grep -E "$forbidden" "$list" || true)"
	if [ -n "$hits" ]; then
		sed -n '1,5s/^/   /p' <<<"$hits"
		fail "pck: the $key PCK carries $what: $(grep -c . <<<"$hits") paths" "$list"
	fi
	# So the check can't pass on an empty or wrong listing: each PCK must hold what it must.
	for re in "${required[@]}"; do
		grep -Eq "$re" "$list" || fail "pck: the $key PCK has no ${re//\\/} ($n files listed)" "$list"
	done
	lost=()
	while IFS= read -r room; do
		[ -z "$room" ] || grep -qixF -- "$room" "$list" || lost+=("${room#res://}")
	done <<<"$want_rooms"
	[ ${#lost[@]} -eq 0 ] || fail "pck: the $key PCK misses ${#lost[@]} of the repo's room files (${lost[*]:0:5})" "$list"
	echo "   $key: $n files"
done

# --- 7. size: the web download, compressed (NFR5, D6) -----------------------------------------
step size
gz=0
raw=0
for f in "$OUT/web"/*; do
	[ -f "$f" ] || continue
	# Captured first: inside $(( )), a failed gzip would leave bash an arithmetic error to report.
	s="$(gzip -9 -c -- "$f" | wc -c)" || fail "size: gzip failed on web/${f##*/}"
	gz=$((gz + s))
	raw=$((raw + $(stat -c %s -- "$f")))
done
SIZE="web download $(mb "$gz") MB (gzip; raw $(mb "$raw") MB)"
echo "   $SIZE"
[ "$gz" -lt "$WEB_DOWNLOAD_MAX_BYTES" ] || fail "size: web download $gz bytes gzip (raw $raw) is not under $WEB_DOWNLOAD_MAX_BYTES (NFR5)"

# --- 8. Linux release boot: world.gd loads without scripts/dev/ (AR53, D5) --------------------
# A release build prints parse and load errors, never runtime script errors, and prints nothing
# when all is well. Booted = still running when timeout ends it (124), with no error line. Its
# user:// is the build's own RUN_DATA, where Game.boot() writes a default settings.json.
step boot
log="$LOGS/boot_linux.log"
RC=0
XDG_DATA_HOME="$RUN_DATA" timeout -k 5 "$BOOT_S" "$OUT/linux/unbroken_chain.x86_64" --headless > "$log.raw" 2>&1 || RC=$?
sed -r 's/\x1b\[[0-9;]*m//g' "$log.raw" > "$log"
rm -f -- "$log.raw"
if errors_in "$log"; then
	fail "boot: the Linux release build printed error lines (exit $RC)" "$log"
fi
[ "$RC" -ne 137 ] || fail "boot: the Linux release build was killed (exit 137: it ignored the TERM at $BOOT_S s, or the OS killed it)" "$log"
[ "$RC" -eq 124 ] || fail "boot: the Linux release build ended within $BOOT_S s (exit $RC), so it did not boot" "$log"
BOOT_RC=$RC
echo "   linux: still running after $BOOT_S s, no error"

# --- 9. web smoke: both web builds boot in headless Chromium (AR53, D7) -----------------------
step web_smoke
log="$LOGS/web_smoke.log"
RC=0
# Under timeout like every Godot step; it signals the whole group (npx, the runner, serve.js, the
# browser). Each test has its own 150 s limit (playwright.config.js).
(cd "$SMOKE" && BUILD_DIR="$OUT" PORT="$SMOKE_PORT" timeout -k 5 600 npx playwright test) > "$log.raw" 2>&1 || RC=$?
# Every escape sequence, not just colours: the line reporter also moves the cursor around a test's
# stdout, which is where the browser console of a failed test goes (smoke.spec.js).
sed -r 's/\x1b\[[0-9;]*[A-Za-z]//g' "$log.raw" > "$log"
rm -f -- "$log.raw"
if [ "$RC" -eq 124 ] || [ "$RC" -eq 137 ]; then
	fail "web_smoke: no result before its time limit" "$log"
fi
if [ "$RC" -ne 0 ]; then
	grep -E '^\s+[0-9]+\) |Error:|passed|failed' "$log" | sed -n '1,8s/^/   /p' || true
	fail "web_smoke: exit $RC" "$log"
fi
# Exit 0 is not enough: a skipped or unrun test is a build nobody booted (forbidOnly in the config
# stops a stray test.only). The line reporter ends with "  N passed (…)" and one line per other
# outcome (playwright 1.65.1 lib/runner/index.js).
others="$(grep -E '^ +[0-9]+ (skipped|flaky|did not run|interrupted)$' "$log" || true)"
[ -z "$others" ] || fail "web_smoke: not every test passed ($(tr -s ' \n' ' ' <<<"$others" | sed -r 's/^ | $//g'))" "$log"
PASSED="$(grep -E '^ +[0-9]+ passed' "$log" | tail -n 1 | sed -r 's/^ +//' || true)"
[ -n "$PASSED" ] || fail "web_smoke: no 'N passed' line" "$log"
echo "   $PASSED"

# --- 10. summary ------------------------------------------------------------------------------
step summary
END="== BUILD OK builds/$V, $SIZE, PCK files windows ${PCK_FILES[windows]} / linux ${PCK_FILES[linux]} / web ${PCK_FILES[web]} / web_debug ${PCK_FILES[web_debug]}, $((SECONDS - START_S)) s"
{
	echo "$END"
	echo "version: $V"
	echo "commit: $(git rev-parse HEAD)"
	echo "godot: $gv"
	echo "web download: $gz bytes gzip -9, $raw bytes raw (limit $WEB_DOWNLOAD_MAX_BYTES, NFR5)"
	for key in windows linux web web_debug; do
		echo "pck $key: ${PCK_FILES[$key]} files"
	done
	echo "linux boot: exit $BOOT_RC (still running) after $BOOT_S s, no error line"
	echo "web smoke: $PASSED"
} > "$LOGS/summary.txt"
echo "$END"
