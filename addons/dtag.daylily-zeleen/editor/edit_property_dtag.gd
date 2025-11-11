@tool
extends EditorProperty

var _domain_limitation :PackedStringArray

var _tag_button := Button.new()

var _select_tag: bool
var _selector: Window

func _init() -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(hbox)

	_tag_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	_tag_button.pressed.connect(_on_tag_button_pressed)
	hbox.add_child(_tag_button)

	var clear_btn := Button.new()
	clear_btn.icon = EditorInterface.get_base_control().get_theme_icon("clear", &"LineEdit")
	clear_btn.tooltip_text = "Clear"
	clear_btn.pressed.connect(_on_clear_btn_pressed)
	hbox.add_child(clear_btn)


func setup(domain_limitation: PackedStringArray, select_tag: bool, selector: Window) -> void:
	_domain_limitation = domain_limitation
	_select_tag = select_tag
	_selector = selector


func _set_read_only(read_only: bool) -> void:
	_tag_button.disabled = read_only


func _update_property() -> void:
	var obj := get_edited_object()
	var prop := get_edited_property()
	var v := obj.get(prop)

	if typeof(v) in [TYPE_STRING, TYPE_STRING_NAME]:
		_tag_button.text = v
	elif v is Array or v is PackedStringArray:
		_tag_button.text = ".".join(v)

	if _select_tag:
		_tag_button.tooltip_text = "DTag: " + _tag_button.text
	else:
		_tag_button.tooltip_text = "DTag Domain: " + _tag_button.text


func _on_tag_button_pressed() -> void:
	var obj := get_edited_object()
	var prop := get_edited_property()
	var v := obj.get(prop)

	if typeof(v) in [TYPE_STRING, TYPE_STRING_NAME]:
		_selector.setup(v, _domain_limitation, _select_tag)
	elif typeof(v) in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]:
		_selector.setup(".".join(v), _domain_limitation, _select_tag)
	else:
		assert(false)
		return

	var result := await _selector.selected as Array
	var selected := result[0] as StringName
	var confirm := result[1] as bool

	if confirm:
		var t := typeof(v)
		match t:
			TYPE_STRING, TYPE_STRING_NAME:
				emit_changed(prop, selected)
			TYPE_ARRAY:
				var domain :Array = selected.split(".", false)
				emit_changed(prop, Array(domain, TYPE_STRING_NAME, &"", null))
			_:
				var domain :Array = selected.split(".", false)
				emit_changed(prop, type_convert(domain, t))


func _on_clear_btn_pressed() -> void:
	var obj := get_edited_object()
	var prop := get_edited_property()
	var v := obj.get(prop)
	var t := typeof(v)
	match t:
		TYPE_STRING, TYPE_STRING_NAME:
			emit_changed(prop, &"")
		TYPE_ARRAY:
			emit_changed(prop, Array([], TYPE_STRING_NAME, &"", null))
		_:
			emit_changed(prop, type_convert(null, t))
