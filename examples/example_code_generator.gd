@tool

const Parser := preload("res://addons/dtag.daylily-zeleen/editor/parser.gd")
const EntryDef = Parser.EntryDef


func generate(parse_result: Dictionary[String, EntryDef], redirect_map: Dictionary[String, String]) -> String:
	for k in parse_result:
		print(k)

	return ""
