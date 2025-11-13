@tool
extends "editor_code_highlighter.gd"

const _Parser := preload("parser.gd")

static func _get_color(editor_setting_name: String) -> Color:
	return CustomCodeEdit._get_color(editor_setting_name)


class CustomCodeEdit extends CodeEdit:
	static func _get_color(editor_setting_name: String) -> Color:
		return EditorInterface.get_editor_settings().get_setting(editor_setting_name)

	var err_lines: Dictionary[int, String]

	func _init() -> void:
		var timer := Timer.new()
		timer.wait_time = 0.25
		timer.autostart = false
		timer.one_shot = true
		timer.timeout.connect(check_syntax)
		add_child(timer)
		text_changed.connect(timer.start)

	func setup() -> void:
		symbol_tooltip_on_hover = true
		line_folding = true
		gutters_draw_line_numbers = true
		gutters_zero_pad_line_numbers = true
		gutters_draw_fold_gutter = true
		scroll_smooth = true
		caret_blink = true
		highlight_all_occurrences = true
		highlight_current_line = true

		set_tooltip_request_func(_request_symbol_tooltip)

	func check_syntax() -> void:
		var errors: Dictionary[int, String] = _Parser.parse_format_errors(text, 10)
		if errors.is_empty():
			_Parser.parse(text, errors)

		# Recover
		for l in get_line_count():
			set_line_background_color(l, Color(0.0, 0.0 ,0.0, 0.0))

		# Apply
		var _mark_color := _get_color("text_editor/theme/highlighting/mark_color")
		var _warn_color := _get_color("text_editor/theme/highlighting/warning_color")
		for line in errors:
			var line_text := errors[line]
			if line_text.begins_with("ERROR"):
				set_line_background_color(line, _mark_color)
			elif line_text.begins_with("WARN"):
				set_line_background_color(line, _warn_color)
			else:
				assert(false, "Unexpected case.")

		err_lines = errors
		return err_lines.is_empty()

	func _request_symbol_tooltip(hovered_word: String) -> String:
		var err_msg := _get_err_msg()
		if not err_msg.is_empty():
			return err_msg

		if not hovered_word.is_valid_identifier():
			return ""

		var cl := get_line_column_at_pos(get_local_mouse_pos())
		var line := cl.y
		var column := cl.x
		var line_text := get_line(cl.y)

		var comment_column := line_text.find("#")
		if comment_column >= 0 and column >= comment_column:
			return ""

		var redirect_column := line_text.find("->")
		var ret := ""
		if redirect_column >= 0 and column > redirect_column:
			ret = "Redirect: " + line_text.split("->", false, 1)[1].split("#", false, 1)[0].strip_edges()
		elif line_text.strip_edges().begins_with("@"):
			ret = "Domain: " + hovered_word
		else:
			ret = "Tag: " + hovered_word

		return ret

	func _make_custom_tooltip(for_text: String) -> Object:
		if for_text.is_empty():
			return null

		var label := Label.new()
		label.text = for_text
		if for_text.begins_with("ERROR"):
			label.modulate = Color.ORANGE_RED
		elif for_text.begins_with("WARN"):
			label.modulate = Color.YELLOW

		return label

	func _get_err_msg(at_position: Vector2 = get_local_mouse_pos()) -> String:
		var cl := get_line_column_at_pos(at_position)
		if cl.y in err_lines:
			return err_lines[cl.y]
		else:
			return ""


func _setup_syntax_check() -> void:
	var te := get_text_edit()
	if te.get_script() == CustomCodeEdit:
		return

	var prop_list := {}
	for p in te.get_property_list():
		if p.usage & PROPERTY_USAGE_STORAGE and p.name != "script":
			prop_list[p.name] = te.get(p.name)

	te.set_script(CustomCodeEdit)
	for p in prop_list:
		te.set(p, prop_list[p])
	te.setup.call_deferred()
	te.check_syntax()
	te.tag_saved_version()


func _update_cache() -> void:
	super ()
	_setup_syntax_check()

	clear_keyword_colors()
	clear_member_keyword_colors()
	clear_color_regions()

	number_color = _get_color("text_editor/theme/highlighting/text_color")
	member_color = _get_color("text_editor/theme/highlighting/text_color")
	function_color = _get_color("text_editor/theme/highlighting/text_color")
	symbol_color = _get_color("text_editor/theme/highlighting/symbol_color")

	var comment_color := _get_color("text_editor/theme/highlighting/comment_color")
	add_color_region("#", "", comment_color, true)

	var doc_comment_color := _get_color("text_editor/theme/highlighting/doc_comment_color")
	add_color_region("##", "", doc_comment_color, true)


func _create() -> EditorSyntaxHighlighter:
	var ret = get_script().new()
	return ret


func _get_name() -> String:
	return "DTagDefine"


func _get_supported_languages() -> PackedStringArray:
	return ["dtag"]
