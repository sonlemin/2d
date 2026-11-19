extends SceneTree
## Lists every file in a PCK, one `res://…` path per line (Story 1.13 D4, AR53). tools/export.sh
## uses the listing to prove no release PCK carries rooms/dev/, tests/ or scripts/dev/.
## Run with absolute paths (a relative -s path resolves inside the pack):
##   godot --headless --main-pack /abs/game.pck -s /abs/tools/pck_list.gd
## The engine reads its own pack, so a PCK format change (v4 in 4.7) needs nothing here; a
## hand-written reader would break silently on an engine upgrade.
## Output starts with the engine banner: keep only lines that start with `res://`.
## Caveat: --main-pack still instances the pack's autoloads. Game._init() only builds the Clock
## (disk access waits for boot(), which only World calls), so listing touches nothing; a future
## autoload must keep disk and network out of _init() and _ready().
## Lives outside game/, so it is never exported or linted, and may print.


func _initialize() -> void:
	var out := PackedStringArray()
	_walk("res://", out)
	out.sort()
	for p in out:
		print(p)
	quit()


## Every file under `dir`, hidden ones too (.godot/ holds the import and uid caches).
func _walk(dir: String, out: PackedStringArray) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		printerr("pck_list: cannot open %s (%s)" % [dir, error_string(DirAccess.get_open_error())])
		return
	da.include_hidden = true
	for f in da.get_files():
		out.append(dir.path_join(f))
	for d in da.get_directories():
		_walk(dir.path_join(d), out)
