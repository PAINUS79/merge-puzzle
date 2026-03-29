extends GutTest
## Integration test: Zone 2 play session
## Full game loop: Zone 1 completion → Zone 2 unlock → Zone 2 play → Zone 2 completion

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
	"""Build a max-tier item by merging up from tier 0."""
	# Place tier 0 pair and merge up through all tiers
	var s := _place_item(chain_type, 0, start_col, 0)
	var t := _place_item(chain_type, 0, start_col + 1, 0)
	board._perform_merge(s, t, start_col + 1, 0)
	await get_tree().process_frame

	for tier in range(1, ItemData.MAX_TIER):
		var extra := _place_item(chain_type, tier, start_col, 0)
		board._perform_merge(extra, board.grid[start_col + 1][0], start_col + 1, 0)
		await get_tree().process_frame


# Full cross-zone play session
func test_full_cross_zone_session() -> void:
	watch_signals(TaskManager)

	# --- Phase 1: Complete Zone 1 via direct task delivery ---
	TaskManager.try_deliver_item(1, 4)  # TOOLS
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(0, 4)  # CROPS
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(2, 4)  # CREATURES

	assert_true(TaskManager.zone_complete, "Zone 1 complete")
	assert_true(TaskManager.is_zone_unlocked(2), "Zone 2 unlocked")
	var z1_coins := Economy.coins
	var z1_gems := Economy.gems

	# --- Phase 2: Switch to Zone 2 ---
	TaskManager.set_zone(2)
	assert_eq(TaskManager.current_zone, 2)
	assert_false(TaskManager.zone_complete, "Zone 2 not yet complete")
	assert_eq(TaskManager.get_total_tasks(), 3)

	# --- Phase 3: Build and deliver Orchard items via board merges ---
	_build_max_tier(ItemData.ChainType.ORCHARD, 0)
	assert_eq(board.grid[1][0].tier, ItemData.MAX_TIER, "First Golden Apple Tree built")
	assert_eq(TaskManager.get_task_progress(0), 1, "First orchard delivery auto-registered")

	# Clean up board for next build
	board.grid[1][0].queue_free()
	board.grid[1][0] = null
	await get_tree().process_frame

	_build_max_tier(ItemData.ChainType.ORCHARD, 0)
	assert_true(TaskManager.is_task_completed(0), "Task 0 (Plant the orchard) complete")
	assert_eq(Economy.coins, z1_coins + 250, "Received orchard task reward")

	# Clean up
	board.grid[1][0].queue_free()
	board.grid[1][0] = null
	await get_tree().process_frame

	# --- Phase 4: Complete remaining Zone 2 tasks via direct delivery ---
	# Task 1: 2x HONEY tier 4
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(4, 4)
	assert_true(TaskManager.is_task_completed(1), "Task 1 (Sweeten the grove) complete")

	# Task 2: 2x CREATURES tier 4
	TaskManager.try_deliver_item(2, 4)
	TaskManager.try_deliver_item(2, 4)
	assert_true(TaskManager.zone_complete, "Zone 2 complete")
	assert_true(TaskManager.zones_completed.get(2, false))
	assert_signal_emitted(TaskManager, "zone_completed")

	# Verify cumulative rewards
	var expected_coins: int = z1_coins + 250 + 300 + 400
	assert_eq(Economy.coins, expected_coins, "Total coins from both zones")


# Energy consumption during Zone 2 merges
func test_zone2_energy_consumption() -> void:
	var initial := EnergyManager.current_energy

	var s := _place_item(ItemData.ChainType.ORCHARD, 0, 0, 0)
	var t := _place_item(ItemData.ChainType.ORCHARD, 0, 1, 0)
	board._perform_merge(s, t, 1, 0)
	await get_tree().process_frame

	assert_eq(EnergyManager.current_energy, initial - 1, "Energy consumed for Zone 2 merge")


# Board consistency with Zone 2 items
func test_zone2_board_consistency() -> void:
	var board_size: int = board.COLS * board.ROWS

	_place_item(ItemData.ChainType.ORCHARD, 0, 0, 0)
	_place_item(ItemData.ChainType.ORCHARD, 0, 1, 0)
	_place_item(ItemData.ChainType.HONEY, 1, 4, 4)

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
