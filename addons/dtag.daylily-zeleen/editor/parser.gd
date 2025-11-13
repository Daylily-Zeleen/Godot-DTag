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
					assert(curr_domain)
					domain.parent_domain = curr_domain.parent_domain

					if curr_domain.parent_domain.sub_domain_list.has(domain.name):
						if not i in r_err_info:
							r_err_info[i] = "ERROR: duplicate identifier \"%s\"." % domain.name
					else:
						curr_domain.parent_domain.sub_domain_list[domain.name] = domain
			elif indent_count == curr_indent + 1:
				if curr_domain.sub_domain_list.has(domain.name):
					if not i in r_err_info:
						r_err_info[i] = "ERROR: duplicate identifier \"%s\"." % domain.name
				else:
					curr_domain.sub_domain_list[domain.name] = domain
					domain.parent_domain = curr_domain #INFO: This allows same-level sub-domains with child tags.
			elif indent_count < curr_indent:
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
				assert(curr_indent + 1 == indent_count)
				assert(curr_domain)
				if curr_domain.tag_list.has(tag.name):
					if not i in r_err_info:
						r_err_info[i] = "ERROR: duplicate identifier \"%s\"." % tag.name
				else:
					curr_domain.tag_list[tag.name] = tag

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

		if identifier.begins_with("@"):
			if indent_count > 0:
				for idx in range(line - 1, -1, -1):
					var prev := lines[idx]
					var stripped := prev.strip_edges()
					if stripped.is_empty():
						continue
					if stripped.begins_with("#"):
						continue
					var prev_indent_count := _get_indent_count(prev)

					
					#INFO: 	Removing this check, paired with other changes, allows multiple sub-domains each with sub-tags.
					#		I am concerned what bugs this check was meant to fix, but for now, removing it doesn't seem to cause problems.
					#if stripped.begins_with("@"):
						#if indent_count - prev_indent_count in [0, 1]:
							#break
						#else:
							#err_lines[line] = "ERROR: Error indent level."
							#break
					#else:
						#if indent_count == prev_indent_count:
							#break
						#else:
							#err_lines[line] = "ERROR: Error indent level."
							#break

			identifier = identifier.substr(1)
		elif indent_count > 0:
			var has_domain:=false
			for idx in range(line - 1, -1, -1):
				var prev := lines[idx]
				var stripped := prev.strip_edges()
				if stripped.is_empty():
					continue
				if stripped.begins_with("#"):
					continue
				var prev_indent_count := _get_indent_count(prev)
				if stripped.begins_with("@"):
					if indent_count - prev_indent_count == 1:
						has_domain = true
						break
					else:
						err_lines[line] = "ERROR: Error indent level."
						break
				else:
					if indent_count == prev_indent_count:
						has_domain = true
						break
					else:
						err_lines[line] = "ERROR: Error indent level."
						break

			if not err_lines.has(line) and not has_domain:
				err_lines[line] = "ERROR: tag should be owned to a domain."

		if err_lines.has(line):
			continue

		if not identifier.strip_edges().is_valid_identifier():
			err_lines[line] = "ERROR: \"%s\" is not a valid identifier." % identifier
			continue

		if not redirect.is_empty():
			for id in redirect.strip_edges().split("."):
				if not id.is_valid_identifier():
					err_lines[line] = "ERROR: \"%s\" is not a valid identifier." % id
					break

	return err_lines
