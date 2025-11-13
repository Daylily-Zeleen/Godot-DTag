@tool
@static_unload
class_name DTag
extends Resource

## Tag Domain, use as limitation.
@export_custom(PROPERTY_HINT_NONE, "DTagDomainEdit") var domain: Array[StringName]:
	set(v):
		if Engine.is_editor_hint():
			domain = v
			if not value.is_empty() and not is_domain_compatible(value):
				print_rich("[color=yellow][DTag]: \"%s\" tag is incompatible with domain \"%s\", will be reset to &\"\".[/color]" % [value, ".".join(domain)])
				value = &""
		else:
			domain.assign(redirect(".".join(v)).split(".", false))
		notify_property_list_changed()
## Tag actual value.
@export_storage var value :StringName = &""

const VALUE_ALIAS := &"tag"


func _get_property_list() -> Array[Dictionary]:
	var ret :Array[Dictionary] = [
		{
			name = VALUE_ALIAS,
			type = TYPE_STRING_NAME,
			hint = PROPERTY_HINT_NONE,
			hint_string = "DTagEdit" if domain.is_empty() else ("DTagEdit: " + ".".join(domain)),
			usage = PROPERTY_USAGE_EDITOR,
		},
	]
	return ret


func _get(property: StringName) -> Variant:
	match property:
		VALUE_ALIAS:
			return value
		_:
			return null


func _set(property: StringName, p_value: Variant) -> bool:
	match property:
		VALUE_ALIAS:
			if domain.is_empty():
				value = p_value
				domain.assign(value.split(".", false))
				domain.pop_back()
				notify_property_list_changed()
			else:
				if Engine.is_editor_hint():
					# Validate in editor
					var splits := p_value.split(".", false) as PackedStringArray
					var valid := true
					for i in range(mini(domain.size(), splits.size())):
						if domain[i] != splits[i]:
							valid = false
							printerr('Set property "tag" failed, new tag ”%s“ is incompatible with required domain "%s". If it is expect, please clear "domain" first.' % [p_value, ".".join(domain)])
							break

					if valid:
						value = p_value
						notify_property_list_changed()
				else:
					value = redirect(p_value)

			return true
		_:
			return false


func is_tag_equal(other_tag: Variant) -> bool:
	assert(other_tag is DTag or other_tag is StringName)
	if other_tag is DTag:
		return value == other_tag.value
	elif other_tag is StringName or other_tag is String:
		return value == other_tag

	assert(false, "Unrecognized type")
	return false


func is_domain_compatible(other_domain: Variant) -> bool:
	if domain.is_empty():
		return true

	if other_domain is DTag:
		for i in range(mini(other_domain.domain.size(), domain.size())):
			if other_domain.domain[i] != domain[i]:
				return false
		return true
	elif other_domain is StringName or other_domain is String:
		var splits := other_domain.split(".", false) as PackedStringArray
		for i in range(mini(splits.size(), domain.size())):
			if splits[i] != domain[i]:
				return false
		return true
	elif typeof(other_domain) >= TYPE_ARRAY:
		for i in range(mini(other_domain.size(), domain.size())):
			if other_domain[i] != domain[i]:
				return false
		return true

	assert(false, "Unrecognized type")
	return false


#region Static
static var _tag_cache: Dictionary[StringName, DTag]
## Create tag from StringName with caching.
static func as_tag(p_tag: StringName) -> DTag:
	if Engine.is_editor_hint():
		var ret := DTag.new()
		ret.tag = p_tag
		return ret
	else:
		if _tag_cache.has(p_tag):
			return _tag_cache.get(p_tag)
		var ret := DTag.new()
		ret.tag = p_tag
		_tag_cache[p_tag] = ret
		return ret


static var _domain_cache: Dictionary[StringName, DTag]
## Create tag domain from StringName with caching.
static func as_domain(p_domain: StringName) -> DTag:
	if Engine.is_editor_hint():
		var ret := DTag.new()
		ret.domain = p_domain.split(".", false)
		return ret
	else:
		if _domain_cache.has(p_domain):
			return _domain_cache.get(p_domain)
		var ret := DTag.new()
		ret.domain = p_domain.split(".", false)
		_domain_cache[p_domain] = ret
		return ret


static var _dtag_def: GDScript:
	get:
		if not is_instance_valid(_dtag_def):
			_dtag_def = ResourceLoader.load("res://dtag_def.gen.gd", "GDScript", ResourceLoader.CACHE_MODE_REUSE)
		assert(is_instance_valid(_dtag_def))
		return _dtag_def
# Redirect tag.
static func redirect(ori_tag: StringName) -> StringName:
	return _dtag_def[&"_REDIRECT_MAP"].get(ori_tag, ori_tag)

#endregion Static