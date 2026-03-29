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

# Zone selector card nodes
@onready var zone1_card: PanelContainer = $UI/FarmMap/Zone1Card
@onready var zone1_before: TextureRect = $UI/FarmMap/Zone1Card/VBox/Zone1Before
@onready var zone1_after: TextureRect = $UI/FarmMap/Zone1Card/VBox/Zone1After
@onready var zone1_label: Label = $UI/FarmMap/Zone1Card/VBox/Zone1Label
@onready var zone1_progress: Label = $UI/FarmMap/Zone1Card/VBox/Zone1Progress
@onready var zone1_button: Button = $UI/FarmMap/Zone1Card/VBox/Zone1Button
@onready var zone2_card: PanelContainer = $UI/FarmMap/Zone2Card
@onready var zone2_before: TextureRect = $UI/FarmMap/Zone2Card/VBox/Zone2Before
@onready var zone2_after: TextureRect = $UI/FarmMap/Zone2Card/VBox/Zone2After
@onready var zone2_label: Label = $UI/FarmMap/Zone2Card/VBox/Zone2Label
@onready var zone2_progress: Label = $UI/FarmMap/Zone2Card/VBox/Zone2Progress
@onready var zone2_button: Button = $UI/FarmMap/Zone2Card/VBox/Zone2Button
@onready var zone2_lock_overlay: ColorRect = $UI/FarmMap/Zone2Card/LockOverlay
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
	zone1_button.pressed.connect(_on_zone1_selected)
	zone2_button.pressed.connect(_on_zone2_selected)
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
	# --- Zone 1 card ---
	var z1_complete: bool = TaskManager.zones_completed.get(1, false)
	zone1_before.visible = not z1_complete
	zone1_after.visible = z1_complete

	if z1_complete:
		zone1_label.text = "Zone 1: " + ZONE_NAMES_RESTORED.get(1, "Zone 1")
	else:
		zone1_label.text = "Zone 1: " + ZONE_NAMES.get(1, "Zone 1")

	# Compute Zone 1 progress
	var z1_completed_count: int = 0
	var z1_total: int = TaskManager.ZONE_1_TASKS.size()
	if current_zone == 1:
		z1_completed_count = TaskManager.get_completed_count()
	elif z1_complete:
		z1_completed_count = z1_total
	zone1_progress.text = str(z1_completed_count) + "/" + str(z1_total) + " tasks complete"

	# Zone 1 button
	if current_zone == 1:
		zone1_button.text = "Current Zone"
		zone1_button.disabled = true
	else:
		zone1_button.text = "Go to Zone 1"
		zone1_button.disabled = false

	# Build card styles for current/normal/locked states
	var active_style: StyleBoxFlat = StyleBoxFlat.new()
	active_style.bg_color = Color(0.38, 0.58, 0.35, 0.85)
	active_style.border_width_left = 2
	active_style.border_width_top = 2
	active_style.border_width_right = 2
	active_style.border_width_bottom = 2
	active_style.border_color = Color(0.9, 0.85, 0.6, 0.8)
	active_style.corner_radius_top_left = 12
	active_style.corner_radius_top_right = 12
	active_style.corner_radius_bottom_left = 12
	active_style.corner_radius_bottom_right = 12
	active_style.content_margin_left = 8.0
	active_style.content_margin_top = 8.0
	active_style.content_margin_right = 8.0
	active_style.content_margin_bottom = 8.0

	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.32, 0.48, 0.3, 0.7)
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.content_margin_left = 8.0
	normal_style.content_margin_top = 8.0
	normal_style.content_margin_right = 8.0
	normal_style.content_margin_bottom = 8.0

	var locked_style: StyleBoxFlat = StyleBoxFlat.new()
	locked_style.bg_color = Color(0.28, 0.3, 0.28, 0.6)
	locked_style.corner_radius_top_left = 12
	locked_style.corner_radius_top_right = 12
	locked_style.corner_radius_bottom_left = 12
	locked_style.corner_radius_bottom_right = 12
	locked_style.content_margin_left = 8.0
	locked_style.content_margin_top = 8.0
	locked_style.content_margin_right = 8.0
	locked_style.content_margin_bottom = 8.0

	if current_zone == 1:
		zone1_card.add_theme_stylebox_override("panel", active_style)
	else:
		zone1_card.add_theme_stylebox_override("panel", normal_style)

	# --- Zone 2 card ---
	var z2_unlocked: bool = TaskManager.is_zone_unlocked(2)
	var z2_complete: bool = TaskManager.zones_completed.get(2, false)

	zone2_lock_overlay.visible = not z2_unlocked

	if z2_unlocked:
		zone2_before.visible = not z2_complete
		zone2_after.visible = z2_complete

		if z2_complete:
			zone2_label.text = "Zone 2: " + ZONE_NAMES_RESTORED.get(2, "Zone 2")
		else:
			zone2_label.text = "Zone 2: " + ZONE_NAMES.get(2, "Zone 2")

		# Compute Zone 2 progress
		var z2_completed_count: int = 0
		var z2_total: int = TaskManager.ZONE_2_TASKS.size()
		if current_zone == 2:
			z2_completed_count = TaskManager.get_completed_count()
		elif z2_complete:
			z2_completed_count = z2_total
		zone2_progress.text = str(z2_completed_count) + "/" + str(z2_total) + " tasks complete"

		if current_zone == 2:
			zone2_button.text = "Current Zone"
			zone2_button.disabled = true
			zone2_card.add_theme_stylebox_override("panel", active_style)
		else:
			zone2_button.text = "Go to Zone 2"
			zone2_button.disabled = false
			zone2_card.add_theme_stylebox_override("panel", normal_style)
	else:
		zone2_label.text = "Zone 2: ???"
		zone2_progress.text = "Complete Zone 1 to unlock"
		zone2_button.text = "Locked"
		zone2_button.disabled = true
		zone2_before.visible = true
		zone2_after.visible = false
		zone2_card.add_theme_stylebox_override("panel", locked_style)

func _show_map() -> void:
	_set_state(GameState.MAP)

func _on_zone1_selected() -> void:
	if current_zone != 1:
		_switch_to_zone(1)
	_set_state(GameState.PLAYING)

func _on_zone2_selected() -> void:
	if not TaskManager.is_zone_unlocked(2):
		return
	if current_zone != 2:
		_switch_to_zone(2)
		if not story_flags.get("zone2_arrival_shown", false):
			story_flags["zone2_arrival_shown"] = true
			dialog_box.show_story_beat("zone2_arrival")
			story_flags["pending_zone2_start"] = true
			return
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
