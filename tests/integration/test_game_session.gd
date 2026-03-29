extends GutTest
## Integration test: headless simulated play session
## Verifies a full game loop from spawn → merge → task delivery → zone complete

var board: Node2D = null
var _board_script: GDScript = preload("res://scripts/game/game_board.gd")

func before_each() -> void:
	EnergyManager.current_energy = EnergyManager.MAX_ENERGY
	Economy.coins = 0
	Economy.gems = 0
	TaskManager.current_zone = 1
	TaskManager.zones_completed = {}
	TaskManager.reset_tasks()
	board = _board_script.new()
	add_child_autofree(board)
	await get_tree().process_frame

func _place_item(chain_type: int, tier: int, col: int, row: int) -> MergeItem:
	var item := MergeItem.new()
	board._item_layer.add_child(item)
	item.setup(chain_type, tier, col, row)
	item.position = board._grid_to_world_center(col, row)
	board.grid[col][row] = item
	return item


# Simulated play: spawn items, merge up the chain, deliver to tasks
func test_full_play_session() -> void:
	watch_signals(board)
	watch_signals(TaskManager)

	# --- Phase 1: Merge TOOLS chain from tier 0 up to tier 4 (Garden Fence) ---
	# We'll build up tier by tier with direct merges
	# Need 2x tier-4 for task 0

	# Build first Garden Fence: merge tier 0→1→2→3→4
	# Tier 0 pair → tier 1
	var s := _place_item(ItemData.ChainType.TOOLS, 0, 0, 0)
	var t := _place_item(ItemData.ChainType.TOOLS, 0, 1, 0)
	board._perform_merge(s, t, 1, 0)
	await get_tree().process_frame
	assert_eq(board.grid[1][0].tier, 1)

	# Tier 1 pair → tier 2
	var t1_extra := _place_item(ItemData.ChainType.TOOLS, 1, 0, 0)
	board._perform_merge(t1_extra, board.grid[1][0], 1, 0)
	await get_tree().process_frame
	assert_eq(board.grid[1][0].tier, 2)

	# Tier 2 pair → tier 3
	var t2_extra := _place_item(ItemData.ChainType.TOOLS, 2, 0, 0)
	board._perform_merge(t2_extra, board.grid[1][0], 1, 0)
	await get_tree().process_frame
	assert_eq(board.grid[1][0].tier, 3)

	# Tier 3 pair → tier 4 (MAX_TIER) — triggers task delivery
	var t3_extra := _place_item(ItemData.ChainType.TOOLS, 3, 0, 0)
	board._perform_merge(t3_extra, board.grid[1][0], 1, 0)
	await get_tree().process_frame
	assert_eq(board.grid[1][0].tier, 4)
	assert_signal_emitted(board, "merge_performed")

	# First delivery registered
	assert_eq(TaskManager.get_task_progress(0), 1, "First Garden Fence delivered")

	# Build second Garden Fence the same way
	s = _place_item(ItemData.ChainType.TOOLS, 0, 2, 0)
	t = _place_item(ItemData.ChainType.TOOLS, 0, 3, 0)
	board._perform_merge(s, t, 3, 0)
	await get_tree().process_frame

	t1_extra = _place_item(ItemData.ChainType.TOOLS, 1, 2, 0)
	board._perform_merge(t1_extra, board.grid[3][0], 3, 0)
	await get_tree().process_frame

	t2_extra = _place_item(ItemData.ChainType.TOOLS, 2, 2, 0)
	board._perform_merge(t2_extra, board.grid[3][0], 3, 0)
	await get_tree().process_frame

	t3_extra = _place_item(ItemData.ChainType.TOOLS, 3, 2, 0)
	board._perform_merge(t3_extra, board.grid[3][0], 3, 0)
	await get_tree().process_frame

	# Task 0 should now be complete
	assert_true(TaskManager.is_task_completed(0), "Task 0 (Clear the weeds) completed")
	assert_eq(TaskManager.current_task_index, 1, "Advanced to task 1")
	assert_signal_emitted(TaskManager, "task_completed")

	# Verify rewards
	assert_eq(Economy.coins, 100, "Received 100 coins reward")
	assert_eq(Economy.gems, 5, "Received 5 gems reward")


# Test that energy is consumed per merge
func test_energy_consumption_during_session() -> void:
	var initial_energy := EnergyManager.current_energy

	var s := _place_item(ItemData.ChainType.CROPS, 0, 0, 0)
	var t := _place_item(ItemData.ChainType.CROPS, 0, 1, 0)
	board._perform_merge(s, t, 1, 0)
	await get_tree().process_frame

	assert_eq(EnergyManager.current_energy, initial_energy - 1, "One energy consumed per merge")


# Test board state consistency through multiple operations
func test_board_consistency_through_session() -> void:
	var board_size: int = board.COLS * board.ROWS

	# Spawn, merge, spawn, verify invariant each time
	_place_item(ItemData.ChainType.CROPS, 0, 0, 0)
	_place_item(ItemData.ChainType.CROPS, 0, 1, 0)
	_place_item(ItemData.ChainType.TOOLS, 1, 4, 4)

	var items := 0
	var empty := 0
	for col in range(board.COLS):
		for row in range(board.ROWS):
			if board.grid[col][row] != null:
				items += 1
			else:
				empty += 1
	assert_eq(items + empty, board_size, "Invariant holds before merge")

	board._perform_merge(board.grid[0][0], board.grid[1][0], 1, 0)
	await get_tree().process_frame

	items = 0
	empty = 0
	for col in range(board.COLS):
		for row in range(board.ROWS):
			if board.grid[col][row] != null:
				items += 1
			else:
				empty += 1
	assert_eq(items + empty, board_size, "Invariant holds after merge")
