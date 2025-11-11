@tool
extends EditorSyntaxHighlighter

class Scope:
	var _action: Callable
	func _init(end_action: Callable) -> void:
		_action = end_action
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			_action.call()
class ColorRegion:
	var color: Color
	var start_key: String
	var end_key: String
	var line_only := false

@export var _color_regions: Dictionary[String, Color]: set = set_color_regions, get = get_color_regions
var color_regions: Array[ColorRegion]
var color_region_cache: Dictionary[int, int]

@export var keywords: Dictionary[String, Color]: set = set_keyword_colors, get = get_keyword_colors
@export var member_keywords: Dictionary[String, Color]: set = set_member_keyword_colors, get = get_member_keyword_colors

var font_color: Color
@export var member_color: Color: set = set_number_color, get = get_number_color
@export var function_color: Color: set = set_function_color, get = get_function_color
@export var symbol_color: Color: set = set_symbol_color, get = get_symbol_color
@export var number_color: Color: set = set_number_color, get = get_number_color

var uint_suffix_enabled := false


func is_symbol(p_char: String) -> bool:
	var utf32 := p_char.to_utf32_buffer()[0]
	var ret := p_char != '_' && \
		((utf32 >= '!'.to_utf32_buffer()[0] && utf32 <= '/'.to_utf32_buffer()[0])
		|| (utf32 >= ':'.to_utf32_buffer()[0] && utf32 <= '@'.to_utf32_buffer()[0])
		|| (utf32 >= '['.to_utf32_buffer()[0] && utf32 <= '`'.to_utf32_buffer()[0])
		|| (utf32 >= '{'.to_utf32_buffer()[0] && utf32 <= '~'.to_utf32_buffer()[0])
		|| utf32 == '\t'.to_utf32_buffer()[0] || utf32 == ' '.to_utf32_buffer()[0])
	return ret


func is_digit(p_char: String) -> bool:
	var utf32 := p_char.to_utf32_buffer()[0]
	var ret := utf32 >= '0'.to_utf32_buffer()[0] && utf32 <= '9'.to_utf32_buffer()[0]
	return ret


func is_hex_digit(p_char: String) -> bool:
	var utf32 := p_char.to_utf32_buffer()[0]
	var ret := (is_digit(p_char)
		|| (utf32 >= 'a'.to_utf32_buffer()[0] && utf32 <= 'f'.to_utf32_buffer()[0])
		|| (utf32 >= 'A'.to_utf32_buffer()[0] && utf32 <= 'F'.to_utf32_buffer()[0]))
	return ret


func is_ascii_alphabet_char(p_char: String) -> bool:
	var utf32 := p_char.to_utf32_buffer()[0]
	var ret := ((utf32 >= 'a'.to_utf32_buffer()[0] && utf32 <= 'z'.to_utf32_buffer()[0])
		|| (utf32 >= 'A'.to_utf32_buffer()[0] && utf32 <= 'Z'.to_utf32_buffer()[0]))
	return ret


func is_underscore(p_char: String) -> bool:
	return p_char == '_'


func _get_line_syntax_highlighting(p_line: int) -> Dictionary:
	var color_map := {}

	var prev_is_char := false
	var prev_is_number := false
	var in_keyword := false
	var in_word := false
	var in_function_name := false
	var in_member_variable := false
	var is_hex_notation := false
	var keyword_color: Color
	var color: Color

	color_region_cache[p_line] = -1
	var in_region := -1
	if p_line != 0:
		var prev_region_line := p_line - 1
		while prev_region_line > 0 && !color_region_cache.has(prev_region_line):
			prev_region_line -= 1
		for i in range(prev_region_line, p_line - 1):
			get_line_syntax_highlighting(i)
		if !color_region_cache.has(p_line - 1):
			get_line_syntax_highlighting(p_line - 1)
		in_region = color_region_cache[p_line - 1]

	var text_edit := get_text_edit()
	var str := text_edit.get_line_with_ime(p_line)
	var line_length := str.length()
	var prev_color: Color

	if in_region != -1 && str.length() == 0:
		color_region_cache[p_line] = in_region
	var j := 0
	while j < line_length:
		var highlighter_info := {}

		color = font_color
		var is_char := !is_symbol(str[j])
		var is_a_symbol := is_symbol(str[j])
		var is_number := is_digit(str[j])

		# color regions
		if is_a_symbol || in_region != -1:
			var from := j

			if in_region == -1:
				while from < line_length:
					if str[from] == '\\':
						from += 1
						from += 1
						continue
					break

			if from != line_length:
				# check if we are in entering a region
				if in_region == -1:
					var c := 0
					while c < color_regions.size():
						# check there is enough room
						var chars_left := line_length - from
						var start_key_length := color_regions[c].start_key.length()
						var end_key_length := color_regions[c].end_key.length()
						if chars_left < start_key_length:
							c += 1
							continue

						# search the line
						var matched := true
						var start_key := color_regions[c].start_key
						for k in range(start_key_length):
							if start_key[k] != str[from + k]:
								matched = false
								break
						if !matched:
							c += 1
							continue
						in_region = c
						from += start_key_length

						# check if it's the whole line
						if end_key_length == 0 || color_regions[c].line_only || from + end_key_length > line_length:
							if from + end_key_length > line_length && (color_regions[in_region].start_key == "\"" || color_regions[in_region].start_key == "\'"):
								# If it's key length and there is a '\', dont skip to highlight esc chars.
								if str.find('\\', from) >= 0:
									break
							prev_color = color_regions[in_region].color
							highlighter_info["color"] = color_regions[c].color
							color_map[j] = highlighter_info

							j = line_length
							if !color_regions[c].line_only:
								color_region_cache[p_line] = c

						break

					if j == line_length:
						j += 1
						continue

				# if we are in one find the end key
				if in_region != -1:
					var is_string := (color_regions[in_region].start_key == "\"" || color_regions[in_region].start_key == "\'")

					var region_color := color_regions[in_region].color
					prev_color = region_color
					highlighter_info["color"] = region_color
					color_map[j] = highlighter_info

					# search the line
					var region_end_index := -1
					var end_key_length := color_regions[in_region].end_key.length()
					var end_key := color_regions[in_region].end_key
					while from < line_length:
						if line_length - from < end_key_length:
							# Don't break if '\' to highlight esc chars.
							if !is_string || str.find('\\', from) < 0:
								break

						if !is_symbol(str[from]):
							from += 1
							continue

						if str[from] == '\\':
							if is_string:
								var escape_char_highlighter_info := {}
								escape_char_highlighter_info["color"] = symbol_color
								color_map[from] = escape_char_highlighter_info

							from += 1

							if is_string:
								var region_continue_highlighter_info := {}
								prev_color = region_color
								region_continue_highlighter_info["color"] = region_color
								color_map[from + 1] = region_continue_highlighter_info
							from += 1
							continue

						region_end_index = from
						for k in range(end_key_length):
							if end_key[k] != str[from + k]:
								region_end_index = -1
								break

						if region_end_index != -1:
							break
						from += 1

					j = from + (end_key_length - 1)
					if region_end_index == -1:
						color_region_cache[p_line] = in_region

					in_region = -1
					prev_is_char = false
					prev_is_number = false

					j += 1
					continue

		# Allow ABCDEF in hex notation.
		if is_hex_notation && (is_hex_digit(str[j]) || is_number):
			is_number = true
		else:
			is_hex_notation = false

		# Check for dot or underscore or 'x' for hex notation in floating point number or 'e' for scientific notation.
		if (str[j] == '.' || str[j] == 'x' || str[j] == 'X' || str[j] == '_' || str[j] == 'f' || str[j] == 'e' || str[j] == 'E' || (uint_suffix_enabled && str[j] == 'u')) && !in_word && prev_is_number && !is_number:
			is_number = true
			is_a_symbol = false
			is_char = false

			if (str[j] == 'x' || str[j] == 'X') && str[j - 1] == '0':
				is_hex_notation = true

		if !in_word && (is_ascii_alphabet_char(str[j]) || is_underscore(str[j])) && !is_number:
			in_word = true

		if (in_keyword || in_word) && !is_hex_notation:
			is_number = false

		if is_a_symbol && str[j] != '.' && in_word:
			in_word = false

		if !is_char:
			in_keyword = false

		if !in_keyword && is_char && !prev_is_char:
			var to := j
			while to < line_length && !is_symbol(str[to]):
				to += 1

			var word := str.substr(j, to - j)
			var col: Color
			if keywords.has(word):
				col = keywords[word]
			elif member_keywords.has(word):
				col = member_keywords[word]
				var _k := j - 1
				while _k >= 0:
					if str[_k] == '.':
						col = Color() # member indexing not allowed
						break
					elif str[_k].to_utf32_buffer()[0] > 32:
						break
					_k -= 1

			if col != Color():
				in_keyword = true
				keyword_color = col

		if !in_function_name && in_word && !in_keyword:
			var k := j
			while k < line_length && !is_symbol(str[k]) && str[k] != '\t' && str[k] != ' ':
				k += 1

			# Check for space between name and bracket.
			while k < line_length && (str[k] == '\t' || str[k] == ' '):
				k += 1

			if k < str.length() and str[k] == '(':
				in_function_name = true

		if !in_function_name && !in_member_variable && !in_keyword && !is_number && in_word:
			var k := j
			while k > 0 && !is_symbol(str[k]) && str[k] != '\t' && str[k] != ' ':
				k -= 1

			if str[k] == '.':
				in_member_variable = true

		if is_a_symbol:
			in_function_name = false
			in_member_variable = false

		if in_keyword:
			color = keyword_color
		elif in_member_variable:
			color = member_color
		elif in_function_name:
			color = function_color
		elif is_a_symbol:
			color = symbol_color
		elif is_number:
			color = number_color

		prev_is_char = is_char
		prev_is_number = is_number

		if color != prev_color:
			prev_color = color
			highlighter_info["color"] = color
			color_map[j] = highlighter_info

		j += 1
	return color_map


func _clear_highlighting_cache() -> void:
	color_region_cache.clear()

func _update_cache() -> void:
	font_color = get_text_edit().get_theme_color(&"font_color")

func add_keyword_color(p_keyword: String, p_color: Color) -> void:
	keywords[p_keyword] = p_color
	clear_highlighting_cache()

func remove_keyword_color(p_keyword: String) -> void:
	keywords.erase(p_keyword)
	clear_highlighting_cache()

func has_keyword_color(p_keyword: String) -> bool:
	return keywords.has(p_keyword)

func get_keyword_color(p_keyword: String) -> Color:
	assert(keywords.has(p_keyword))
	return keywords.get(p_keyword, Color())

func set_keyword_colors(p_keywords: Dictionary) -> void:
	keywords = p_keywords
	clear_highlighting_cache()

func clear_keyword_colors() -> void:
	keywords.clear()
	clear_highlighting_cache()

func get_keyword_colors() -> Dictionary:
	return keywords

func add_member_keyword_color(p_member_keyword: String, p_color: Color) -> void:
	member_keywords[p_member_keyword] = p_color
	clear_highlighting_cache()

func remove_member_keyword_color(p_member_keyword: String) -> void:
	member_keywords.erase(p_member_keyword)
	clear_highlighting_cache()

func has_member_keyword_color(p_member_keyword: String) -> bool:
	return member_keywords.has(p_member_keyword)

func get_member_keyword_color(p_member_keyword: String) -> Color:
	assert(member_keywords.has(p_member_keyword))
	return member_keywords.get(p_member_keyword, Color())

func set_member_keyword_colors(p_member_keywords: Dictionary) -> void:
	member_keywords = p_member_keywords
	clear_highlighting_cache()

func clear_member_keyword_colors() -> void:
	member_keywords.clear()
	clear_highlighting_cache()

func get_member_keyword_colors() -> Dictionary:
	return member_keywords

func add_color_region(p_start_key: String, p_end_key: String, p_color: Color, p_line_only: bool = false) -> void:
	for i in range(p_start_key.length()):
		assert(is_symbol(p_start_key[i]), "color regions must start with a symbol")

	if p_end_key.length() > 0:
		for i in range(p_end_key.length()):
			assert(is_symbol(p_end_key[i]), "color regions must end with a symbol")

	var at := 0
	for i in range(color_regions.size()):
		assert(color_regions[i].start_key != p_start_key, "color region with start key '" + p_start_key + "' already exists.")
		if p_start_key.length() < color_regions[i].start_key.length():
			at += 1

	var color_region := ColorRegion.new()
	color_region.color = p_color
	color_region.start_key = p_start_key
	color_region.end_key = p_end_key
	color_region.line_only = p_line_only || p_end_key.is_empty()
	color_regions.insert(at, color_region)
	clear_highlighting_cache()


func remove_color_region(p_start_key: String) -> void:
	for i in range(color_regions.size()):
		if color_regions[i].start_key == p_start_key:
			color_regions.remove_at(i)
			break
	clear_highlighting_cache()

func has_color_region(p_start_key: String) -> bool:
	for i in range(color_regions.size()):
		if color_regions[i].start_key == p_start_key:
			return true
	return false

func set_color_regions(p_color_regions: Dictionary[String, Color]) -> void:
	color_regions.clear()

	for key: String in p_color_regions:
		var start_key := key.get_slicec(' '.to_utf32_buffer()[0], 0)

		var end_key := key.get_slicec(' '.to_utf32_buffer()[0], 1) if (key.get_slice_count(" ") > 1) else ""
		add_color_region(start_key, end_key, p_color_regions[key], end_key.is_empty())

	clear_highlighting_cache()

func clear_color_regions() -> void:
	color_regions.clear()
	clear_highlighting_cache()

func get_color_regions() -> Dictionary[String, Color]:
	var r_color_regions: Dictionary[String, Color] = {}
	for i in range(color_regions.size()):
		var region := color_regions[i]
		r_color_regions[region.start_key + ("" if region.end_key.is_empty() else (" " + region.end_key))] = region.color

	return r_color_regions

func set_uint_suffix_enabled(p_enabled: bool) -> void:
	uint_suffix_enabled = p_enabled

func set_number_color(p_color: Color) -> void:
	number_color = p_color
	clear_highlighting_cache()

func get_number_color() -> Color:
	return number_color

func set_symbol_color(p_color: Color) -> void:
	symbol_color = p_color
	clear_highlighting_cache()

func get_symbol_color() -> Color:
	return symbol_color


func set_function_color(p_color: Color) -> void:
	function_color = p_color
	clear_highlighting_cache()

func get_function_color() -> Color:
	return function_color

func set_member_variable_color(p_color: Color) -> void:
	member_color = p_color
	clear_highlighting_cache()

func get_member_variable_color() -> Color:
	return member_color
