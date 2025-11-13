@tool

const Parser := preload("../editor/parser.gd")
const DomainDef := Parser.DomainDef
const TagDef := Parser.TagDef

const DOMAIN_NAME := "DOMAIN_NAME"
const GEN_FILE := "res://dtag_def.gen.gd"

func generate(parse_result: Dictionary[String, RefCounted], redirect_map: Dictionary[String, String]) -> String:
	var fa := FileAccess.open(GEN_FILE, FileAccess.WRITE)
	if not is_instance_valid(fa):
		printerr("[DTag] Generate \"%s\" failed: %s" % [GEN_FILE, error_string(FileAccess.get_open_error())])
		return ""

	var identifiers: PackedStringArray # TODO: Check identifiers.
	var text := "# NOTE: This file is generated, any modify maybe discard.\n"
	text += "class_name DTagDef\n\n"

	for def in parse_result.values():
		if def is TagDef:
			text += "\n"
			if not def.desc.is_empty():
				text += "## %s\n" % def.desc
			text += "const %s = &\"%s\"\n" % [def.name, def.redirect if not def.redirect.is_empty() else def.name]

			if not identifiers.has(def.name):
				identifiers.push_back(def.name)

	text += "\n"
	for def in parse_result.values():
		if def is DomainDef:
			text += _generate_doman_class_recursively(def, "", identifiers)
			text += "\n"

	text += "# ===== Redirect map. =====\n"
	text += "const _REDIRECT_MAP: Dictionary[StringName, StringName] = {"
	if not redirect_map.is_empty():
		text += "\n"

		for k in redirect_map:
			var redirected := redirect_map[k]
			while redirect_map.has(redirected):
				var next := redirect_map[redirected]
				if next == k:
					printerr("[DTag] Cycle redirect %s." % k)
					break
				redirected = next
			text += '\t&"%s" : &"%s",\n' % [k, redirect_map[k]]
	text += "}\n"

	fa.store_string(text)
	fa.close()

	var opened_scripts := EditorInterface.get_script_editor().get_open_scripts()
	for i in range(opened_scripts.size()):
		var script := opened_scripts[i] as Script
		if script.resource_path == GEN_FILE:
			var se := EditorInterface.get_script_editor().get_open_script_editors().get(i) as ScriptEditorBase
			if is_instance_valid(se):
				var te := se.get_base_editor() as CodeEdit
				if is_instance_valid(te):
					te.text = text
					te.tag_saved_version()
			break

	print("[DTag]: \"%s\" is generated." % [GEN_FILE])
	return GEN_FILE


#region Generate
static func _generate_doman_class_recursively(def: DomainDef, prev_tag: String, r_identifiers: PackedStringArray) -> String:
	var domain_text :String
	if def.redirect.is_empty():
		domain_text = def.name if prev_tag.is_empty() else ("%s.%s" % [prev_tag, def.name])
	else:
		domain_text = def.redirect

	if not r_identifiers.has(def.name):
		r_identifiers.push_back(def.name)

	var ret := ""
	if not def.desc.is_empty():
		ret += "## %s\n" % def.desc
	ret += "@abstract class %s extends Object:\n" % def.name
	ret += "\t## StringName of this domain.\n"
	ret += "\tconst %s = &\"%s\"\n" % [DOMAIN_NAME, domain_text]

	for tag: TagDef in def.tag_list.values():
		var tag_text :String
		if tag.redirect.is_empty():
			tag_text = "%s.%s" % [domain_text, tag.name]
		else:
			tag_text = tag.redirect

		if not tag.desc.is_empty():
			ret += "\t## %s\n" % tag.desc
		ret += "\tconst %s = &\"%s\"\n" % [tag.name, tag_text]

		if not r_identifiers.has(def.name):
			r_identifiers.push_back(def.name)

	ret += "\n"

	for domain: DomainDef in def.sub_domain_list.values():
		ret += _generate_doman_class_recursively(domain, domain_text, r_identifiers).indent("\t")

		
	return ret
#endregion Generate
