extends GutTest
## Integration test: Zone 2 play session (Whispering Woods)
## Full game loop: Zone 1 completion -> Zone 2 unlock -> Zone 2 merges -> completion

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

func _build_max_tier(chain_type: int, start_col: int) -> void:
	"""Build a max-tier item by merging from tier 0 up."""
	var s := _place_item(chain_type, 0, start_col, 0)
	var t := _place_item(chain_type, 0, start_col + 1, 0)
	board._perform_merge(s, t, start_col + 1, 0)
	await get_tree().process_frame
	for tier in range(1, ItemData.MAX_TIER):
		var extra := _place_item(chain_type, tier, start_col, 0)
		board._perform_merge(extra, board.grid[start_col + 1][0], start_col + 1, 0)
		await get_tree().process_frame

func _clear_cell(col: int, row: int) -> void:
	if board.grid[col][row] != null:
		board.grid[col][row].queue_free()
		board.grid[col][row] = null


# Full cross-zone session with board merges
func test_full_cross_zone_session() -> void:
	watch_signals(TaskManager)

	# --- Phase 1: Complete Zone 1 ---
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(2, 4)
	assert_true(TaskManager.zone_complete, "Zone 1 complete")
	assert_true(TaskManager.is_zone_unlocked(2))
	var z1_coins := Economy.coins

	# --- Phase 2: Switch to Zone 2 ---
	TaskManager.set_zone(2)
	assert_eq(TaskManager.current_zone, 2)
	assert_eq(TaskManager.get_total_tasks(), 5)

	# --- Phase 3: Build Glowcap via board merges (Task 1) ---
	_build_max_tier(ItemData.ChainType.MUSHROOMS, 0)
	assert_eq(board.grid[1][0].tier, ItemData.MAX_TIER, "Glowcap built")
	assert_eq(TaskManager.get_requirement_progress(0, 0), 1, "Auto-delivered")
	_clear_cell(1, 0)
	await get_tree().process_frame

	_build_max_tier(ItemData.ChainType.MUSHROOMS, 0)
	assert_true(TaskManager.is_task_completed(0), "Task 1 complete")
	assert_eq(Economy.coins, z1_coins + 120)
	_clear_cell(1, 0)
	await get_tree().process_frame

	# --- Phase 4: Complete remaining tasks via direct delivery ---
	# Task 2: 1x Star Crystal + 1x Garden Fence
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(1, 4)
	assert_true(TaskManager.is_task_completed(1))

	# Task 3: 3x Shiitake Cluster + 1x Golden Harvest
	TaskManager.try_deliver_item(3, 3)
	TaskManager.try_deliver_item(3, 3)
	TaskManager.try_deliver_item(3, 3)
	TaskManager.try_deliver_item(0, 4)
	assert_true(TaskManager.is_task_completed(2))

	# Task 4: 2x Star Crystal + 2x Glowcap
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(3, 4)
	TaskManager.try_deliver_item(3, 4)
	assert_true(TaskManager.is_task_completed(3))

	# Task 5: 1x Phoenix Chicken + 1x Star Crystal + 1x Glowcap
	TaskManager.try_deliver_item(2, 4)
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(3, 4)
	assert_true(TaskManager.zone_complete, "Zone 2 complete")
	assert_signal_emitted(TaskManager, "zone_completed")


# Energy consumption during Zone 2 merges
func test_zone2_energy_consumption() -> void:
	var initial := EnergyManager.current_energy
	var s := _place_item(ItemData.ChainType.MUSHROOMS, 0, 0, 0)
	var t := _place_item(ItemData.ChainType.MUSHROOMS, 0, 1, 0)
	board._perform_merge(s, t, 1, 0)
	await get_tree().process_frame
	assert_eq(EnergyManager.current_energy, initial - 1, "1 energy per merge in Zone 2")


# Board consistency with Zone 2 items
func test_zone2_board_consistency() -> void:
	var board_size: int = board.COLS * board.ROWS
	_place_item(ItemData.ChainType.MUSHROOMS, 0, 0, 0)
	_place_item(ItemData.ChainType.MUSHROOMS, 0, 1, 0)
	_place_item(ItemData.ChainType.CRYSTALS, 1, 4, 4)

	var items := 0
	var empty := 0
	for col in range(board.COLS):
		for row in range(board.ROWS):
			if board.grid[col][row] != null:
				items += 1
			else:
				empty += 1
	assert_eq(items + empty, board_size, "Invariant holds with Zone 2 items")

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
	assert_eq(items + empty, board_size, "Invariant holds after Zone 2 merge")
