extends Node

signal task_updated(task_index: int)
signal task_completed(task_index: int)
signal zone_completed()
signal item_delivered(task_index: int, chain_type: int, tier: int)

const ZONE_1_TASKS: Array = [
	{
		"name": "Clear the weeds",
		"description": "Deliver 2x Garden Fence",
		"required_chain": 1,  # TOOLS
		"required_tier": 4,   # Garden Fence (0-indexed)
		"required_count": 2,
		"coin_reward": 100,
		"gem_reward": 5,
	},
	{
		"name": "Plant the first crop",
		"description": "Deliver 2x Golden Harvest",
		"required_chain": 0,  # CROPS
		"required_tier": 4,   # Golden Harvest
		"required_count": 2,
		"coin_reward": 150,
		"gem_reward": 8,
	},
	{
		"name": "Welcome a friend",
		"description": "Deliver 1x Phoenix Chicken",
		"required_chain": 2,  # CREATURES
		"required_tier": 4,   # Phoenix Chicken
		"required_count": 1,
		"coin_reward": 200,
		"gem_reward": 10,
	},
]

var task_progress: Array = []  # Array of ints: delivered count per task
var tasks_completed: Array = []  # Array of bools
var current_task_index: int = 0
var zone_complete: bool = false

func _ready() -> void:
	reset_tasks()

func reset_tasks() -> void:
	task_progress = []
	tasks_completed = []
	for i in range(ZONE_1_TASKS.size()):
		task_progress.append(0)
		tasks_completed.append(false)
	current_task_index = 0
	zone_complete = false

func get_current_task() -> Dictionary:
	if current_task_index < ZONE_1_TASKS.size():
		return ZONE_1_TASKS[current_task_index]
	return {}

func get_task_progress(index: int) -> int:
	if index < task_progress.size():
		return task_progress[index]
	return 0

func is_task_completed(index: int) -> bool:
	if index < tasks_completed.size():
		return tasks_completed[index]
	return false

func try_deliver_item(chain_type: int, tier: int) -> bool:
	if zone_complete:
		return false
	var task: Dictionary = ZONE_1_TASKS[current_task_index]
	if chain_type == task["required_chain"] and tier == task["required_tier"]:
		task_progress[current_task_index] += 1
		item_delivered.emit(current_task_index, chain_type, tier)
		task_updated.emit(current_task_index)
		if task_progress[current_task_index] >= task["required_count"]:
			_complete_task(current_task_index)
		return true
	return false

func _complete_task(index: int) -> void:
	tasks_completed[index] = true
	var task: Dictionary = ZONE_1_TASKS[index]
	Economy.add_coins(task["coin_reward"])
	Economy.add_gems(task["gem_reward"])
	task_completed.emit(index)
	# Advance to next task
	current_task_index += 1
	if current_task_index >= ZONE_1_TASKS.size():
		zone_complete = true
		zone_completed.emit()

func get_total_tasks() -> int:
	return ZONE_1_TASKS.size()

func get_completed_count() -> int:
	var count: int = 0
	for completed in tasks_completed:
		if completed:
			count += 1
	return count

func save_data() -> Dictionary:
	return {
		"task_progress": task_progress.duplicate(),
		"tasks_completed": tasks_completed.duplicate(),
		"current_task_index": current_task_index,
		"zone_complete": zone_complete,
	}

func load_data(data: Dictionary) -> void:
	task_progress = data.get("task_progress", [0, 0, 0])
	tasks_completed = data.get("tasks_completed", [false, false, false])
	current_task_index = data.get("current_task_index", 0)
	zone_complete = data.get("zone_complete", false)
