@tool
extends EditorScript

const Parser := preload("../editor/parser.gd")
const DomainDef := Parser.DomainDef
const TagDef := Parser.TagDef

const CACHE_FILE := "res://.godot/editor/dtag_cache.cfg"

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


static func generate(files: PackedStringArray, generaters: Array[Object]) -> void:
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

	# Redirect
	for def in merge_result.values():
		if def is DomainDef:
			_redirect_domain_recursively(def)

	# Gen cache
	var cache_info := _gen_cache(merge_result)

	# Redirect map
	var redirect_map: Dictionary[String, String]
	for tag_text in cache_info:
		var data := cache_info[tag_text]
		var redirect := data.get("redirect", "") as String
		if not redirect.is_empty():
			redirect_map[tag_text] = redirect

	# Check Cycle redirect and finalize redirect.
	for k in redirect_map:
		var redirected := redirect_map[k]
		while redirect_map.has(redirected):
			var next := redirect_map[redirected]
			if next == k:
				printerr("[DTag] Cycle redirect: %s." % k)
				return
			redirected = next
		redirect_map[k] = redirected

	# Fix redirect.
	for tag_text in merge_result:
		var def := merge_result[tag_text]
		if tag_text in redirect_map:
			var redirect := redirect_map[tag_text]
			def.redirect = redirect
		if def is DomainDef:
			_fix_redirect_recursively(def, redirect_map, tag_text)

	# Generate
	var generated: PackedStringArray
	var default_gen := preload("../generater/gen_dtag_def_gdscript.gd").new()
	generated.push_back(default_gen.generate(merge_result, redirect_map))
	for g in generaters:
		generated.push_back(g.generate(merge_result, redirect_map))

	# Check redirect target.
	for tag_text in redirect_map:
		var target := redirect_map[tag_text]
		if not cache_info.has(target):
			print_rich("[color=yellow][DTag] Redirect taget \"%s\" is not exists.[/color]" % target)

	# Refrech
	for f in generated:
		if f.is_empty():
			continue
		EditorInterface.get_resource_filesystem().update_file(f)

	print("[DTag] Generate completed.")

#region Internal
static func _fix_redirect_recursively(def: DomainDef, redirect_map: Dictionary[String, String], prev_tag := "") -> void:
	var domain_text := "%s.%s" % [prev_tag, def.name]

	if redirect_map.has(domain_text):
		def.redirect = redirect_map[domain_text]

	for tag_name in def.tag_list:
		var tag_text := "%s.%s" % [domain_text, tag_name]
		var tag_def := def.tag_list[tag_name]
		if redirect_map.has(tag_name):
			tag_def.redirect = redirect_map[tag_name]

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


static func _merge_parse_results(parse_results: Dictionary[String, Dictionary], r_errors: PackedStringArray) -> Dictionary[String, RefCounted]:
	var ret: Dictionary[String, RefCounted]
	var defined_main_identifier: Dictionary[String, String]
	var tag_to_file: Dictionary[String, String]
	for file: String in parse_results:
		var result := parse_results[file] as Dictionary[String, RefCounted]
		for n in result:
			var def := result[n] as RefCounted
			if def is TagDef:
				if ret.has(n):
					r_errors.push_back("Tag \"%s\" in \"%s\" is redefined in \"%s\"." % [
						n, file, tag_to_file[n]
					])
				else:
					ret[n] = def
					tag_to_file[n] = file
			elif def is DomainDef:
				__merge_resursively(file, [], def, ret, r_errors, tag_to_file)
	return ret


#region Merge
static func __get_domain_def(route: Array[String], result: Dictionary[String, RefCounted]) -> DomainDef:
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


static func __merge_resursively(file:String, cur_route: Array[String], domain: DomainDef, r_result: Dictionary[String, RefCounted], 
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
			__merge_resursively(file, next_route, domain.sub_domain_list[d], r_result, r_errors, r_tag_to_file)
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


static func _gen_cache(parse_results: Dictionary[String, RefCounted]) -> Dictionary[String, Dictionary]:
	var cfg := ConfigFile.new()

	var cache_info: Dictionary[String, Dictionary]
	for def in parse_results.values():
		_get_cache_info_recursively(def, cache_info)

	for def_tag_text in cache_info:
		var values := cache_info[def_tag_text]
		for k in values:
			var v := values[k] as String
			cfg.set_value(def_tag_text, k, v)

	var err := cfg.save(CACHE_FILE)
	if err != OK:
		print_rich("[color=yellow][DTag] generate cache file \"%s\" failed: %s[/color]" % [CACHE_FILE, error_string(err)])

	return cache_info


static func _get_cache_info_recursively(def: RefCounted, r_info: Dictionary[String, Dictionary], prev_tag: String = "") -> void:
	var tag_text := def.name if prev_tag.is_empty() else ("%s.%s" % [prev_tag, def.name]) as String
	r_info[tag_text] = {
		desc = def.desc,
		redirect = def.redirect,
	}

	if def is DomainDef:
		for tag in def.tag_list.values():
			_get_cache_info_recursively(tag, r_info, tag_text)
		for domain in def.sub_domain_list.values():
			_get_cache_info_recursively(domain, r_info, tag_text)
#endregion Internal
