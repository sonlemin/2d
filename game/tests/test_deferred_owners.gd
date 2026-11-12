extends Node
## Fails while any item in the deferred-work ledger has no owner.
## Why: gds-code-review appends deferred findings without one, and unowned items are how
## M1 work went missing until the 2026-11-12 readiness pass gave every item an owner.
## An agent may propose an owner (`→ **Owner (proposed): E3** — why`); only sonlm drops
## "(proposed)". Never edit this check to get green: give the item an owner instead.
## Run: godot --headless --path game res://tests/runner.tscn -- res://tests/test_deferred_owners.gd

const LEDGER := "../_bmad-output/implementation-artifacts/deferred-work.md"

var _fail := 0


func run() -> void:
	_test_scan_rules()
	_test_real_ledger()
	if _fail == 0:
		print("PASS")
	else:
		print("FAILED (%d)" % _fail)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


## Values that name no one: an item marked with one of these still has no owner.
const PLACEHOLDERS := ["", "tbd", "tba", "none", "none yet", "nobody", "unassigned", "unknown", "n/a", "na", "?", "??", "-", "—"]


## Pure scan of ledger text. An item is a top-level list bullet (`- `, `* `, `+ `, `1. `) plus
## its indented lines; a blank line doesn't end it, a column-0 paragraph or heading does.
## It is owned only by one of its own indented lines that opens with a bold `**Owner…: x**` or
## `**Closed…: x**` marker (optionally after `→`). There are no section-level owners, on
## purpose: bmad-build and quick-dev append bullets at the end of the file, under whatever
## section is last, and must not inherit its owner (code review of 1.1). Fenced code and
## `backticked` text are never items or markers.
## Returns {items: int, unowned: Array[Dictionary], proposed: Array[Dictionary]};
## each entry is {line: int (1-based), title: String}.
static func scan(text: String) -> Dictionary:
	var item_re := RegEx.create_from_string("^([-*+]|\\d+[.)])\\s")
	# Anchored at the line start, so an item's own bold title ("**Closed captions: x**") is no marker.
	var marker_re := RegEx.create_from_string("(?i)^\\s+(?:→\\s*)?\\*\\*(?:owner|closed)\\b[^*:]*:(.*)$")
	var code_re := RegEx.create_from_string("`[^`]*`")
	var items: Array[Dictionary] = []
	var current := {}
	var in_fence := false
	var lines := text.replace("\r", "").split("\n")
	for i in lines.size():
		var l: String = lines[i]
		var trimmed := l.strip_edges()
		if trimmed.begins_with("```") or trimmed.begins_with("~~~"):
			in_fence = not in_fence
			continue
		if in_fence or trimmed == "":
			continue
		var indented := l.begins_with(" ") or l.begins_with("\t")
		# An indented bullet with no item above it (after a heading or paragraph) is still an item.
		if not indented or current.is_empty():
			if item_re.search(trimmed) != null:
				current = {line = i + 1, title = _title(trimmed), owner = ""}
				items.append(current)
				continue
		if not indented:
			current = {}  # a column-0 paragraph or heading ends the item
			continue
		var kind := _marker_kind(code_re.sub(l, "", true), marker_re)
		if kind != "" and not current.is_empty() and current.owner != "owned":
			current.owner = kind
	var unowned: Array[Dictionary] = []
	var proposed: Array[Dictionary] = []
	for it in items:
		var entry := {line = it.line, title = it.title}
		if it.owner == "":
			unowned.append(entry)
		elif it.owner == "proposed":
			proposed.append(entry)
	return {items = items.size(), unowned = unowned, proposed = proposed}


## "owned", "proposed", or "" when the line carries no marker that names someone.
static func _marker_kind(line: String, marker_re: RegEx) -> String:
	var m := marker_re.search(line)
	if m == null:
		return ""
	var rest := m.get_string(1)
	var value: String
	if rest.begins_with("**"):
		value = rest.substr(2)  # "**Owner:** E3": the value follows the bold label
	else:
		var close := rest.find("**")
		if close < 0:
			return ""  # an unclosed bold is not a marker
		value = rest.substr(0, close)
	if value.strip_edges().trim_suffix(".").strip_edges().to_lower() in PLACEHOLDERS:
		return ""
	# "(proposed" anywhere on the line keeps it awaiting sonlm, wherever an agent put the word.
	return "proposed" if line.to_lower().contains("(proposed") else "owned"


static func _title(bullet: String) -> String:
	var body := RegEx.create_from_string("^([-*+]|\\d+[.)])\\s+").sub(bullet, "")
	var bold := RegEx.create_from_string("^\\*\\*(.+?)\\*\\*").search(body)
	if bold != null:
		return bold.get_string(1)
	var plain := body.strip_edges()
	return plain if plain.length() <= 60 else plain.substr(0, 57) + "..."


static func _lines(entries: Array) -> Array:
	return entries.map(func(e: Dictionary) -> int: return e.line)


func _test_scan_rules() -> void:
	# Size checks come first: a runtime error here would skip the rest and still print PASS.
	var r := scan("## A\n\n- **One** — x.\n  → **Owner: E1**\n- **Two** — y.\n")
	check(r.items == 2 and _lines(r.unowned) == [5], "an item without an owner line is reported with its line")
	check(r.unowned.size() == 1 and r.unowned[0].title == "Two", "the bold lead-in is the item's title")

	r = scan("## A\n- **Idea** — z.\n  → **Closed (2026-11-12): absorbed.** Moved to gear.\n")
	check(r.unowned.is_empty(), "a Closed marker counts as owned")

	r = scan("## Ideas\n\n**Owner (2026-11-12): the M2 retrospective**, later.\n\n- **P** — a.\n- **Q** — b.\n")
	check(_lines(r.unowned) == [5, 6], "a paragraph owner covers nothing: each item needs its own line")

	r = scan("## A\n- **P** — a.\n  → **Owner: E1**\n- source_spec: specs/x.md\n  location: game/x.gd\n")
	check(_lines(r.unowned) == [4], "an item appended at the end of the file inherits no owner")

	r = scan("## Deferred from: code review of 1-1 (2026-11-13)\n\n- run_tests.sh hides ERROR lines from the raw Godot output — deferred, pre-existing\n- Second finding\n")
	check(_lines(r.unowned) == [3, 4], "code-review bullets with no owner are caught")
	check(r.unowned.size() == 2 and r.unowned[0].title.length() <= 60 and r.unowned[1].title == "Second finding", "plain bullets get a short title")

	r = scan("## A\n- **X** — x.\n  → **Owner:**\n- **Y** — y.\n  → owner: E2 (not bold)\n")
	check(_lines(r.unowned) == [2, 4], "an empty or non-bold owner does not count")

	r = scan("## A\n- **X** — x.\n  → **Owner: TBD**\n- **Y** — y.\n  → **Owner: none.**\n- **Z** — z.\n  → **Owner: ?**\n")
	check(_lines(r.unowned) == [2, 4, 6], "a placeholder owner (TBD, none, ?) does not count")

	r = scan("## A\n- **X** — x.\n  → **Owner:** E3\n- **Y** — y.\n  → **Ownership: unclear**\n")
	check(_lines(r.unowned) == [4], "a value after the bold label counts; a longer word like Ownership does not")

	r = scan("## A\n- **Closed captions: Deck** — x.\n- **Regex** — y.\n  `**Owner: E1**` is the marker syntax.\n")
	check(_lines(r.unowned) == [2, 3], "an item's bold title or a backticked marker is not an owner")

	r = scan("## A\n- **X** — x.\n  → **Owner (proposed): E3** — the audio epic owns mix bugs.\n")
	check(r.unowned.is_empty() and _lines(r.proposed) == [2], "a proposed owner counts, but is listed for sonlm")

	r = scan("## A\n- **X** — x.\n  → **Owner: E3 (proposed)**\n- **Y** — y.\n  → **Closed (proposed): obsolete**\n- **Z** — z.\n  → **Owner: E3** (proposed)\n")
	check(r.unowned.is_empty() and _lines(r.proposed) == [2, 4, 6], "(proposed) anywhere on an Owner or Closed line stays proposed")

	r = scan("## A\n- **X** — x.\n  → **Owner (proposed): E5**\n  → **Owner: E2**\n")
	check(r.unowned.is_empty() and r.proposed.is_empty(), "a confirmed owner line beats a proposed one")

	r = scan("## A\n- **X** — x.\n\nA note between items.\n  → **Owner: E1**\n")
	check(_lines(r.unowned) == [2], "a paragraph ends the item, so a later indented owner is not its owner")

	r = scan("## A\n* **S** — s.\n+ **P** — p.\n1. **N** — n.\n2) plain\n\nNote.\n - **I** — i.\n")
	check(_lines(r.unowned) == [2, 3, 4, 5, 8], "*, +, numbered and lone indented bullets are items too")
	check(r.unowned.size() == 5 and r.unowned[2].title == "N" and r.unowned[3].title == "plain", "every bullet style gets its title")

	r = scan("## A\n```\n# not a heading\n- not an item\n```\n- **X** — x.\n  → **Owner: E1**\n")
	check(r.items == 1 and r.unowned.is_empty(), "fenced code holds no items")


func _test_real_ledger() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join(LEDGER).simplify_path()
	# A missing or unreadable ledger fails rather than passes, so it can't switch the check off.
	if not FileAccess.file_exists(path):
		check(false, "ledger not found at %s" % path)
		return
	var text := FileAccess.get_file_as_string(path)
	var err := FileAccess.get_open_error()
	if err != OK:
		check(false, "ledger unreadable at %s: %s" % [path, error_string(err)])
		return
	var r := scan(text)
	for u in r.unowned:
		check(false, "deferred-work.md:%d no owner: %s (add `  → **Owner: E#**`, or propose one)" % [u.line, u.title])
	for p in r.proposed:
		print("ok   deferred-work.md:%d proposed owner, awaiting sonlm: %s" % [p.line, p.title])
	# An empty ledger is fine (everything archived); only unowned items fail, each counted once above.
	if r.unowned.is_empty():
		check(true, "deferred-work.md: %d items, 0 unowned, %d proposed" % [r.items, r.proposed.size()])
