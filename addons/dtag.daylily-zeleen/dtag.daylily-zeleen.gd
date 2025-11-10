@tool
extends EditorPlugin


class EditorInspectorPluginTag extends EditorInspectorPlugin:
	var _selector: Window
	func _init(selector: Window) -> void:
		_selector = selector

	func _can_handle(object) -> bool:
		return true

	func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: PropertyUsageFlags, wide: bool) -> bool:
		const TAG_EDIT_PREFIX := "DTagEdit"
		const TAG_DOMAIN_EDIT_PREFIX := "DTagDomainEdit"
		var select_tag := hint_string.begins_with(TAG_EDIT_PREFIX)
		var select_domain := hint_string.begins_with(TAG_DOMAIN_EDIT_PREFIX)
		if type in [TYPE_STRING, TYPE_STRING_NAME, TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]:
			var splits := hint_string.split(":", false, 1)
			var domain_limitation := [] if splits.size() < 2 else (splits[1].strip_edges(true).split(".", false))
			if select_tag:
				var prop_edit := preload("editor/edit_property_dtag.gd").new()
				prop_edit.setup(domain_limitation, true, _selector)
				add_property_editor(name, prop_edit)
				return true
			elif select_domain:
				var prop_edit := preload("editor/edit_property_dtag.gd").new()
				prop_edit.setup(domain_limitation, false, _selector)
				add_property_editor(name, prop_edit)
				return true
		return false

var _selector: Window
var _inspector_plugin: EditorInspectorPluginTag
var _highlighter := preload("editor/dtag_syntax_highlighter.gd").new()

const ESETTING_TEXTFILE_EXTENDSIONS := "docks/filesystem/textfile_extensions"
const OVERRIDE_SETTING_TEXTFILE_EXTENDSIONS := "editor_overrides/docks/filesystem/textfile_extensions"

const SETTINGS_CODE_GENERATOR := "DTag/basic/code_generators"

func _enter_tree() -> void:
	# Setting code generators
	if not ProjectSettings.has_setting(SETTINGS_CODE_GENERATOR):
		ProjectSettings.set_setting(SETTINGS_CODE_GENERATOR, [])
	ProjectSettings.set_initial_value(SETTINGS_CODE_GENERATOR, [])
	ProjectSettings.set_as_basic(SETTINGS_CODE_GENERATOR, true)
	var property_info = {
		"name": SETTINGS_CODE_GENERATOR,
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_ARRAY_TYPE,
		"hint_string": "GDScript",
	}
	ProjectSettings.add_property_info(property_info)

	# Settings recognize "*.dtag"
	if not ProjectSettings.has_setting(OVERRIDE_SETTING_TEXTFILE_EXTENDSIONS):
		ProjectSettings.set_setting(OVERRIDE_SETTING_TEXTFILE_EXTENDSIONS, EditorInterface.get_editor_settings().get_setting(ESETTING_TEXTFILE_EXTENDSIONS))

	var extensions := ProjectSettings.get_setting_with_override(OVERRIDE_SETTING_TEXTFILE_EXTENDSIONS) as String
	var valid := false
	for e in extensions.split(","):
		if e.strip_edges() == "dtag":
			valid = true
			break
	if not valid:
		extensions += ",dtag"
	ProjectSettings.set_setting(OVERRIDE_SETTING_TEXTFILE_EXTENDSIONS, extensions)
	
	_selector = preload("editor/dtag_selector.tscn").instantiate()
	add_child(_selector)
	
	_inspector_plugin = EditorInspectorPluginTag.new(_selector)
	add_inspector_plugin(_inspector_plugin)

	add_tool_menu_item("Generate dtag_def.gen.gd", _on_generate_dtag_def_gen_requested)

	EditorInterface.get_script_editor().register_syntax_highlighter(_highlighter)


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector_plugin)

	remove_tool_menu_item("Generate dtag_def.gen.gd")

	EditorInterface.get_script_editor().unregister_syntax_highlighter(_highlighter)


func _on_generate_dtag_def_gen_requested() -> void:
	var code_generators := ProjectSettings.get_setting(SETTINGS_CODE_GENERATOR) as Array

	var generators: Array[Object]
	for s in code_generators:
		s = s as GDScript
		if not is_instance_valid(s):
			continue

		var g := s.new() as Object
		var valid := false

		if g.has_method(&"generate"):
			var m := g.get_method_list().filter(func(m: Dictionary) -> bool: return m.name == &"generate").front() as Dictionary
			if m.args.size() == 2:
				valid = true

		if valid:
			generators.push_back(g)
		else:
			if g is RefCounted:
				pass
			elif g is Node:
				g.queue_free()
			else:
				g.free()
			continue

	var tool := preload("tool/tool_generate_dtag_def.gd").new() as EditorScript
	tool.generate(tool.get_dtag_recursively(), generators)

	for g in generators:
		if g is RefCounted:
			pass
		elif g is Node:
			g.queue_free()
		else:
			g.free()
