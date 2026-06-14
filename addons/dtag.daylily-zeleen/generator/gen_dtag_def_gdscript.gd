@tool

const Parser := preload("../editor/parser.gd")
const DomainDef := Parser.DomainDef
const TagDef := Parser.TagDef

const DOMAIN_NAME := "DOMAIN_NAME"
const GEN_FILE := "res://dtag_def.gen.gd"

func generate(parse_result: Dictionary[String, RefCounted], redirect_map: Dictionary[String, String]) -> String:
	var old_code := FileAccess.get_file_as_string(GEN_FILE)

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
			text += _generate_domain_class_recursively(def, "", identifiers)
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

	var script_editor := EditorInterface.get_script_editor()
	var opened_scripts := script_editor.get_open_scripts()
	if opened_scripts.any(func(s: Script) -> bool: return s.resource_path == GEN_FILE):
		var code_editors := script_editor.get_open_script_editors()\
			.map(func(se: ScriptEditorBase) -> CodeEdit: return se.get_base_editor())\
			.filter(func(ce: CodeEdit) -> bool: return is_instance_valid(ce))

		var reloaded :Array[bool] = [false]
		var func_reload_text := func(ce: CodeEdit, reload_flag :Array[bool]) -> void:
			ce.text = text
			ce.tag_saved_version()
			reload_flag[0] = true

		if code_editors.all(func(ce: CodeEdit) -> bool: return ce.get_saved_version() == ce.get_version()):
			var ce_list := code_editors.filter(func(ce: CodeEdit) -> bool: return ce.text == old_code)
			assert(ce_list.size() >= 0, "异常情况？")
			if ce_list.size() == 1:
				var ce := code_editors[0] as CodeEdit
				func_reload_text.call(ce, reloaded)

		if not reloaded[0]: ## HACK
			var candidates := code_editors.filter(func(ce: CodeEdit) -> bool: return ce.text.contains("class_name DTagDef\n"))
			if candidates.size() == 1:
				var ce := code_editors[0] as CodeEdit
				func_reload_text.call(ce, reloaded)

		if not reloaded[0]:
			push_warning("[DTag]: \"%s\" is opened in editor but can't be reload, please handle this issue by youself." % [GEN_FILE])

	EditorInterface.get_resource_filesystem().update_file(GEN_FILE)
	print("[DTag]: \"%s\" is generated." % [GEN_FILE])
	return GEN_FILE


#region Generate
static func _generate_domain_class_recursively(def: DomainDef, prev_tag: String, r_identifiers: PackedStringArray) -> String:
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
		ret += _generate_domain_class_recursively(domain, domain_text, r_identifiers).indent("\t")

		
	return ret
#endregion Generate
