extends SceneTree
## Writes GODOT_LICENSES.txt for tools/export.sh's licences step (Story 1.17 D13; NFR18, UX-DR16):
## Godot's MIT licence, every third-party component the engine was built with (name, files,
## copyright lines, licence) and the full text of every licence they use. Every build ships it,
## web included, beside the font's OFL.txt and LICENSES/.
## Run with absolute paths (the output path goes after `--`):
##   godot --headless --path /abs/game -s /abs/tools/godot_licenses.gd -- /abs/out/GODOT_LICENSES.txt
## It runs on the editor binary, which preflight pins to 4.7.2 like the templates. The editor's
## component list is a superset of the export templates' (it adds editor-only components), and a
## superset notice is compliant.
## Exits 0 with the file written; on a write failure pushes an error (an `ERROR:` line) and exits 1,
## both of which fail export.sh's step. Lives outside game/, so it is never exported or linted,
## and may print.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path():
		push_error("godot_licenses: pass one absolute output path after -- (got %s)" % [args])
		quit(1)
		return
	var text := build()
	var f := FileAccess.open(args[0], FileAccess.WRITE)
	if f == null:
		push_error("godot_licenses: cannot write %s (%s)" % [args[0], error_string(FileAccess.get_open_error())])
		quit(1)
		return
	f.store_string(text)
	f.close()
	if f.get_error() != OK:
		push_error("godot_licenses: writing %s failed (%s)" % [args[0], error_string(f.get_error())])
		quit(1)
		return
	print("godot_licenses: wrote %s (%d bytes)" % [args[0], text.to_utf8_buffer().size()])
	quit(0)


## The whole notice: the engine's licence, the components, then each licence's text.
static func build() -> String:
	var info := Engine.get_version_info()
	var out := PackedStringArray()
	out.append("Godot Engine %s (%s)" % [info.string, info.hash])
	out.append("https://godotengine.org/license")
	out.append("")
	out.append(Engine.get_license_text().strip_edges())
	out.append("")
	out.append("=".repeat(72))
	out.append("Third-party components")
	out.append("=".repeat(72))
	for c: Dictionary in Engine.get_copyright_info():
		out.append("")
		out.append(c.name)
		for part: Dictionary in c.parts:
			out.append("  Files: %s" % ", ".join(part.files))
			for line: String in part.copyright:
				out.append("  Copyright: %s" % line)
			out.append("  License: %s" % part.license)
	out.append("")
	out.append("=".repeat(72))
	out.append("Licence texts")
	out.append("=".repeat(72))
	var licences := Engine.get_license_info()
	var names := licences.keys()
	names.sort()
	for n: String in names:
		out.append("")
		out.append("License: %s" % n)
		out.append("")
		out.append(String(licences[n]).strip_edges())
	return "\n".join(out) + "\n"
