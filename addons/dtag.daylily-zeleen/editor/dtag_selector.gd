@tool
extends ConfirmationDialog

const _DISABLED_COLOR := Color.DIM_GRAY
const _REDIRECTED_COLOR := Color.DARK_ORANGE
const _REDIRECTED_DISABLED_COLOR := Color.CHOCOLATE

signal selected(tag_or_domain: StringName, confirm: bool)

const CACHE_FILE := "res://.godot/editor/dtag_cache.cfg"

@export_group("_internal_", "_")
@export var _search_line_edit: LineEdit
@export var _selected_label: Label
@export var _domain_limitation_label: Label
@export var _tree: Tree

var _selected: StringName = &"":
	set(v):
		_selected = v
		_selected_label.text = _selected
		_selected_label.tooltip_text = _selected
		get_ok_button().disabled = _selected.is_empty()
var _domain_limitation: StringName:
	set(v):
		_domain_limitation = v
		_domain_limitation_label.text = _domain_limitation
		_domain_limitation_label.tooltip_text = _domain_limitation
		_domain_limitation_label.get_parent().visible = not v.is_empty()
var _select_tag: bool

var _leaves_item: Array[TreeItem]
var _cache_cfg: ConfigFile

func _ready() -> void:
	hide()
	confirmed.connect(_on_confirmed)
	_search_line_edit.text_changed.connect(_on_search_text_changed)
	_tree.item_activated.connect(_on_tree_item_activated)
	_tree.item_selected.connect(_on_tree_item_selected)
	_tree.columns = 2
	_tree.set_column_title(1, "Redirect")


# r_text_ref, 0 - tag_text, 1 - redirect_text
func _add_item(parent: TreeItem, tag_name: String, is_tag: bool, r_text_ref: Array = []) -> TreeItem:
	var prev_domain := parent.get_metadata(0) as String
	var tag_text := tag_name if prev_domain.is_empty() else ("%s.%s" % [prev_domain, tag_name])
	var redirect := _get_cache_redirect(tag_text, "")

	r_text_ref.clear()
	r_text_ref.push_back(tag_text)
	r_text_ref.push_back(redirect)

	var item := parent.create_child()
	item.set_auto_translate_mode(0, Node.AUTO_TRANSLATE_MODE_DISABLED)
	item.set_auto_translate_mode(1, Node.AUTO_TRANSLATE_MODE_DISABLED)
	item.set_text(0, tag_text)
	item.set_metadata(0, tag_text)
	item.set_tooltip_text(0, _get_cache_desc(tag_text, tag_text))

	item.set_text(1, redirect)
	item.set_tooltip_text(1, _get_cache_desc(redirect, redirect))
	item.set_custom_color(1, Color.DARK_GRAY)
	item.set_selectable(1, not redirect.is_empty())
	item.set_metadata(1, redirect)

	if is_tag:
		if not _select_tag:
			item.set_selectable(0, false)
			item.set_selectable(1, false)
			item.set_custom_color(0, _DISABLED_COLOR)
	else:
		if _select_tag:
			item.set_selectable(0, false)
			item.set_selectable(1, false)
			item.set_custom_color(0, _DISABLED_COLOR)

	if not redirect.is_empty():
		var color := _REDIRECTED_COLOR
		if item.get_custom_color(0).is_equal_approx(_DISABLED_COLOR):
			color = _REDIRECTED_DISABLED_COLOR
		item.set_custom_color(0, color)
		item.set_text(0, item.get_text(0) + "[Deprecated]")

	return item


func _is_fit_limitation(tag_text: String, redirect_text: String) -> bool:
	return _domain_limitation.is_empty() \
			or _domain_limitation.begins_with(tag_text + ".") or tag_text.begins_with(_domain_limitation) \
			or _domain_limitation.begins_with(redirect_text + ".") or redirect_text.begins_with(_domain_limitation)


func _is_incompatible_with_limitation(item: TreeItem) -> bool:
	return item.get_child_count() <= 0 and not _is_fit_limitation(item.get_metadata(0), item.get_metadata(1))


func setup(p_selected: StringName, domain_limitation: PackedStringArray, select_tag: bool) -> void:
	_domain_limitation = (".".join(domain_limitation) + ".") if not domain_limitation.is_empty() else ""
	_select_tag = select_tag
	if not _domain_limitation.is_empty():
		title += ": " + _domain_limitation
	_selected = p_selected

	if select_tag:
		title = "Select DTag"
	else:
		title = "Select DTag Domain"

	_leaves_item.clear()
	_tree.clear()
	var root := _tree.create_item()
	root.set_text(0, "")
	root.set_metadata(0, "")
	root.set_tooltip_text(0, "")

	const DEF_CLASS := &"DTagDef"
	var def_class_path: String = ""
	for class_info in ProjectSettings.get_global_class_list():
		if class_info.class == DEF_CLASS:
			def_class_path = class_info.path

	_cache_cfg = ConfigFile.new()
	_cache_cfg.load(CACHE_FILE)

	if not def_class_path.is_empty():
		var def_script := load(def_class_path) as Script
		_setup_item_recursively(root, def_script)

	if not _domain_limitation.is_empty() and _tree.get_root().get_child_count() == 0:
		print_rich("[color=yellow][DTag]: domain limitation \"%s\" is not exists in this project.[/color]" % [_domain_limitation])
	_on_search_text_changed(_search_line_edit.text)
	popup_centered_ratio(0.6)


func _get_cache_desc(tag_text: String, default: String) -> String:
	assert(is_instance_valid(_cache_cfg))
	var ret := _cache_cfg.get_value(tag_text, "desc", "") as String
	if ret.is_empty():
		return default
	return ret


func _get_cache_redirect(tag_text: String, default: String) -> String:
	var redirected := DTag.redirect(tag_text)
	if tag_text == redirected:
		return default
	return redirected


func _setup_item_recursively(parent: TreeItem, def: Script) -> void:
	var const_map := def.get_script_constant_map()
	var prev_domain := parent.get_metadata(0) as String

	# 排序(同一层级下被重定向的目标滞后)
	var keys :Array[StringName]
	var redirected_keys: Array[StringName]
	for k: String in const_map:
		if k in [&"DOMAIN_NAME", &"_REDIRECT_NAP"]:
			continue

		var next_def: Variant = const_map[k]
		
		var tag_text := k if prev_domain.is_empty() else ("%s.%s" % [prev_domain, k])
		var redirect := _get_cache_redirect(tag_text, "")
		if redirect.is_empty():
			keys.push_back(k)
		else:
			redirected_keys.push_back(k)

	var func_add := func(k: StringName) -> void:
		var next_def: Variant = const_map[k]
		var tag_text := k if prev_domain.is_empty() else ("%s.%s" % [prev_domain, k])
		var redirect := _get_cache_redirect(tag_text, "")
		var is_tag := typeof(next_def) == TYPE_STRING_NAME
		assert(is_tag or (next_def is Script and next_def.is_abstract()))
		var item := _add_item(parent, k, typeof(next_def) == TYPE_STRING_NAME)

		if not is_tag:
			_setup_item_recursively(item, next_def)

	# 将被重定向的对象滞后
	for k in keys:
		func_add.call(k)
	for k in redirected_keys:
		func_add.call(k)

	# 过滤与记录
	for item in parent.get_children():
		if _is_incompatible_with_limitation(item):
			# 过滤命名空间限制
			item.free()
			continue
		if item.get_child_count() <= 0:
			_leaves_item.push_back(item)


func _update_parent_item_visible_recursively(item: TreeItem) -> void:
	var parent := item.get_parent()
	if parent == _tree.get_root():
		return

	var parent_visible := false
	for c in parent.get_children():
		if c.visible:
			parent_visible = true

	parent.visible = parent_visible
	_update_parent_item_visible_recursively(parent)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not visible:
			selected.emit(&"", false)


func _on_search_text_changed(search_text: String) -> void:
	for item in _leaves_item:
		if search_text.is_empty():
			item.visible = true
		else:
			var tag := item.get_metadata(0) as String
			var redirect := item.get_metadata(1) as String
			item.visible = tag.contains(search_text) or redirect.contains(search_text)

	for item in _leaves_item:
		_update_parent_item_visible_recursively(item)


func _on_confirmed() -> void:
	if not _selected.is_empty():
		selected.emit(_selected, true)
		hide()


func _on_tree_item_activated() -> void:
	var item := _tree.get_selected()
	if not is_instance_valid(item):
		return

	if not item.is_selectable(_tree.get_selected_column()):
		return

	selected.emit(_selected, true)
	hide()


func _on_tree_item_selected() -> void:
	var item := _tree.get_selected()
	if not is_instance_valid(item):
		return

	if not item.is_selectable(_tree.get_selected_column()):
		return

	_selected = _tree.get_selected().get_metadata(_tree.get_selected_column())
