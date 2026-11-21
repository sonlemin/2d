extends RefCounted
## The pure string-table checks (Story 1.17 D10, AR41): the table's shape, its keys, its copy rules
## and every place code or a scene names a key. Every validator is static and pure over text or
## parsed rows and returns errors as "<where>: <what>"; test_strings runs them on the real table
## and tree and proves each one on a firing sample and a near-miss.
## A helper, not a test (no test_/smoke_ prefix), and no class_name, like room_sweep.gd:
##   const StringsCheck := preload("res://tests/strings_check.gd")
## What a text scan can't see (review covers it): a key built at run time from parts
## (`tr("DEATH_%s_LINE" % cause)` fails as a non-key literal; a key assembled in a variable on an
## earlier line passes unseen). The rule: every key appears whole as a literal somewhere in
## scripts/ (keys held as data, like E4/E5 dialogue tables, are literals too).

const Lint := preload("res://tests/test_lint.gd")

const HEADER := ["keys", "en"]  ## AC5: one key column and English; a locale adds a column
## D8: UPPER_SNAKE with at least two segments; the first is the domain prefix.
const KEY_PATTERN := "^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$"
## D8: the listed domains. A story that adds a domain adds its prefix here and in
## docs/development-guide.md → Player-facing text, so a new domain is a choice, not an accident.
const PREFIXES := ["MENU", "DEATH", "TIER", "NPC", "JOURNAL", "DEV", "POPUP"]
## D11: narrative prose follows narrative-design.md (E4/E5 validators), not UX-DR55's colour rule.
const NARRATIVE_PREFIXES := ["NPC", "JOURNAL"]
## D11, UX-DR55: copy names shapes, never colours (whole words, any case).
const COLOUR_WORDS := ["red", "green", "blue", "yellow", "orange", "amber", "purple", "violet",
		"pink", "white", "black", "grey", "gray"]
## UX-DR56: never "roguelike" or "Downwell-like" (any case).
const BANNED_WORDS := ["roguelike", "downwell"]

static var _key_re := RegEx.create_from_string(KEY_PATTERN)
## A translating call whose first argument starts with a string literal (StringName too); group 2
## is the literal's text. `tr`, `tr_n`, `atr`, `atr_n` (Object) and the static
## TranslationServer.translate(). Not preceded by a word character, so `str(` never matches.
static var _call_res: Array[RegEx] = [
	RegEx.create_from_string("(?<![\\w])(tr|tr_n|atr|atr_n|TranslationServer\\s*\\.\\s*translate)\\s*\\(\\s*&?\"((?:\\\\.|[^\"\\\\])*)\""),
	RegEx.create_from_string("(?<![\\w])(tr|tr_n|atr|atr_n|TranslationServer\\s*\\.\\s*translate)\\s*\\(\\s*&?'((?:\\\\.|[^'\\\\])*)'"),
]
## Every string literal on a line (StringName and NodePath too); group 1 is its text.
static var _literal_res: Array[RegEx] = [
	RegEx.create_from_string("\"((?:\\\\.|[^\"\\\\])*)\""),
	RegEx.create_from_string("'((?:\\\\.|[^'\\\\])*)'"),
]
## A scene's `text = "…"` property holding a run of two lowercase letters: raw UI text (AC6).
static var _scene_text_re := RegEx.create_from_string("^\\s*text\\s*=\\s*\"[^\"]*[a-z]{2}")
static var _word_re := RegEx.create_from_string("[a-z]+")


static func is_key(s: String) -> bool:
	return _key_re.search(s) != null


## True for a key-shaped string whose first segment is a listed prefix.
static func is_listed_key(s: String) -> bool:
	return is_key(s) and s.get_slice("_", 0) in PREFIXES


## The table's shape (AC6 "Table"): `rows` are FileAccess.get_csv_line() results, header first.
## The header is exactly keys,en; every row has two cells; every key is key-shaped, listed and
## unique; every `en` is non-empty with no leading or trailing whitespace.
static func check_table(rows: Array) -> Array[String]:
	var errors: Array[String] = []
	if rows.is_empty():
		return ["table: no header row"]
	if Array(rows[0]) != HEADER:
		errors.append("table: header is %s, not %s" % [Array(rows[0]), HEADER])
	var seen := {}
	for i in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		var where := "row %d" % (i + 1)
		if row.size() != HEADER.size():
			errors.append("%s: %d cells, not %d (%s)" % [where, row.size(), HEADER.size(), row])
			continue
		var key := row[0]
		var en := row[1]
		if not is_key(key):
			errors.append("%s: key '%s' is not UPPER_SNAKE with a prefix (%s)" % [where, key, KEY_PATTERN])
		elif not is_listed_key(key):
			errors.append("%s: key %s has an unlisted prefix (listed: %s)" % [where, key, ", ".join(PREFIXES)])
		if seen.has(key):
			errors.append("%s: key %s repeats row %d" % [where, key, seen[key]])
		else:
			seen[key] = i + 1
		if en == "":
			errors.append("%s: %s has no English text" % [where, key])
		elif en != en.strip_edges():
			errors.append("%s: %s's English text has leading or trailing whitespace ('%s')" % [where, key, en])
	return errors


## AC6: every character of every `en`, as drawn (unescaped), has a glyph in `font` (newline
## excepted). The 8 px build has Latin-1 and Latin Extended-A, not stacked Vietnamese marks or
## Cyrillic (AC1), so copy outside them would draw as boxes.
static func check_glyphs(rows: Array, font: Font) -> Array[String]:
	var errors: Array[String] = []
	for i in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if row.size() < 2:
			continue
		var text := row[1].c_unescape()
		for c in text:
			if c != "\n" and not font.has_char(c.unicode_at(0)):
				errors.append("row %d: %s has '%s' (U+%04X), which the font can't draw" % [i + 1, row[0], c, c.unicode_at(0)])
	return errors


## AC6 "Registered and current": every key translates to its CSV text, unescaped as the importer's
## unescape_translations does (String.c_unescape(), probed). A CSV edited without a re-import
## leaves a stale .translation, and this is the only check that sees it. `translate` is
## TranslationServer.translate in the test; a sample passes a lookup of its own.
static func check_registered(rows: Array, translate: Callable) -> Array[String]:
	var errors: Array[String] = []
	for i in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if row.size() < 2:
			continue
		var want := row[1].c_unescape()
		var got := String(translate.call(row[0]))
		if got != want:
			errors.append("row %d: %s translates to '%s', not the CSV's '%s' (re-import and commit the .translation)" % [i + 1, row[0], got.c_escape(), want.c_escape()])
	return errors


## AC6 "Copy rules" (UX-DR55, UX-DR56; D11): no `en` says "roguelike" or "downwell", "%%" or
## "percent" (no completion percentage); no colour word, in the text or the key, outside the
## narrative prefixes.
static func check_copy(rows: Array) -> Array[String]:
	var errors: Array[String] = []
	for i in range(1, rows.size()):
		var row: PackedStringArray = rows[i]
		if row.size() < 2:
			continue
		var key := row[0]
		var low := row[1].to_lower()
		for w: String in BANNED_WORDS:
			if low.contains(w):
				errors.append("row %d: %s says '%s' (UX-DR56)" % [i + 1, key, w])
		if row[1].contains("%%") or low.contains("percent"):
			errors.append("row %d: %s shows a percentage (UX-DR56: no completion percentage)" % [i + 1, key])
		if key.get_slice("_", 0) in NARRATIVE_PREFIXES:
			continue
		var words := PackedStringArray()
		for m in _word_re.search_all(low):
			words.append(m.get_string())
		words.append_array(key.to_lower().split("_"))
		for w: String in COLOUR_WORDS:
			if w in words:
				errors.append("row %d: %s names a colour, '%s' (UX-DR55: name shapes, never colours)" % [i + 1, key, w])
	return errors


## Every key reference in one file, as [{line (1-based), key, kind}]. kind "call": a key-shaped
## literal as a translating call's first argument; "bad_call": a literal there that is not
## key-shaped (a composed key, which no scan can resolve); "data": any other literal that is a
## listed key (keys held as data). For .gd files comments are dropped with test_lint's strip()
## (strings kept); .tscn lines are read whole.
static func refs_in(text: String, is_gd: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var open := ""
	var lines := text.replace("\r", "").split("\n")
	for i in lines.size():
		var code := lines[i]
		if is_gd:
			var s := Lint.strip(lines[i], open)
			open = s.open
			code = s.code
		var call_spans := {}  # literal start -> true, so a call's literal isn't also counted as data
		for re in _call_res:
			for m in re.search_all(code):
				var lit := m.get_string(2)
				call_spans[m.get_start(2)] = true
				out.append({line = i + 1, key = lit, kind = "call" if is_key(lit) else "bad_call"})
		for re in _literal_res:
			for m in re.search_all(code):
				if call_spans.has(m.get_start(1)):
					continue
				var lit := m.get_string(1)
				if is_listed_key(lit):
					out.append({line = i + 1, key = lit, kind = "data"})
	return out


## AC6 "Code scan": `refs` maps a file path to refs_in()'s result, `keys` lists the CSV's keys.
## Fails a referenced key the table lacks, a non-key literal passed to a translating call, and a
## table key nothing references (no dead text ships).
static func check_refs(refs: Dictionary, keys: Array) -> Array[String]:
	var errors: Array[String] = []
	var used := {}
	for path: String in refs:
		for r: Dictionary in refs[path]:
			if r.kind == "bad_call":
				errors.append("%s:%d: '%s' passed to a translating call is not a key; keep each key whole as a literal (D10)" % [path, r.line, r.key])
				continue
			used[r.key] = true
			if not r.key in keys:
				errors.append("%s:%d: key %s is not in text/strings.csv (tr() would show the key)" % [path, r.line, r.key])
	for k: String in keys:
		if not used.has(k):
			errors.append("text/strings.csv: key %s is referenced nowhere in scripts/ or scenes/ (dead text)" % k)
	return errors


## AC6 "Scenes": no `text = "…"` in a scene holds a run of two lowercase letters; player text is
## set from code through tr(), so the table and the scan see it.
static func check_scene_text(path: String, text: String) -> Array[String]:
	var errors: Array[String] = []
	var lines := text.replace("\r", "").split("\n")
	for i in lines.size():
		if _scene_text_re.search(lines[i]) != null:
			errors.append("%s:%d: raw UI text in a scene (%s); set it from code with tr()" % [path, i + 1, lines[i].strip_edges()])
	return errors


## Every file under `dir` ending in `ext`, subfolders included, sorted.
static func files_under(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(files_under(dir.path_join(d), ext))
	out.sort()
	return out
