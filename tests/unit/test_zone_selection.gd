extends GutTest
## Zone selection UI and transition flow tests
## ZS-01 through ZS-10

func before_each() -> void:
	EnergyManager.current_energy = EnergyManager.MAX_ENERGY
	Economy.coins = 0
	Economy.gems = 0
	TaskManager.current_zone = 1
	TaskManager.zones_completed = {}
	TaskManager.reset_tasks()

func _complete_zone1() -> void:
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(2, 4)


# --- Zone Unlock State Tests ---

# ZS-01: Zone 2 is locked when Zone 1 is incomplete
func test_zs01_zone2_locked_initially() -> void:
	assert_true(TaskManager.is_zone_unlocked(1), "Zone 1 always unlocked")
	assert_false(TaskManager.is_zone_unlocked(2), "Zone 2 locked at start")
	assert_eq(TaskManager.get_highest_unlocked_zone(), 1)

# ZS-02: Zone 2 unlocks after Zone 1 completion
func test_zs02_zone2_unlocks_after_zone1() -> void:
	_complete_zone1()
	assert_true(TaskManager.is_zone_unlocked(2), "Zone 2 unlocked after Zone 1 done")
	assert_eq(TaskManager.get_highest_unlocked_zone(), 2)

# ZS-03: Partial Zone 1 progress does not unlock Zone 2
func test_zs03_partial_zone1_no_unlock() -> void:
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(1, 4)
	# Only completed task 0, tasks 1 and 2 remain
	assert_false(TaskManager.is_zone_unlocked(2), "Zone 2 still locked with partial progress")


# --- Zone Transition Tests ---

# ZS-04: Switching to Zone 2 resets task state for that zone
func test_zs04_switch_to_zone2_resets_tasks() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	assert_eq(TaskManager.current_zone, 2)
	assert_eq(TaskManager.get_total_tasks(), 5)
	assert_eq(TaskManager.get_completed_count(), 0)
	assert_false(TaskManager.zone_complete)

# ZS-05: Switching back to Zone 1 preserves completion
func test_zs05_switch_back_preserves_completion() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	# Switch back to Zone 1
	TaskManager.set_zone(1)
	assert_eq(TaskManager.current_zone, 1)
	assert_true(TaskManager.zone_complete, "Zone 1 still complete after switching back")
	assert_true(TaskManager.zones_completed.get(1, false))

# ZS-06: Zone 2 progress persists across zone switches
func test_zs06_zone2_progress_persists() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	# Partial progress on Zone 2 task 1
	TaskManager.try_deliver_item(3, 4)
	assert_eq(TaskManager.get_requirement_progress(0, 0), 1)

	# Save state, switch away and back
	var saved := TaskManager.save_data()
	TaskManager.set_zone(1)
	TaskManager.load_data(saved)
	TaskManager.set_zone(2)

	# Reload saved data for Zone 2
	TaskManager.load_data(saved)
	assert_eq(TaskManager.current_zone, 2)
	assert_eq(TaskManager.get_requirement_progress(0, 0), 1, "Z2 progress preserved")


# --- Progress Indicator Tests ---

# ZS-07: Zone 1 progress counts correctly
func test_zs07_zone1_progress_count() -> void:
	assert_eq(TaskManager.get_completed_count(), 0)
	assert_eq(TaskManager.get_total_tasks(), 3)
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(1, 4)
	assert_eq(TaskManager.get_completed_count(), 1, "1 of 3 tasks done")
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(0, 4)
	assert_eq(TaskManager.get_completed_count(), 2, "2 of 3 tasks done")

# ZS-08: Zone 2 progress counts correctly with multi-requirement tasks
func test_zs08_zone2_progress_count() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	assert_eq(TaskManager.get_completed_count(), 0)
	assert_eq(TaskManager.get_total_tasks(), 5)
	# Complete task 1
	TaskManager.try_deliver_item(3, 4)
	TaskManager.try_deliver_item(3, 4)
	assert_eq(TaskManager.get_completed_count(), 1, "1 of 5 Zone 2 tasks done")


# --- Save/Load Across Zone Transitions ---

# ZS-09: Full save/load round-trip preserves zone unlock state
func test_zs09_save_load_zone_unlock() -> void:
	_complete_zone1()
	var saved := TaskManager.save_data()

	# Reset everything
	TaskManager.current_zone = 1
	TaskManager.zones_completed = {}
	TaskManager.reset_tasks()
	assert_false(TaskManager.is_zone_unlocked(2), "Reset clears unlock")

	# Restore
	TaskManager.load_data(saved)
	assert_true(TaskManager.is_zone_unlocked(2), "Unlock state restored from save")
	assert_true(TaskManager.zones_completed.get(1, false))

# ZS-10: Zone 1 always remains accessible even from Zone 2
func test_zs10_zone1_always_accessible() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	assert_true(TaskManager.is_zone_unlocked(1), "Zone 1 always accessible")
	# Can switch back
	TaskManager.set_zone(1)
	assert_eq(TaskManager.current_zone, 1)
	assert_true(TaskManager.zone_complete)
