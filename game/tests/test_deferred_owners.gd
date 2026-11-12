extends SceneTree
## Fails while any item in the deferred-work ledger has no owner.
## Why: gds-code-review appends deferred findings without one, and unowned items are how
## M1 work went missing until the 2026-11-12 readiness pass gave every item an owner.
## An agent may propose an owner (`→ **Owner (proposed): E3** — why`); only sonlm drops
## "(proposed)". Never edit this check to get green: give the item an owner instead.
## Run: godot --headless --path game --script res://tests/test_deferred_owners.gd

const LEDGER := "../_bmad-output/implementation-artifacts/deferred-work.md"

var _fail := 0


func _init() -> void:
	_test_scan_rules()
	_test_real_ledger()
	if _fail == 0:
		print("PASS")
		quit(0)
	else:
		print("FAILED (%d)" % _fail)
		quit(1)


func check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_fail += 1


## Pure scan of ledger text. An item is a top-level `- ` bullet plus its indented lines.
## It is owned by a bold `**Owner…: x**` or `**Closed…: x**` marker in its own lines, or by
## such a marker in a non-bullet paragraph of its `#` section (one owner for a whole list).
## Returns {items: int, unowned: Array[Dictionary], proposed: Array[Dictionary]};
## each entry is {line: int (1-based), title: String}.
static func scan(text: String) -> Dictionary:
	# The value after the colon must be non-empty: "**Owner:**" alone owns nothing.
	var owner_re := RegEx.create_from_string("(?i)\\*\\*(owner|closed)[^*:]*:\\s*[^*\\s][^*]*\\*\\*")
	var proposed_re := RegEx.create_from_string("(?i)\\*\\*owner[^*:]*\\(proposed")
	var items: Array[Dictionary] = []
	var section_owner := {}  # section index -> "owned" or "proposed"
	var section := 0
	var current := {}
	var lines := text.replace("\r", "").split("\n")
	for i in lines.size():
		var l: String = lines[i]
		if l.begins_with("#"):
			section += 1
			current = {}
			continue
		if l.begins_with("- "):
			current = {line = i + 1, title = _title(l), section = section, owner = ""}
			items.append(current)
		elif l.strip_edges() != "" and not (l.begins_with(" ") or l.begins_with("\t")):
			current = {}  # a paragraph line ends the item and speaks for the section
		if owner_re.search(l) == null:
			continue
		var kind := "proposed" if proposed_re.search(l) != null else "owned"
		if not current.is_empty():
			if current.owner != "owned":
				current.owner = kind
		elif not (l.begins_with(" ") or l.begins_with("\t")):
			# Only a top-level paragraph speaks for the section; an orphaned indented line owns nothing.
			if section_owner.get(section, "") != "owned":
				section_owner[section] = kind
	var unowned: Array[Dictionary] = []
	var proposed: Array[Dictionary] = []
	for it in items:
		var k: String = it.owner if it.owner != "" else section_owner.get(it.section, "")
		var entry := {line = it.line, title = it.title}
		if k == "":
			unowned.append(entry)
		elif k == "proposed":
			proposed.append(entry)
	return {items = items.size(), unowned = unowned, proposed = proposed}


static func _title(bullet: String) -> String:
	var bold := RegEx.create_from_string("^- \\*\\*(.+?)\\*\\*").search(bullet)
	if bold != null:
		return bold.get_string(1)
	var plain := bullet.substr(2).strip_edges()
	return plain if plain.length() <= 60 else plain.substr(0, 57) + "..."


static func _lines(entries: Array) -> Array:
	return entries.map(func(e: Dictionary) -> int: return e.line)


func _test_scan_rules() -> void:
	var r := scan("## A\n\n- **One** — x.\n  → **Owner: E1**\n- **Two** — y.\n")
	check(r.items == 2 and _lines(r.unowned) == [5], "an item without an owner line is reported with its line")
	check(r.unowned[0].title == "Two", "the bold lead-in is the item's title")

	r = scan("## A\n- **Idea** — z.\n  → **Closed (2026-11-12): absorbed.** Moved to gear.\n")
	check(r.unowned.is_empty(), "a Closed marker counts as owned")

	r = scan("## Ideas\n\nRule: one at a time.\n\n**Owner (2026-11-12): the M2 retrospective**, later.\n\n- **P** — a.\n- **Q** — b.\n\n## Next\n- **R** — c.\n")
	check(_lines(r.unowned) == [11], "a section-level owner covers its list and stops at the next heading")

	r = scan("## Deferred from: code review of 1-1 (2026-11-13)\n\n- run_tests.sh hides ERROR lines from the raw Godot output — deferred, pre-existing\n- Second finding\n")
	check(_lines(r.unowned) == [3, 4], "code-review bullets with no owner are caught")
	check(r.unowned[0].title.length() <= 60 and r.unowned[1].title == "Second finding", "plain bullets get a short title")

	r = scan("## A\n- **X** — x.\n  → **Owner:**\n- **Y** — y.\n  → owner: E2 (not bold)\n")
	check(_lines(r.unowned) == [2, 4], "an empty or non-bold owner does not count")

	r = scan("## A\n- **X** — x.\n  → **Owner (proposed): E3** — the audio epic owns mix bugs.\n")
	check(r.unowned.is_empty() and _lines(r.proposed) == [2], "a proposed owner counts, but is listed for sonlm")

	r = scan("## A\n**Owner (proposed): E5**\n- **X** — x.\n- **Y** — y.\n  → **Owner: E2**\n")
	check(_lines(r.proposed) == [3] and r.unowned.is_empty(), "an item's own owner beats a proposed section owner")

	r = scan("## A\n- **X** — x.\n\nA note between items.\n  → **Owner: E1**\n")
	check(_lines(r.unowned) == [2], "a paragraph ends the item, so a later indented owner is not its owner")


func _test_real_ledger() -> void:
	var path := ProjectSettings.globalize_path("res://").path_join(LEDGER).simplify_path()
	# A missing ledger fails rather than passes, so moving the file can't switch the check off.
	if not FileAccess.file_exists(path):
		check(false, "ledger not found at res://%s" % LEDGER)
		return
	var r := scan(FileAccess.get_file_as_string(path))
	for u in r.unowned:
		check(false, "deferred-work.md:%d no owner: %s (add `  → **Owner: E#**`, or propose one)" % [u.line, u.title])
	for p in r.proposed:
		print("ok   deferred-work.md:%d proposed owner, awaiting sonlm: %s" % [p.line, p.title])
	# An empty ledger is fine (everything archived); only unowned items fail.
	check(r.unowned.is_empty(), "deferred-work.md: %d items, %d unowned, %d proposed" % [r.items, r.unowned.size(), r.proposed.size()])
