extends Node

signal tutorial_step_changed(step: int)
signal tutorial_completed()

enum Step {
	NOT_STARTED,
	ARRIVAL_DIALOG,
	TAP_POUCH,
	TAP_POUCH_AGAIN,
	DRAG_TO_MERGE,
	KEEP_MERGING,
	FREE_PLAY,
	COMPLETED,
}

var current_step: int = Step.NOT_STARTED
var _tutorial_active: bool = true
var _first_item_spawned: bool = false

func start_tutorial() -> void:
	current_step = Step.ARRIVAL_DIALOG
	tutorial_step_changed.emit(current_step)

func advance_to(step: int) -> void:
	current_step = step
	tutorial_step_changed.emit(current_step)
	if step == Step.COMPLETED:
		_tutorial_active = false
		tutorial_completed.emit()

func is_active() -> bool:
	return _tutorial_active and current_step != Step.COMPLETED

func get_hint_text() -> String:
	match current_step:
		Step.TAP_POUCH:
			return "Tap a Seed Pouch to spawn an item!"
		Step.TAP_POUCH_AGAIN:
			return "Tap it again to get another!"
		Step.DRAG_TO_MERGE:
			return "Now drag one item onto the matching one to merge!"
		Step.KEEP_MERGING:
			return "Keep merging to build a Garden Fence!"
		Step.FREE_PLAY:
			return ""
		_:
			return ""

func on_pouch_tapped() -> void:
	if current_step == Step.TAP_POUCH:
		_first_item_spawned = true
		advance_to(Step.TAP_POUCH_AGAIN)
	elif current_step == Step.TAP_POUCH_AGAIN:
		advance_to(Step.DRAG_TO_MERGE)

func on_merge_performed() -> void:
	if current_step == Step.DRAG_TO_MERGE:
		advance_to(Step.KEEP_MERGING)
	elif current_step == Step.KEEP_MERGING:
		advance_to(Step.FREE_PLAY)

func on_task_completed(task_index: int) -> void:
	if task_index >= 1 and current_step != Step.COMPLETED:
		advance_to(Step.COMPLETED)

func save_data() -> Dictionary:
	return {
		"current_step": current_step,
		"tutorial_active": _tutorial_active,
	}

func load_data(data: Dictionary) -> void:
	current_step = data.get("current_step", Step.NOT_STARTED)
	_tutorial_active = data.get("tutorial_active", true)
