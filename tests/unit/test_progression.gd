extends GutTest
## Progression tests: Zone 1 task completion, win/lose conditions

func before_each() -> void:
	EnergyManager.current_energy = EnergyManager.MAX_ENERGY
	Economy.coins = 0
	Economy.gems = 0
	TaskManager.current_zone = 1
	TaskManager.zones_completed = {}
	TaskManager.reset_tasks()


# Zone 1 task structure is correct
func test_zone1_has_three_tasks() -> void:
	assert_eq(TaskManager.get_total_tasks(), 3, "Zone 1 should have 3 tasks")
	assert_false(TaskManager.zone_complete, "Zone should not be complete at start")
	assert_eq(TaskManager.current_task_index, 0, "Should start at task 0")


# Task 1: Clear the weeds (deliver 2x Garden Fence = TOOLS tier 4)
func test_task1_delivery_and_completion() -> void:
	var task := TaskManager.get_current_task()
	assert_eq(task["name"], "Clear the weeds")
	assert_eq(task["requirements"][0]["chain"], 1)  # TOOLS
	assert_eq(task["requirements"][0]["tier"], 4)
	assert_eq(task["requirements"][0]["count"], 2)

	# Deliver wrong chain — should fail
	var result := TaskManager.try_deliver_item(0, 4)  # CROPS tier 4
	assert_false(result, "Wrong chain should not deliver")
	assert_eq(TaskManager.get_requirement_progress(0, 0), 0)

	# Deliver correct first item
	result = TaskManager.try_deliver_item(1, 4)
	assert_true(result, "Correct delivery should succeed")
	assert_eq(TaskManager.get_requirement_progress(0, 0), 1)
	assert_false(TaskManager.is_task_completed(0), "Task not yet complete")

	# Deliver second
	result = TaskManager.try_deliver_item(1, 4)
	assert_true(result)
	assert_true(TaskManager.is_task_completed(0), "Task 1 should be complete")
	assert_eq(TaskManager.current_task_index, 1, "Should advance to task 1")


# Complete all zone 1 tasks -> zone_complete
func test_zone1_full_completion() -> void:
	watch_signals(TaskManager)

	# Task 0: 2x TOOLS tier 4
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(1, 4)

	# Task 1: 2x CROPS tier 4
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(0, 4)

	# Task 2: 1x CREATURES tier 4
	TaskManager.try_deliver_item(2, 4)

	assert_true(TaskManager.zone_complete, "Zone should be complete")
	assert_eq(TaskManager.get_completed_count(), 3, "All 3 tasks complete")
	assert_signal_emitted(TaskManager, "zone_completed")


# Coin/gem rewards from task completion
func test_task_rewards() -> void:
	# Complete task 0: 100 coins, 5 gems
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(1, 4)
	assert_eq(Economy.coins, 100, "Should receive 100 coins for task 1")
	assert_eq(Economy.gems, 5, "Should receive 5 gems for task 1")


# Delivery after zone complete should be rejected
func test_no_delivery_after_zone_complete() -> void:
	# Complete all
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(2, 4)

	assert_true(TaskManager.zone_complete)
	var result := TaskManager.try_deliver_item(1, 4)
	assert_false(result, "Should reject delivery after zone complete")


# Energy depletion blocks merges
func test_energy_depletion() -> void:
	EnergyManager.current_energy = 0
	var result := EnergyManager.use_energy(1)
	assert_false(result, "Should not be able to use energy when depleted")


# Task save/load round-trip
func test_task_save_load_round_trip() -> void:
	TaskManager.try_deliver_item(1, 4)
	var saved := TaskManager.save_data()

	TaskManager.reset_tasks()
	assert_eq(TaskManager.get_requirement_progress(0, 0), 0, "Reset should clear progress")

	TaskManager.load_data(saved)
	assert_eq(TaskManager.get_requirement_progress(0, 0), 1, "Loaded progress should match")
	assert_eq(TaskManager.current_task_index, 0, "Task index should match")
