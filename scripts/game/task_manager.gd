extends Node

signal task_updated(task_index: int)
signal task_completed(task_index: int)
signal zone_completed()
signal item_delivered(task_index: int, chain_type: int, tier: int)

# Zone 1 tasks: single-requirement per task (backward compatible)
const ZONE_1_TASKS: Array = [
	{
		"name": "Clear the weeds",
		"description": "Deliver 2x Garden Fence",
		"requirements": [
			{ "chain": 1, "tier": 4, "count": 2 },  # TOOLS
		],
		"coin_reward": 100,
		"gem_reward": 5,
	},
	{
		"name": "Plant the first crop",
		"description": "Deliver 2x Golden Harvest",
		"requirements": [
			{ "chain": 0, "tier": 4, "count": 2 },  # CROPS
		],
		"coin_reward": 150,
		"gem_reward": 8,
	},
	{
		"name": "Welcome a friend",
		"description": "Deliver 1x Phoenix Chicken",
		"requirements": [
			{ "chain": 2, "tier": 4, "count": 1 },  # CREATURES
		],
		"coin_reward": 200,
		"gem_reward": 10,
	},
]

# Zone 2 tasks: multi-requirement per task (cross-chain deliveries)
const ZONE_2_TASKS: Array = [
	{
		"name": "Light the Path",
		"description": "Deliver 2x Glowcap",
		"requirements": [
			{ "chain": 3, "tier": 4, "count": 2 },  # MUSHROOMS max
		],
		"coin_reward": 120,
		"gem_reward": 6,
	},
	{
		"name": "Craft a Lantern",
		"description": "Deliver 1x Star Crystal + 1x Garden Fence",
		"requirements": [
			{ "chain": 4, "tier": 4, "count": 1 },  # CRYSTALS max
			{ "chain": 1, "tier": 4, "count": 1 },  # TOOLS max
		],
		"coin_reward": 160,
		"gem_reward": 8,
	},
	{
		"name": "Feed the Fox",
		"description": "Deliver 3x Shiitake Cluster + 1x Golden Harvest",
		"requirements": [
			{ "chain": 3, "tier": 3, "count": 3 },  # MUSHROOMS tier 4
			{ "chain": 0, "tier": 4, "count": 1 },  # CROPS max
		],
		"coin_reward": 180,
		"gem_reward": 10,
	},
	{
		"name": "Restore the Shrine",
		"description": "Deliver 2x Star Crystal + 2x Glowcap",
		"requirements": [
			{ "chain": 4, "tier": 4, "count": 2 },  # CRYSTALS max
			{ "chain": 3, "tier": 4, "count": 2 },  # MUSHROOMS max
		],
		"coin_reward": 220,
		"gem_reward": 12,
	},
	{
		"name": "Awaken the Grove",
		"description": "Deliver 1x Phoenix Chicken + 1x Star Crystal + 1x Glowcap",
		"requirements": [
			{ "chain": 2, "tier": 4, "count": 1 },  # CREATURES max
			{ "chain": 4, "tier": 4, "count": 1 },  # CRYSTALS max
			{ "chain": 3, "tier": 4, "count": 1 },  # MUSHROOMS max
		],
		"coin_reward": 300,
		"gem_reward": 15,
	},
]

const ALL_ZONE_TASKS: Dictionary = {
	1: ZONE_1_TASKS,
	2: ZONE_2_TASKS,
}

var current_zone: int = 1
# requirement_progress is a 2D structure: [task_index][req_index] = delivered count
var requirement_progress: Array = []
var tasks_completed: Array = []  # Array of bools
var current_task_index: int = 0
var zone_complete: bool = false
var zones_completed: Dictionary = {}  # { zone_number: true }

func _ready() -> void:
	reset_tasks()

func reset_tasks() -> void:
	var tasks: Array = _get_zone_tasks()
	requirement_progress = []
	tasks_completed = []
	for i in range(tasks.size()):
		var req_counts: Array = []
		for j in range(tasks[i]["requirements"].size()):
			req_counts.append(0)
		requirement_progress.append(req_counts)
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

func get_task_progress(task_index: int) -> int:
	# Returns total delivered items across all requirements for backward compat
	if task_index >= requirement_progress.size():
		return 0
	var total: int = 0
	for count in requirement_progress[task_index]:
		total += count
	return total

func get_requirement_progress(task_index: int, req_index: int) -> int:
	if task_index < requirement_progress.size() and req_index < requirement_progress[task_index].size():
		return requirement_progress[task_index][req_index]
	return 0

func is_task_completed(index: int) -> bool:
	if index < tasks_completed.size():
		return tasks_completed[index]
	return false

func try_deliver_item(chain_type: int, tier: int) -> bool:
	if zone_complete:
		return false
	var tasks: Array = _get_zone_tasks()
	if current_task_index >= tasks.size():
		return false
	var task: Dictionary = tasks[current_task_index]
	var requirements: Array = task["requirements"]

	# Find a matching requirement that isn't yet fulfilled
	for req_idx in range(requirements.size()):
		var req: Dictionary = requirements[req_idx]
		if chain_type == req["chain"] and tier == req["tier"]:
			if requirement_progress[current_task_index][req_idx] < req["count"]:
				requirement_progress[current_task_index][req_idx] += 1
				item_delivered.emit(current_task_index, chain_type, tier)
				task_updated.emit(current_task_index)
				# Check if ALL requirements for this task are fulfilled
				if _is_task_fulfilled(current_task_index):
					_complete_task(current_task_index)
				return true
	return false

func _is_task_fulfilled(task_index: int) -> bool:
	var tasks: Array = _get_zone_tasks()
	var requirements: Array = tasks[task_index]["requirements"]
	for req_idx in range(requirements.size()):
		if requirement_progress[task_index][req_idx] < requirements[req_idx]["count"]:
			return false
	return true

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
		"requirement_progress": requirement_progress.duplicate(true),
		"tasks_completed": tasks_completed.duplicate(),
		"current_task_index": current_task_index,
		"zone_complete": zone_complete,
		"zones_completed": zones_completed.duplicate(),
	}

func load_data(data: Dictionary) -> void:
	current_zone = data.get("current_zone", 1)
	tasks_completed = data.get("tasks_completed", [false, false, false])
	current_task_index = data.get("current_task_index", 0)
	zone_complete = data.get("zone_complete", false)
	zones_completed = data.get("zones_completed", {})
	# Handle both old single-progress and new multi-requirement format
	if data.has("requirement_progress"):
		requirement_progress = data["requirement_progress"]
	elif data.has("task_progress"):
		# Backward compat: old format had flat array of ints
		var old_progress: Array = data["task_progress"]
		requirement_progress = []
		for i in range(old_progress.size()):
			requirement_progress.append([old_progress[i]])
	else:
		# Default: reset
		var tasks: Array = _get_zone_tasks()
		requirement_progress = []
		for i in range(tasks.size()):
			var req_counts: Array = []
			for j in range(tasks[i]["requirements"].size()):
				req_counts.append(0)
			requirement_progress.append(req_counts)
