@tool
extends EditorScript

const Parser := preload("../editor/parser.gd")
const EntryDef := Parser.EntryDef
const DomainDef := Parser.DomainDef
const TagDef := Parser.TagDef
const _DTagPaths := preload("../script/dtag_paths.gd")


func _run() -> void:
	generate(get_dtag_recursively(), [])


static func get_dtag_recursively(base_dir := "res://", r_files: PackedStringArray = []) -> PackedStringArray:
	if base_dir == "res://addons/":
		return r_files

	for f in DirAccess.get_files_at(base_dir):
		if f.begins_with("."): # Skip hidden files
			continue

		if f.get_extension().to_lower() == "dtag":
			r_files.push_back(base_dir.path_join(f))

	for d in DirAccess.get_directories_at(base_dir):
		if d.begins_with("."): # Skip hidden files
			continue

		var next_dir := base_dir.path_join(d)
		if next_dir.begins_with("res://addons"):
			continue

		get_dtag_recursively(next_dir, r_files)

	return r_files


static func generate(files: PackedStringArray, generators: Array[Object]) -> void:
	var validated: PackedStringArray
	for f in files:
		if f.get_extension().to_lower() != "dtag":
			continue
		validated.push_back(f)

	# Validate Format
	for f in validated:
		var text := FileAccess.get_file_as_string(f)
		if FileAccess.get_open_error() != OK:
			printerr("[DTag] generate failed, can't open \"%s\": %s" % [f, error_string(FileAccess.get_open_error())])
			return
		var errors := Parser.parse_format_errors(text)
		if not errors.is_empty():
			printerr("[DTag] Generate failed, parse error in \"%s\": " % f)
			for line in errors:
				printerr("- Line %d: %s " % [line, errors[line].trim_prefix("ERROR:")])
			return

	# Parse and validate identifiers
	var parse_errors: Dictionary[int, String]
	var parse_results: Dictionary[String, Dictionary]
	for f in validated:
		var text := FileAccess.get_file_as_string(f)
		if FileAccess.get_open_error() != OK:
			printerr("[DTag] generate failed, can't open \"%s\": %s" % [f, error_string(FileAccess.get_open_error())])
			return

		var result := Parser.parse(text, parse_errors)
		if not parse_errors.is_empty():
			printerr("[DTag] Generate failed, parse error in \"%s\": " % f)
			for line in parse_errors:
				printerr("\t- Line %d: %s " % [line, parse_errors[line].trim_prefix("ERROR:")])
			return
		parse_results[f] = result

	# Merge
	var merge_errors: PackedStringArray
	var merge_result := _merge_parse_results(parse_results, merge_errors)
	if not merge_errors.is_empty():
		printerr("[DTag] Generate failed, merge errors: ")
		for msg in merge_errors:
			printerr("\t- ", msg)
		return

	# Redirect (auto-redirect sub tags for domain redirect)
	for def in merge_result.values():
		if def is DomainDef:
			_redirect_domain_recursively(def)

	# Collect redirect map from parsed definitions
	var redirect_map: Dictionary[String, String]
	for tag_text in merge_result:
		var def := merge_result[tag_text]
		var redirect := def.redirect
		if not redirect.is_empty():
			redirect_map[tag_text] = redirect
		# Collect redirects from nested entries inside domains
		if def is DomainDef:
			_collect_redirect_recursively(def, "", redirect_map)

	# Check cycle redirect and finalize redirect.
	for k in redirect_map:
		var redirected := redirect_map[k]
		while redirect_map.has(redirected):
			var next := redirect_map[redirected]
			if next == k:
				printerr("[DTag] Cycle redirect: %s." % k)
				return
			redirected = next
		redirect_map[k] = redirected

	# Fix redirect in definitions
	for tag_text in merge_result:
		var def := merge_result[tag_text]
		if tag_text in redirect_map:
			def.redirect = redirect_map[tag_text]
		if def is DomainDef:
			_fix_redirect_recursively(def, redirect_map, "")

	# Gen data files
	_gen_data_files(merge_result, redirect_map)

	# Generate
	var generated: PackedStringArray
	for g in generators:
		generated.push_back(g.generate(merge_result, redirect_map))

	# Check redirect target.
	var entry_texts: PackedStringArray
	for tag_text in merge_result:
		_collect_all_entry_texts_recursively(merge_result[tag_text], tag_text, entry_texts)
	for tag_text in redirect_map:
		var target := redirect_map[tag_text]
		if not entry_texts.has(target):
			print_rich("[color=yellow][DTag] Redirect target \"%s\" is not exists.[/color]" % target)

	# Refresh
	for f in generated:
		if f.is_empty():
			continue
		EditorInterface.get_resource_filesystem().update_file(f)

	# Reload redirect map in runtime
	DTag.reload_redirect_map()

	print("[DTag] Generate completed.")

#region Internal
static func _collect_redirect_recursively(def: DomainDef, prev_tag: String, r_redirect_map: Dictionary[String, String]) -> void:
	var domain_text := def.name if prev_tag.is_empty() else ("%s.%s" % [prev_tag, def.name])

	# Check domain redirect
	if not def.redirect.is_empty():
		r_redirect_map[domain_text] = def.redirect

	# Check tag redirects
	for tag_name in def.tag_list:
		var tag_text := "%s.%s" % [domain_text, tag_name]
		var tag_def := def.tag_list[tag_name]
		if not tag_def.redirect.is_empty():
			r_redirect_map[tag_text] = tag_def.redirect

	# Recurse into sub-domains
	for sub_def in def.sub_domain_list.values():
		_collect_redirect_recursively(sub_def, domain_text, r_redirect_map)


static func _fix_redirect_recursively(def: DomainDef, redirect_map: Dictionary[String, String], prev_tag := "") -> void:
	var domain_text := def.name if prev_tag.is_empty() else ("%s.%s" % [prev_tag, def.name])

	if redirect_map.has(domain_text):
		def.redirect = redirect_map[domain_text]

	for tag_name in def.tag_list:
		var tag_text := "%s.%s" % [domain_text, tag_name]
		var tag_def := def.tag_list[tag_name]
		if redirect_map.has(tag_text):
			tag_def.redirect = redirect_map[tag_text]

	for domain_def in def.sub_domain_list.values():
		_fix_redirect_recursively(domain_def, redirect_map, domain_text)


static func _redirect_domain_recursively(def: DomainDef) -> void:
	if not def.redirect.is_empty():
		for tag: TagDef in def.tag_list.values():
			if tag.redirect.is_empty():
				tag.redirect = def.redirect + "." + tag.name

	for domain: DomainDef in def.sub_domain_list.values():
		# 不自动对未重定向的子 domain 进行重定向
		_redirect_domain_recursively(domain)


static func _merge_parse_results(parse_results: Dictionary[String, Dictionary], r_errors: PackedStringArray) -> Dictionary[String, EntryDef]:
	var ret: Dictionary[String, EntryDef]
	var defined_main_identifier: Dictionary[String, String]
	var tag_to_file: Dictionary[String, String]
	for file: String in parse_results:
		var result := parse_results[file] as Dictionary[String, EntryDef]
		for n in result:
			var def := result[n] as EntryDef
			if def is TagDef:
				if ret.has(n):
					r_errors.push_back("Tag \"%s\" in \"%s\" is redefined in \"%s\"." % [
						n, file, tag_to_file[n]
					])
				else:
					ret[n] = def
					tag_to_file[n] = file
			elif def is DomainDef:
				__merge_recursively(file, [], def, ret, r_errors, tag_to_file)
	return ret


#region Merge
static func __get_domain_def(route: Array[String], result: Dictionary[String, EntryDef]) -> DomainDef:
	var ret :DomainDef
	for i in range(route.size()):
		var n := route[i]
		if i == 0:
			ret = result.get(n, null)
		else:
			ret = ret.sub_domain_list.get(n, null)
		if not is_instance_valid(ret):
			return null
	return ret


static func __merge_recursively(file:String, cur_route: Array[String], domain: DomainDef, r_result: Dictionary[String, EntryDef], 
	r_errors: PackedStringArray,
	r_tag_to_file: Dictionary[String, String] = {},
) -> void:
	var next_route := cur_route.duplicate()
	next_route.push_back(domain.name)

	var exists_domain := __get_domain_def(next_route, r_result)
	if is_instance_valid(exists_domain):
		# Tag
		for t in domain.tag_list:
			var tag_text := ".".join(next_route) + "." + t
			if exists_domain.tag_list.has(t):
				r_errors.push_back("Tag \"%s\" in \"%s\" is redefined in \"%s\"." % [
					tag_text, file, r_tag_to_file[tag_text]
				])
			else:
				exists_domain.tag_list[t] = domain.tag_list[t]
				r_tag_to_file[tag_text] = file
		# Sub Domain
		for d in domain.sub_domain_list:
			__merge_recursively(file, next_route, domain.sub_domain_list[d], r_result, r_errors, r_tag_to_file)
		# Info
		if exists_domain.redirect.is_empty():
			exists_domain.redirect = domain.redirect
		if exists_domain.desc.is_empty():
			exists_domain.desc = domain.desc
	else:
		if cur_route.is_empty():
			r_result[domain.name] = domain
			__add_tag_source_file_recursively(file, cur_route, domain, r_tag_to_file)
		else:
			var prev_domain := __get_domain_def(cur_route, r_result)
			assert(is_instance_valid(prev_domain))
			prev_domain.sub_domain_list[domain.name] = domain
			__add_tag_source_file_recursively(file, cur_route, domain, r_tag_to_file)


static func __add_tag_source_file_recursively(file: String, prev_route: Array[String], domain: DomainDef, r_tag_to_file: Dictionary[String, String]) -> void:
	var domain_text := ".".join(prev_route) + "." + domain.name
	for t in domain.tag_list:
		var tag_text := "%s.%s" % [domain_text, t]
		r_tag_to_file[tag_text] = file

	var cur_route := prev_route.duplicate()
	cur_route.push_back(domain.name)
	for d in domain.sub_domain_list:
		__add_tag_source_file_recursively(file, cur_route, domain.sub_domain_list[d], r_tag_to_file)

#endregion Merge


static func _gen_data_files(merge_result: Dictionary[String, EntryDef], redirect_map: Dictionary[String, String]) -> void:
	# Build tree data
	var data_dict: Dictionary
	for def in merge_result.values():
		if def is DomainDef:
			data_dict[def.name] = _build_tree_dict(def)
		elif def is TagDef:
			data_dict[def.name] = { "type": "tag" }

	# Write data file (tree structure)
	var data_dir := _DTagPaths.DTAG_DATA_DIR
	DirAccess.make_dir_recursive_absolute(data_dir)
	_write_json(_DTagPaths.DTAG_DATA_FILE, data_dict)

	# Write redirect file
	_write_json(_DTagPaths.DTAG_REDIRECT_FILE, redirect_map)

	# Build metadata (desc only)
	var metadata_dict: Dictionary
	for tag_text in merge_result:
		var def := merge_result[tag_text]
		_collect_metadata_recursively(tag_text, def, metadata_dict)
	_write_json(_DTagPaths.DTAG_META_FILE, metadata_dict)


static func _build_tree_dict(def: EntryDef) -> Dictionary:
	var node := { "type": "tag" if def is TagDef else "domain" }
	if def is DomainDef:
		var has_children := false
		var children: Dictionary

		# Add tag entries
		if not def.tag_list.is_empty():
			has_children = true
			for tag_name in def.tag_list:
				children[tag_name] = { "type": "tag" }

		# Add sub-domain entries
		if not def.sub_domain_list.is_empty():
			has_children = true
			for name in def.sub_domain_list:
				children[name] = _build_tree_dict(def.sub_domain_list[name])

		if has_children:
			node["children"] = children
	return node


static func _write_json(path: String, data: Variant) -> void:
	var json_str := JSON.stringify(data, "\t")
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if not is_instance_valid(fa):
		printerr("[DTag] Failed to write \"%s\": %s" % [path, error_string(FileAccess.get_open_error())])
		return
	fa.store_string(json_str)
	fa.close()


static func _collect_all_entry_texts_recursively(def: EntryDef, prev_tag: String, r_texts: PackedStringArray) -> void:
	r_texts.push_back(prev_tag)
	if def is DomainDef:
		var domain := def as DomainDef
		for tag_name in domain.tag_list:
			r_texts.push_back("%s.%s" % [prev_tag, tag_name])
		for sub_name in domain.sub_domain_list:
			var sub_text := "%s.%s" % [prev_tag, sub_name]
			_collect_all_entry_texts_recursively(domain.sub_domain_list[sub_name], sub_text, r_texts)


static func _collect_metadata_recursively(tag_text: String, def: EntryDef, r_metadata: Dictionary) -> void:
	var desc := def.desc
	if not desc.is_empty():
		r_metadata[tag_text] = { "desc": desc }
	if def is DomainDef:
		var domain := def as DomainDef
		for tag_name in domain.tag_list:
			var tag_text_full := "%s.%s" % [tag_text, tag_name]
			var tag_def := domain.tag_list[tag_name]
			var tag_desc := tag_def.desc
			if not tag_desc.is_empty():
				r_metadata[tag_text_full] = { "desc": tag_desc }
		for sub_name in domain.sub_domain_list:
			var sub_def := domain.sub_domain_list[sub_name]
			var sub_text := "%s.%s" % [tag_text, sub_name]
			_collect_metadata_recursively(sub_text, sub_def, r_metadata)
#endregion Internal
