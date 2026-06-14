@tool
extends EditorExportPlugin

const _DTagPaths := preload("../script/dtag_paths.gd")


func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
	# Export redirect map for runtime DTag.redirect()
	_add_data_file(_DTagPaths.DTAG_REDIRECT_FILE)
	# Export data tree for runtime usage
	_add_data_file(_DTagPaths.DTAG_DATA_FILE)


func _add_data_file(src_path: String) -> void:
	if not FileAccess.file_exists(src_path):
		return
	var bytes := FileAccess.get_file_as_bytes(src_path)
	if FileAccess.get_open_error() != OK:
		return
	add_file(src_path, bytes, false)
