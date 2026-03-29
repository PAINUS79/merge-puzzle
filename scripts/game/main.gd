extends Node2D

enum GameState { MENU, PLAYING, DIALOG, MAP, ZONE_COMPLETE }

var current_state: int = GameState.MENU
var current_zone: int = 1
var story_flags: Dictionary = {}
var tutorial: Node = null

@onready var game_board: Node2D = $GameBoard
@onready var ui_layer: CanvasLayer = $UI
@onready var hud: Control = $UI/HUD
@onready var dialog_box: PanelContainer = $UI/DialogBox
@onready var farm_map: Control = $UI/FarmMap
@onready var pouch_container: HBoxContainer = $UI/PouchContainer
@onready var tutorial_label: Label = $UI/TutorialLabel
@onready var map_button: Button = $UI/MapButton
@onready var menu_screen: Control = $UI/MenuScreen
@onready var zone_complete_screen: Control = $UI/ZoneCompleteScreen

# Farm map sub-nodes
@onready var zone_before: TextureRect = $UI/FarmMap/ZoneBefore
@onready var zone_after: TextureRect = $UI/FarmMap/ZoneAfter
@onready var zone_label: Label = $UI/FarmMap/ZoneLabel
@onready var progress_label: Label = $UI/FarmMap/ProgressLabel
@onready var zone_button: Button = $UI/FarmMap/ZoneButton
@onready var back_button: Button = $UI/FarmMap/BackButton

var _pouches: Array = []

const ZONE_NAMES: Dictionary = {
	1: "The Overgrown Garden",
	2: "The Whispering Woods",
}

const ZONE_NAMES_RESTORED: Dictionary = {
	1: "The Garden (Restored!)",
	2: "The Whispering Woods (Restored!)",
}

const ZONE_BEFORE_TEXTURES: Dictionary = {
	1: "res://assets/farm/zone1_before.svg",
	2: "res://assets/farm/zone2_before.svg",
}

const ZONE_AFTER_TEXTURES: Dictionary = {
	1: "res://assets/farm/zone1_after.svg",
	2: "res://assets/farm/zone2_after.svg",
}

func _ready() -> void:
	tutorial = preload("res://scripts/game/tutorial_manager.gd").new()
	tutorial.name = "TutorialManager"
	add_child(tutorial)

	_connect_signals()
	_load_or_new_game()

func _setup_pouches_for_zone(zone: int) -> void:
	# Clear existing pouches
	for pouch in _pouches:
		pouch.queue_free()
	_pouches.clear()

	var pouch_scene := preload("res://scenes/game/seed_pouch.tscn")
	var chains: Array = ItemData.get_chains_for_zone(zone)
	for chain_type in chains:
		var pouch: Control = pouch_scene.instantiate()
		pouch.chain_type = chain_type
		pouch_container.add_child(pouch)
		pouch.pouch_tapped.connect(_on_pouch_tapped)
		_pouches.append(pouch)
		var btn: Button = pouch.get_node("VBox/TapButton")
		btn.text = ItemData.get_chain_name(chain_type)
		# Apply Zone 2 pouch config for new chains
		if ItemData.is_zone2_chain(chain_type):
			pouch.charges = ItemData.ZONE2_POUCH_MAX_CHARGES
			pouch._update_display()

func _connect_signals() -> void:
	game_board.merge_performed.connect(_on_merge_performed)
	game_board.item_sold.connect(_on_item_sold)
	game_board.board_full.connect(_on_board_full)
	dialog_box.dialog_finished.connect(_on_dialog_finished)
	zone_button.pressed.connect(_on_zone_selected)
	back_button.pressed.connect(_on_back_to_grid)
	TaskManager.task_completed.connect(_on_task_completed)
	TaskManager.zone_completed.connect(_on_zone_completed)
	tutorial.tutorial_step_changed.connect(_on_tutorial_step_changed)
	map_button.pressed.connect(_show_map)
	menu_screen.get_node("PlayButton").pressed.connect(_start_game)
	zone_complete_screen.get_node("ContinueButton").pressed.connect(_on_zone_complete_continue)

func _load_or_new_game() -> void:
	_set_state(GameState.MENU)
	if SaveManager.has_save():
		var data: Dictionary = SaveManager.load_game()
		if data.has("grid"):
			game_board.load_grid_data(data["grid"])
		if data.has("story_flags"):
			story_flags = data["story_flags"]
		if data.has("tutorial"):
			tutorial.load_data(data["tutorial"])
		current_zone = story_flags.get("current_zone", 1)
		TaskManager.current_zone = current_zone
		_setup_pouches_for_zone(current_zone)
		menu_screen.get_node("PlayButton").text = "Continue"
	else:
		current_zone = 1
		_setup_pouches_for_zone(current_zone)
		menu_screen.get_node("PlayButton").text = "New Game"

func _start_game() -> void:
	if not story_flags.get("arrival_shown", false):
		story_flags["arrival_shown"] = true
		_set_state(GameState.MAP)
		dialog_box.show_story_beat("arrival")
	else:
		_set_state(GameState.PLAYING)

func _set_state(new_state: int) -> void:
	current_state = new_state
	# Hide everything first
	game_board.visible = false
	hud.visible = false
	farm_map.visible = false
	pouch_container.visible = false
	map_button.visible = false
	menu_screen.visible = false
	zone_complete_screen.visible = false
	tutorial_label.visible = false

	match new_state:
		GameState.MENU:
			menu_screen.visible = true
		GameState.PLAYING:
			game_board.visible = true
			hud.visible = true
			pouch_container.visible = true
			map_button.visible = true
			if tutorial.is_active():
				tutorial_label.visible = true
		GameState.DIALOG:
			game_board.visible = true
			hud.visible = true
		GameState.MAP:
			farm_map.visible = true
			_update_farm_map_display()
		GameState.ZONE_COMPLETE:
			zone_complete_screen.visible = true

func _on_pouch_tapped(chain_type: int) -> void:
	if current_state != GameState.PLAYING:
		return
	var item := game_board.spawn_item(chain_type, 0)
	if item:
		SfxManager.play_tap()
		tutorial.on_pouch_tapped()
		_save_game()

func _on_merge_performed(chain_type: int, new_tier: int) -> void:
	tutorial.on_merge_performed()
	if not story_flags.get("first_merge_shown", false) and tutorial.current_step >= tutorial.Step.DRAG_TO_MERGE:
		story_flags["first_merge_shown"] = true
	_save_game()

func _on_item_sold(_chain_type: int, _tier: int, _value: int) -> void:
	_save_game()

func _on_board_full() -> void:
	SfxManager.play_error()

func _on_task_completed(task_index: int) -> void:
	SfxManager.play_task_complete()
	tutorial.on_task_completed(task_index)
	if current_zone == 1:
		if task_index == 0 and not story_flags.get("garden_restored_shown", false):
			story_flags["garden_restored_shown"] = true
			dialog_box.show_story_beat("garden_restored")
			_set_state(GameState.DIALOG)
	elif current_zone == 2:
		# Show midpoint dialog after task 3 (index 2) per design spec
		if task_index == 2 and not story_flags.get("zone2_midpoint_shown", false):
			story_flags["zone2_midpoint_shown"] = true
			dialog_box.show_story_beat("zone2_midpoint")
			_set_state(GameState.DIALOG)
	_save_game()

func _on_zone_completed() -> void:
	if current_zone == 1:
		if not story_flags.get("cliffhanger_shown", false):
			story_flags["cliffhanger_shown"] = true
			dialog_box.show_story_beat("cliffhanger")
			_set_state(GameState.DIALOG)
			story_flags["pending_zone_complete"] = true
		else:
			_set_state(GameState.ZONE_COMPLETE)
	elif current_zone == 2:
		if not story_flags.get("zone2_complete_shown", false):
			story_flags["zone2_complete_shown"] = true
			dialog_box.show_story_beat("zone2_complete")
			_set_state(GameState.DIALOG)
			story_flags["pending_zone_complete"] = true
		else:
			_set_state(GameState.ZONE_COMPLETE)
	_save_game()

func _on_dialog_finished() -> void:
	if story_flags.get("pending_zone_complete", false):
		story_flags["pending_zone_complete"] = false
		_set_state(GameState.ZONE_COMPLETE)
	elif story_flags.get("pending_zone2_start", false):
		story_flags["pending_zone2_start"] = false
		_set_state(GameState.PLAYING)
	elif not story_flags.get("first_merge_dialog_shown", false) and story_flags.get("arrival_shown", false):
		story_flags["first_merge_dialog_shown"] = true
		_set_state(GameState.PLAYING)
		tutorial.start_tutorial()
		tutorial.advance_to(tutorial.Step.TAP_POUCH)
		dialog_box.show_story_beat("first_merge")
	else:
		_set_state(GameState.PLAYING)

func _on_tutorial_step_changed(_step: int) -> void:
	if tutorial_label:
		tutorial_label.text = tutorial.get_hint_text()
		tutorial_label.visible = tutorial.get_hint_text() != ""

func _switch_to_zone(zone: int) -> void:
	current_zone = zone
	story_flags["current_zone"] = zone
	TaskManager.set_zone(zone)
	# Clear the board for the new zone
	game_board.load_grid_data([])
	_setup_pouches_for_zone(zone)
	_save_game()

func _update_farm_map_display() -> void:
	var is_restored: bool = TaskManager.zones_completed.get(current_zone, false)
	var before_path: String = ZONE_BEFORE_TEXTURES.get(current_zone, "")
	var after_path: String = ZONE_AFTER_TEXTURES.get(current_zone, "")

	if before_path != "":
		var before_tex = load(before_path)
		if before_tex:
			zone_before.texture = before_tex
	if after_path != "":
		var after_tex = load(after_path)
		if after_tex:
			zone_after.texture = after_tex

	zone_before.visible = not is_restored
	zone_after.visible = is_restored

	var zone_name: String
	if is_restored:
		zone_name = ZONE_NAMES_RESTORED.get(current_zone, "Zone " + str(current_zone))
	else:
		zone_name = ZONE_NAMES.get(current_zone, "Zone " + str(current_zone))
	zone_label.text = "Zone " + str(current_zone) + ": " + zone_name

	var completed: int = TaskManager.get_completed_count()
	var total: int = TaskManager.get_total_tasks()
	progress_label.text = str(completed) + "/" + str(total) + " tasks complete"

	# Show zone navigation
	if TaskManager.is_zone_unlocked(2) and current_zone == 1 and is_restored:
		zone_button.text = "Go to Zone 2"
	elif current_zone == 2 and TaskManager.zones_completed.get(1, false):
		zone_button.text = "Back to Zone 1"
	else:
		zone_button.text = "Enter Zone"

func _show_map() -> void:
	_set_state(GameState.MAP)

func _on_zone_selected() -> void:
	if current_zone == 1 and TaskManager.zones_completed.get(1, false) and TaskManager.is_zone_unlocked(2):
		_switch_to_zone(2)
		if not story_flags.get("zone2_arrival_shown", false):
			story_flags["zone2_arrival_shown"] = true
			dialog_box.show_story_beat("zone2_arrival")
			story_flags["pending_zone2_start"] = true
		else:
			_set_state(GameState.PLAYING)
	elif current_zone == 2 and TaskManager.zones_completed.get(1, false):
		_switch_to_zone(1)
		_set_state(GameState.PLAYING)
	else:
		_set_state(GameState.PLAYING)

func _on_back_to_grid() -> void:
	_set_state(GameState.PLAYING)

func _on_zone_complete_continue() -> void:
	_set_state(GameState.MAP)

func _save_game() -> void:
	var tutorial_data: Dictionary = tutorial.save_data() if tutorial else {}
	story_flags["tutorial"] = tutorial_data
	story_flags["current_zone"] = current_zone
	SaveManager.save_game(game_board.get_grid_save_data(), story_flags)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_save_game()
