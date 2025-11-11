@tool
extends "editor_code_highlighter.gd"

var _hovering_symbol: String
var _hovering_symbol_tooltip: String
var _err_lines: Dictionary[int, String]

const _Parse := preload("parser.gd")

func _get_color(editor_setting_name: String) -> Color:
	return EditorInterface.get_editor_settings().get_setting(editor_setting_name)


class CustomCodeEdit extends CodeEdit:
	func _make_custom_tooltip(for_text: String) -> Object:
		if for_text.is_empty():
			return null

		var label := Label.new()
		label.text = for_text
		if for_text.begins_with("ERROR"):
			label.modulate = Color.ORANGE_RED
		return label


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
	te.tag_saved_version()

	var timer := Timer.new()
	timer.wait_time = 0.25
	timer.autostart = false
	timer.one_shot = true
	timer.timeout.connect(_check_syntax)
	te.add_child(timer)

	te.symbol_tooltip_on_hover = true
	te.line_folding = true
	te.gutters_draw_line_numbers = true
	te.gutters_zero_pad_line_numbers = true
	te.gutters_draw_fold_gutter = true
	te.scroll_smooth = true
	te.caret_blink = true
	te.highlight_all_occurrences = true
	te.highlight_current_line = true

	te.text_changed.connect(timer.start)
	te.symbol_hovered.connect(_on_symbol_hovered)

	### HACK
	te.set_tooltip_request_func.call_deferred(_request_symbol_tooltip)

func _on_symbol_hovered(symbol: String, line: int, column: int) -> void:
	_hovering_symbol = symbol
	_hovering_symbol_tooltip = ""

	if line in _err_lines:
		_hovering_symbol_tooltip = _err_lines[line]
		get_text_edit().tooltip_text = _hovering_symbol_tooltip
		return

	get_text_edit().tooltip_text = ""
	if not symbol.is_valid_identifier():
		return

	var te := get_text_edit()
	var line_text := te.get_line(line)

	var comment_column := line_text.find("#")
	if comment_column >= 0 and column >= comment_column:
		return

	var redirect_column := line_text.find("->")
	if redirect_column >= 0 and column > redirect_column:
		_hovering_symbol_tooltip = "Redirect: " + line_text.split("->", false, 1)[1].split("#", false, 1)[0].strip_edges()
		return

	if line_text.strip_edges().begins_with("@"):
		_hovering_symbol_tooltip = "Domain: " + symbol
	else:
		_hovering_symbol_tooltip = "Tag: " + symbol


func _request_symbol_tooltip(hovered_word: String) -> String:
	if _hovering_symbol_tooltip.begins_with("ERROR"):
		return _hovering_symbol_tooltip

	if _hovering_symbol != hovered_word:
		return ""
	return _hovering_symbol_tooltip


func _get_indent_count(text: String) -> int:
	var ret := 0
	while text.begins_with("\t"):
		ret += 1
		text = text.substr(1)
	return ret


func _check_syntax() -> void:
	var te := get_text_edit()

	var err_lines: Dictionary[int, String] = _Parse.parse_format_errors(te.text, 10)
	if err_lines.is_empty():
		_Parse.parse(te.text, err_lines)

	# Recover
	for line in _err_lines:
		if not line in err_lines:
			te.set_line_background_color(line, Color.TRANSPARENT)
	# Apply
	for line in err_lines:
		te.set_line_background_color(line, Color.INDIAN_RED)

	_err_lines = err_lines

	if is_instance_valid(te.get_viewport()):
		var mouse_pos := te.get_local_mouse_pos()
		var cl := te.get_line_column_at_pos(mouse_pos)
		if cl.y in _err_lines:
			te.tooltip_text = _err_lines[cl.y]
			_hovering_symbol_tooltip = te.tooltip_text
		else:
			te.tooltip_text = ""
			if _hovering_symbol.is_empty():
				_hovering_symbol_tooltip = ""
			else:
				_on_symbol_hovered(_hovering_symbol, cl.y, cl.x)

	return _err_lines.is_empty()


func _update_cache() -> void:
	super ()
	_setup_syntax_check()
	_check_syntax()

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
