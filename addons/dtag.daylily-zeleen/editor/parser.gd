class TagDef:
	var name : String
	var desc: String
	var redirect: String

class DomainDef:
	var name: String
	var desc: String
	var redirect: String
	var parent_domain: DomainDef
	var sub_domain_list: Dictionary[String, DomainDef]
	var tag_list: Dictionary[String, TagDef]


static func parse(text: String, r_err_info: Dictionary[int, String] = {}) -> Dictionary[String, RefCounted]:
	var ret :Dictionary[String, RefCounted]
	var curr_indent := 0
	var curr_domain :DomainDef

	var lines := Array(text.split("\n", true))

	for i in range(lines.size()):
		var line := lines[i] as String
		
		var stripped := line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		
		var indent_count := _get_indent_count(line)

		var result := _parse_line(line)
		assert(result.size() == 3)
		var identifiler := result[0] as String
		var redirect := result[1] as String
		var comment := result[2] as String

		if identifiler.begins_with("@"):
			var domain := DomainDef.new()
			domain.name = identifiler.trim_prefix("@").strip_edges()
			domain.redirect = redirect
			domain.desc = comment
			if indent_count == curr_indent:
				if indent_count == 0:
					if ret.has(domain.name):
						if not i in r_err_info:
							r_err_info[i] = "ERROR: duplicate identifier \"%s\"." % domain.name
					else:
						ret[domain.name] = domain
				else:
					if not is_instance_valid(curr_domain):
						r_err_info[i] = "ERROR: need a parent domain."
					else:
						domain.parent_domain = curr_domain.parent_domain

						if curr_domain.parent_domain.sub_domain_list.has(domain.name):
							if not i in r_err_info:
								r_err_info[i] = "ERROR: duplicate identifier \"%s\"." % domain.name
						else:
							curr_domain.parent_domain.sub_domain_list[domain.name] = domain
							domain.parent_domain = curr_domain.parent_domain
			elif indent_count == curr_indent + 1:
				if not is_instance_valid(curr_domain):
					r_err_info[i] = "ERROR: need a parent domain."
				elif curr_domain.sub_domain_list.has(domain.name):
					if not i in r_err_info:
						r_err_info[i] = "ERROR: duplicate identifier \"%s\"." % domain.name
				else:
					curr_domain.sub_domain_list[domain.name] = domain
					domain.parent_domain = curr_domain
			elif indent_count < curr_indent:
				if not is_instance_valid(curr_domain):
					r_err_info[i] = "ERROR: need a parent domain."
				else:
					var parent := curr_domain.parent_domain
					var dedent_count := curr_indent - indent_count -1
					while dedent_count > 0:
						dedent_count -= 1
						parent = parent.parent_domain
					assert(parent or indent_count == 0, "indent: %s" %indent_count)
					domain.parent_domain = parent
					if not domain.parent_domain:
						ret[domain.name] = domain

			curr_indent = indent_count
			curr_domain = domain
		else:
			var tag := TagDef.new()
			tag.name = identifiler
			tag.redirect = redirect
			tag.desc = comment
			if indent_count == 0:
				if ret.has(tag.name):
					if not i in r_err_info:
						r_err_info[i] = "ERROR: duplicate identifier \"%s\"." % tag.name
				else:
					ret[tag.name] = tag
			else:
				if not is_instance_valid(curr_domain):
					r_err_info[i] = "ERROR: need a parent domain."
				else:
					var domain_indent := curr_indent
					var domain := curr_domain
					while domain_indent + 1 > indent_count and is_instance_valid(domain):
						domain_indent -= 1
						domain = curr_domain.parent_domain

					if indent_count - 1 != domain_indent or not is_instance_valid(domain):
						if not i in r_err_info:
							r_err_info[i] = "ERROR: error indent level.11"
					else:
						if curr_domain.tag_list.has(tag.name):
							r_err_info[i] = "ERROR: duplicate identifier \"%s\"." % tag.name
						else:
							domain.tag_list[tag.name] = tag

	return ret

# [identifier, redirect, comment]
static func _parse_line(line: String) -> Array:
	line = line.strip_edges()

	var comment := ""
	var comment_idx := line.find("#")
	if comment_idx >= 0 and line.length() >= comment_idx + 2 and line[comment_idx + 1] == "#":
		comment = line.substr(comment_idx + 2).trim_prefix(" ")
		line = line.substr(0, comment_idx)

	var redirect := ""
	var redirect_idx := line.find("->")
	if redirect_idx < comment_idx and redirect_idx >= 0:
		redirect = line.substr(redirect_idx + 2).strip_edges()
		line = line.substr(0, redirect_idx)

	var identifier := line.strip_edges()

	assert(not identifier.is_empty())
	return [identifier, redirect, comment]


static func _get_indent_count(text: String) -> int:
	var ret := 0
	while text.begins_with("\t"):
		ret += 1
		text = text.substr(1)
	return ret


static func parse_format_errors(text: String, limit := -1) -> Dictionary[int, String]:
	var lines := text.split("\n")
	var err_lines :Dictionary[int, String]

	for line in range(lines.size()):
		if limit > 0 and err_lines.size() >= limit:
			return err_lines

		var line_text := lines[line]

		if line_text.strip_edges().is_empty():
			continue

		if line_text.strip_edges().begins_with("#"):
			continue

		var indent_count := _get_indent_count(line_text)
		if line_text.begins_with(" "):
			err_lines[line] = "ERROR: Can't begins with space."
			continue

		var splits := line_text.strip_edges().split("#", false, 1)
		if splits.is_empty():
			continue

		line_text = splits[0]

		splits = line_text.split("->", false, 1)
		var identifier := splits[0]
		var redirect := splits[1] if splits.size() == 2 else ""

		var empty_line_check_ref := [0, false]
		if indent_count > 0:
			if identifier.begins_with("@"):
				var func_check_indent := func(idx: int) -> bool:
					var prev := lines[idx]
					var stripped := prev.strip_edges()
					if stripped.is_empty():
						if not empty_line_check_ref[1]:
							empty_line_check_ref[0] += 1
						return false

					if stripped.begins_with("#"):
						return false

					empty_line_check_ref[1] = true
					var prev_indent_count := _get_indent_count(prev)

					if stripped.begins_with("@"):
						if indent_count - prev_indent_count in [0, 1]:
							return true
					else:
						if prev_indent_count == 0:
							err_lines[line] = "ERROR: this domain should be owned to an parent domain."
							return false
					return false

				var valid := false
				for idx in range(line - 1, -1, -1):
					if func_check_indent.call(idx):
						valid = true
						break
					if err_lines.has(line):
						break

				if not valid and not err_lines.has(line):
					err_lines[line] = "ERROR: error indent level."
			else:
				var has_domain_ref := [false]
				var func_check_indent := func(idx: int, p_has_domain_ref: Array) -> bool:
					var prev := lines[idx]
					var stripped := prev.strip_edges()
					if stripped.is_empty():
						if not empty_line_check_ref[1]:
							empty_line_check_ref[0] += 1
						return false

					if stripped.begins_with("#"):
						return false

					empty_line_check_ref[1] = true
					var prev_indent_count := _get_indent_count(prev)
					if stripped.begins_with("@"):
						if indent_count - prev_indent_count == 1:
							has_domain_ref[0] = true
							return true
					else:
						if indent_count == prev_indent_count:
							has_domain_ref[0] = true
							return true

						if prev_indent_count == 0:
							err_lines[line] = "ERROR: this tag should be owned to a domain.11"
							return false
					return false

				var valid := false
				for idx in range(line - 1, -1, -1):
					if func_check_indent.call(idx, has_domain_ref):
						valid = true
						break
					if err_lines.has(line):
						break

				var has_domain := has_domain_ref[0] as bool
				if not err_lines.has(line) and not has_domain:
					err_lines[line] = "ERROR: this tag should be owned to a domain."

		if err_lines.has(line):
			continue

		if identifier.begins_with("@"):
			identifier = identifier.substr(1)
		if not identifier.strip_edges().is_valid_identifier():
			err_lines[line] = "ERROR: \"%s\" is not a valid identifier." % identifier
			continue

		if not redirect.is_empty():
			for id in redirect.strip_edges().split("."):
				if not id.is_valid_identifier():
					err_lines[line] = "ERROR: \"%s\" is not a valid identifier." % id
					break

		if not err_lines.has(line) and indent_count > 0 and empty_line_check_ref[0] > 2:
			err_lines[line] = "WARN: this sub level line is far from previous level (more than 2 empty line)."

	return err_lines
