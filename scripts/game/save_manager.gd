extends Node

const SAVE_PATH: String = "user://save.json"

func save_game(grid_data: Array, story_flags: Dictionary) -> void:
	var data: Dictionary = {
		"version": 1,
		"energy": EnergyManager.save_data(),
		"economy": Economy.save_data(),
		"tasks": TaskManager.save_data(),
		"grid": grid_data,
		"story_flags": story_flags,
		"timestamp": Time.get_unix_time_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("SaveManager: Failed to parse save file (line %d): %s" % [json.get_error_line(), json.get_error_message()])
		return {}
	if json.data == null or not (json.data is Dictionary):
		push_warning("SaveManager: Save file does not contain a valid dictionary")
		return {}
	var data: Dictionary = json.data
	if data.has("energy"):
		EnergyManager.load_data(data["energy"])
	if data.has("economy"):
		Economy.load_data(data["economy"])
	if data.has("tasks"):
		TaskManager.load_data(data["tasks"])
	return data

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
