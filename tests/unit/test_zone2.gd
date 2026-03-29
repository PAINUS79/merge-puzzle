extends GutTest
## Zone 2 tests: new merge chains, zone progression, save/load
## ZN-01 through ZN-12

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


# --- Chain Definition Tests ---

# ZN-01: Orchard chain has 5 tiers
func test_zn01_orchard_chain_has_5_tiers() -> void:
	var chain: Array = ItemData.CHAINS[ItemData.ChainType.ORCHARD]
	assert_eq(chain.size(), 5, "Orchard chain should have 5 tiers")
	assert_eq(chain[0]["name"], "Apple Pip")
	assert_eq(chain[4]["name"], "Golden Apple Tree")

# ZN-02: Honey chain has 5 tiers
func test_zn02_honey_chain_has_5_tiers() -> void:
	var chain: Array = ItemData.CHAINS[ItemData.ChainType.HONEY]
	assert_eq(chain.size(), 5, "Honey chain should have 5 tiers")
	assert_eq(chain[0]["name"], "Wildflower")
	assert_eq(chain[4]["name"], "Ambrosia Jar")

# ZN-03: Zone 2 chains have correct sell values (higher than Zone 1)
func test_zn03_zone2_sell_values_scale() -> void:
	assert_eq(ItemData.get_sell_value(ItemData.ChainType.ORCHARD, 0), 2, "Orchard T0 sell value")
	assert_eq(ItemData.get_sell_value(ItemData.ChainType.ORCHARD, 4), 32, "Orchard T4 sell value")
	assert_eq(ItemData.get_sell_value(ItemData.ChainType.HONEY, 0), 2, "Honey T0 sell value")
	assert_eq(ItemData.get_sell_value(ItemData.ChainType.HONEY, 4), 32, "Honey T4 sell value")

# ZN-04: Orchard items merge correctly
func test_zn04_orchard_merge() -> void:
	var source := _place_item(ItemData.ChainType.ORCHARD, 0, 0, 0)
	var target := _place_item(ItemData.ChainType.ORCHARD, 0, 1, 0)

	board._perform_merge(source, target, 1, 0)
	await get_tree().process_frame

	assert_null(board.grid[0][0], "Source cell empty after merge")
	assert_not_null(board.grid[1][0], "Target cell has merged item")
	assert_eq(board.grid[1][0].tier, 1, "Merged orchard item is tier 1")
	assert_eq(board.grid[1][0].chain_type, ItemData.ChainType.ORCHARD)

# ZN-05: Honey items merge correctly
func test_zn05_honey_merge() -> void:
	var source := _place_item(ItemData.ChainType.HONEY, 2, 0, 0)
	var target := _place_item(ItemData.ChainType.HONEY, 2, 1, 0)

	board._perform_merge(source, target, 1, 0)
	await get_tree().process_frame

	assert_not_null(board.grid[1][0], "Merged honey item exists")
	assert_eq(board.grid[1][0].tier, 3, "Merged honey is tier 3")

# ZN-06: Cross-chain merge rejected (Orchard + Honey)
func test_zn06_cross_chain_no_merge() -> void:
	var orchard := _place_item(ItemData.ChainType.ORCHARD, 0, 0, 0)
	var honey := _place_item(ItemData.ChainType.HONEY, 0, 1, 0)

	assert_false(orchard.can_merge_with(honey), "Orchard and Honey should not merge")


# --- Zone Progression Tests ---

# ZN-07: Zone 2 is locked at start
func test_zn07_zone2_locked_at_start() -> void:
	assert_true(TaskManager.is_zone_unlocked(1), "Zone 1 always unlocked")
	assert_false(TaskManager.is_zone_unlocked(2), "Zone 2 locked at start")

# ZN-08: Completing Zone 1 unlocks Zone 2
func test_zn08_zone1_complete_unlocks_zone2() -> void:
	# Complete Zone 1
	TaskManager.try_deliver_item(1, 4)  # TOOLS
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(0, 4)  # CROPS
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(2, 4)  # CREATURES

	assert_true(TaskManager.zone_complete, "Zone 1 is complete")
	assert_true(TaskManager.zones_completed.get(1, false), "Zone 1 marked in zones_completed")
	assert_true(TaskManager.is_zone_unlocked(2), "Zone 2 now unlocked")

# ZN-09: Zone 2 has 3 tasks with correct structure
func test_zn09_zone2_task_structure() -> void:
	# Complete Zone 1 first
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(2, 4)

	# Switch to Zone 2
	TaskManager.set_zone(2)
	assert_eq(TaskManager.get_total_tasks(), 3, "Zone 2 should have 3 tasks")
	assert_eq(TaskManager.current_zone, 2)
	assert_false(TaskManager.zone_complete, "Zone 2 not yet complete")

	var task := TaskManager.get_current_task()
	assert_eq(task["name"], "Plant the orchard")
	assert_eq(task["required_chain"], 3)  # ORCHARD
	assert_eq(task["required_tier"], 4)

# ZN-10: Zone 2 task delivery and completion
func test_zn10_zone2_task_delivery() -> void:
	# Complete Zone 1 and switch to Zone 2
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(2, 4)
	TaskManager.set_zone(2)

	watch_signals(TaskManager)

	# Task 0: 2x ORCHARD tier 4
	var result := TaskManager.try_deliver_item(3, 4)
	assert_true(result, "Orchard delivery should succeed")
	assert_eq(TaskManager.get_task_progress(0), 1)

	TaskManager.try_deliver_item(3, 4)
	assert_true(TaskManager.is_task_completed(0), "Task 0 complete")
	assert_eq(Economy.coins, 250 + 450, "Coins: Z1 rewards + Z2 task 0")

	# Task 1: 2x HONEY tier 4
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(4, 4)
	assert_true(TaskManager.is_task_completed(1), "Task 1 complete")

	# Task 2: 2x CREATURES tier 4
	TaskManager.try_deliver_item(2, 4)
	TaskManager.try_deliver_item(2, 4)
	assert_true(TaskManager.zone_complete, "Zone 2 complete")
	assert_signal_emitted(TaskManager, "zone_completed")
	assert_true(TaskManager.zones_completed.get(2, false), "Zone 2 in zones_completed")

# ZN-11: Zone 2 wrong-chain delivery rejected
func test_zn11_zone2_wrong_chain_rejected() -> void:
	TaskManager.zones_completed[1] = true
	TaskManager.set_zone(2)

	# Try delivering CROPS (Zone 1 chain) to Zone 2 task that needs ORCHARD
	var result := TaskManager.try_deliver_item(0, 4)
	assert_false(result, "Zone 1 chain should not deliver to Zone 2 task")
	assert_eq(TaskManager.get_task_progress(0), 0)


# --- Save/Load Tests ---

# ZN-12: Multi-zone save/load round-trip
func test_zn12_multizone_save_load() -> void:
	# Complete Zone 1
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(2, 4)

	# Switch to Zone 2 and make partial progress
	TaskManager.set_zone(2)
	TaskManager.try_deliver_item(3, 4)  # One orchard delivery

	# Save
	var saved := TaskManager.save_data()
	assert_eq(saved["current_zone"], 2)
	assert_true(saved["zones_completed"].get(1, false))
	assert_eq(saved["task_progress"][0], 1)

	# Reset and reload
	TaskManager.current_zone = 1
	TaskManager.zones_completed = {}
	TaskManager.reset_tasks()

	TaskManager.load_data(saved)
	assert_eq(TaskManager.current_zone, 2)
	assert_true(TaskManager.zones_completed.get(1, false), "Zone 1 completion persisted")
	assert_eq(TaskManager.get_task_progress(0), 1, "Zone 2 progress persisted")
	assert_true(TaskManager.is_zone_unlocked(2), "Zone 2 still unlocked")


# --- Zone-Chain Mapping Tests ---

# ZN-13: Zone chain mapping returns correct chains
func test_zn13_zone_chain_mapping() -> void:
	var z1_chains: Array = ItemData.get_chains_for_zone(1)
	assert_eq(z1_chains.size(), 3)
	assert_has(z1_chains, ItemData.ChainType.CROPS)
	assert_has(z1_chains, ItemData.ChainType.TOOLS)
	assert_has(z1_chains, ItemData.ChainType.CREATURES)

	var z2_chains: Array = ItemData.get_chains_for_zone(2)
	assert_eq(z2_chains.size(), 3)
	assert_has(z2_chains, ItemData.ChainType.ORCHARD)
	assert_has(z2_chains, ItemData.ChainType.HONEY)
	assert_has(z2_chains, ItemData.ChainType.CREATURES)

# ZN-14: Max tier merge rejected for Zone 2 chains
func test_zn14_max_tier_merge_rejected_zone2() -> void:
	var orchard_max := _place_item(ItemData.ChainType.ORCHARD, ItemData.MAX_TIER, 0, 0)
	var orchard_max2 := _place_item(ItemData.ChainType.ORCHARD, ItemData.MAX_TIER, 1, 0)
	assert_false(orchard_max.can_merge_with(orchard_max2), "Max tier Orchard should not merge")

	var honey_max := _place_item(ItemData.ChainType.HONEY, ItemData.MAX_TIER, 2, 0)
	var honey_max2 := _place_item(ItemData.ChainType.HONEY, ItemData.MAX_TIER, 3, 0)
	assert_false(honey_max.can_merge_with(honey_max2), "Max tier Honey should not merge")

# ZN-15: Board save/load with Zone 2 items
func test_zn15_zone2_board_save_load() -> void:
	_place_item(ItemData.ChainType.ORCHARD, 2, 0, 0)
	_place_item(ItemData.ChainType.HONEY, 3, 3, 3)

	var save_data: Array = board.get_grid_save_data()
	assert_eq(save_data.size(), 2)

	board.load_grid_data(save_data)
	await get_tree().process_frame

	assert_not_null(board.grid[0][0])
	assert_eq(board.grid[0][0].chain_type, ItemData.ChainType.ORCHARD)
	assert_eq(board.grid[0][0].tier, 2)

	assert_not_null(board.grid[3][3])
	assert_eq(board.grid[3][3].chain_type, ItemData.ChainType.HONEY)
	assert_eq(board.grid[3][3].tier, 3)
