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

const ZONE_2_TASKS: Array = [
	{
		"name": "Plant the orchard",
		"description": "Deliver 2x Golden Apple Tree",
		"required_chain": 3,  # ORCHARD
		"required_tier": 4,   # Golden Apple Tree
		"required_count": 2,
		"coin_reward": 250,
		"gem_reward": 12,
	},
	{
		"name": "Sweeten the grove",
		"description": "Deliver 2x Ambrosia Jar",
		"required_chain": 4,  # HONEY
		"required_tier": 4,   # Ambrosia Jar
		"required_count": 2,
		"coin_reward": 300,
		"gem_reward": 15,
	},
	{
		"name": "Hatch the guardian",
		"description": "Deliver 2x Phoenix Chicken",
		"required_chain": 2,  # CREATURES
		"required_tier": 4,   # Phoenix Chicken
		"required_count": 2,
		"coin_reward": 400,
		"gem_reward": 20,
	},
]

const ALL_ZONE_TASKS: Dictionary = {
	1: ZONE_1_TASKS,
	2: ZONE_2_TASKS,
}

var current_zone: int = 1
var task_progress: Array = []  # Array of ints: delivered count per task
var tasks_completed: Array = []  # Array of bools
var current_task_index: int = 0
var zone_complete: bool = false
var zones_completed: Dictionary = {}  # { zone_number: true }

func _ready() -> void:
	reset_tasks()

func reset_tasks() -> void:
	var tasks: Array = _get_zone_tasks()
	task_progress = []
	tasks_completed = []
	for i in range(tasks.size()):
		task_progress.append(0)
		tasks_completed.append(false)
	current_task_index = 0
	zone_complete = false

func set_zone(zone: int) -> void:
	current_zone = zone
	zone_complete = zones_completed.get(zone, false)
	if not zone_complete:
		reset_tasks()

func _get_zone_tasks() -> Array:
	return ALL_ZONE_TASKS.get(current_zone, ZONE_1_TASKS)

func get_current_task() -> Dictionary:
	var tasks: Array = _get_zone_tasks()
	if current_task_index < tasks.size():
		return tasks[current_task_index]
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
	var tasks: Array = _get_zone_tasks()
	var task: Dictionary = tasks[current_task_index]
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
	var tasks: Array = _get_zone_tasks()
	var task: Dictionary = tasks[index]
	Economy.add_coins(task["coin_reward"])
	Economy.add_gems(task["gem_reward"])
	task_completed.emit(index)
	# Advance to next task
	current_task_index += 1
	if current_task_index >= tasks.size():
		zone_complete = true
		zones_completed[current_zone] = true
		zone_completed.emit()

func get_total_tasks() -> int:
	return _get_zone_tasks().size()

func get_completed_count() -> int:
	var count: int = 0
	for completed in tasks_completed:
		if completed:
			count += 1
	return count

func is_zone_unlocked(zone: int) -> bool:
	if zone <= 1:
		return true
	# Zone N requires Zone N-1 to be completed
	return zones_completed.get(zone - 1, false)

func get_highest_unlocked_zone() -> int:
	var highest: int = 1
	for zone in ALL_ZONE_TASKS.keys():
		if is_zone_unlocked(zone):
			highest = maxi(highest, zone)
	return highest

func save_data() -> Dictionary:
	return {
		"current_zone": current_zone,
		"task_progress": task_progress.duplicate(),
		"tasks_completed": tasks_completed.duplicate(),
		"current_task_index": current_task_index,
		"zone_complete": zone_complete,
		"zones_completed": zones_completed.duplicate(),
	}

func load_data(data: Dictionary) -> void:
	current_zone = data.get("current_zone", 1)
	task_progress = data.get("task_progress", [0, 0, 0])
	tasks_completed = data.get("tasks_completed", [false, false, false])
	current_task_index = data.get("current_task_index", 0)
	zone_complete = data.get("zone_complete", false)
	zones_completed = data.get("zones_completed", {})
