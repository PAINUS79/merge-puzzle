extends GutTest
## Zone 2 tests: Mushroom/Crystal chains, multi-requirement tasks, zone progression
## ZN-01 through ZN-16

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

func _complete_zone1() -> void:
	# Zone 1 tasks use single-requirement format
	TaskManager.try_deliver_item(1, 4)  # TOOLS x2
	TaskManager.try_deliver_item(1, 4)
	TaskManager.try_deliver_item(0, 4)  # CROPS x2
	TaskManager.try_deliver_item(0, 4)
	TaskManager.try_deliver_item(2, 4)  # CREATURES x1


# --- Chain Definition Tests ---

# ZN-01: Mushroom chain has 5 tiers with correct sell values
func test_zn01_mushroom_chain() -> void:
	var chain: Array = ItemData.CHAINS[ItemData.ChainType.MUSHROOMS]
	assert_eq(chain.size(), 5, "Mushroom chain should have 5 tiers")
	assert_eq(chain[0]["name"], "Spore")
	assert_eq(chain[4]["name"], "Glowcap")
	# Sell values: 1, 3, 6, 12, 24 (steeper curve than Zone 1)
	assert_eq(chain[0]["sell_value"], 1)
	assert_eq(chain[1]["sell_value"], 3)
	assert_eq(chain[2]["sell_value"], 6)
	assert_eq(chain[3]["sell_value"], 12)
	assert_eq(chain[4]["sell_value"], 24)

# ZN-02: Crystal chain has 5 tiers with correct sell values
func test_zn02_crystal_chain() -> void:
	var chain: Array = ItemData.CHAINS[ItemData.ChainType.CRYSTALS]
	assert_eq(chain.size(), 5, "Crystal chain should have 5 tiers")
	assert_eq(chain[0]["name"], "Shard")
	assert_eq(chain[4]["name"], "Star Crystal")
	assert_eq(chain[0]["sell_value"], 1)
	assert_eq(chain[4]["sell_value"], 24)

# ZN-03: Mushroom items merge correctly
func test_zn03_mushroom_merge() -> void:
	var source := _place_item(ItemData.ChainType.MUSHROOMS, 0, 0, 0)
	var target := _place_item(ItemData.ChainType.MUSHROOMS, 0, 1, 0)
	board._perform_merge(source, target, 1, 0)
	await get_tree().process_frame
	assert_null(board.grid[0][0], "Source cell empty")
	assert_not_null(board.grid[1][0], "Merged item exists")
	assert_eq(board.grid[1][0].tier, 1, "Tier 1 after merge")
	assert_eq(board.grid[1][0].chain_type, ItemData.ChainType.MUSHROOMS)

# ZN-04: Crystal items merge correctly
func test_zn04_crystal_merge() -> void:
	var source := _place_item(ItemData.ChainType.CRYSTALS, 2, 0, 0)
	var target := _place_item(ItemData.ChainType.CRYSTALS, 2, 1, 0)
	board._perform_merge(source, target, 1, 0)
	await get_tree().process_frame
	assert_not_null(board.grid[1][0])
	assert_eq(board.grid[1][0].tier, 3, "Crystal tier 3 after merge")

# ZN-05: Cross-chain merge rejected (Mushroom + Crystal)
func test_zn05_cross_chain_no_merge() -> void:
	var mushroom := _place_item(ItemData.ChainType.MUSHROOMS, 0, 0, 0)
	var crystal := _place_item(ItemData.ChainType.CRYSTALS, 0, 1, 0)
	assert_false(mushroom.can_merge_with(crystal), "Different chains should not merge")

# ZN-06: Max tier merge rejected for Zone 2 chains
func test_zn06_max_tier_merge_rejected() -> void:
	var m1 := _place_item(ItemData.ChainType.MUSHROOMS, ItemData.MAX_TIER, 0, 0)
	var m2 := _place_item(ItemData.ChainType.MUSHROOMS, ItemData.MAX_TIER, 1, 0)
	assert_false(m1.can_merge_with(m2), "Max tier Mushroom should not merge")
	var c1 := _place_item(ItemData.ChainType.CRYSTALS, ItemData.MAX_TIER, 2, 0)
	var c2 := _place_item(ItemData.ChainType.CRYSTALS, ItemData.MAX_TIER, 3, 0)
	assert_false(c1.can_merge_with(c2), "Max tier Crystal should not merge")


# --- Zone Progression Tests ---

# ZN-07: Zone 2 is locked at start
func test_zn07_zone2_locked_at_start() -> void:
	assert_true(TaskManager.is_zone_unlocked(1), "Zone 1 always unlocked")
	assert_false(TaskManager.is_zone_unlocked(2), "Zone 2 locked at start")

# ZN-08: Completing Zone 1 unlocks Zone 2
func test_zn08_zone1_complete_unlocks_zone2() -> void:
	_complete_zone1()
	assert_true(TaskManager.zone_complete, "Zone 1 is complete")
	assert_true(TaskManager.zones_completed.get(1, false))
	assert_true(TaskManager.is_zone_unlocked(2), "Zone 2 now unlocked")

# ZN-09: Zone 2 has 5 tasks with correct structure
func test_zn09_zone2_task_structure() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	assert_eq(TaskManager.get_total_tasks(), 5, "Zone 2 should have 5 tasks")
	assert_eq(TaskManager.current_zone, 2)
	assert_false(TaskManager.zone_complete)
	var task := TaskManager.get_current_task()
	assert_eq(task["name"], "Light the Path")
	assert_eq(task["requirements"][0]["chain"], 3)  # MUSHROOMS
	assert_eq(task["requirements"][0]["tier"], 4)
	assert_eq(task["requirements"][0]["count"], 2)

# ZN-10: Zone 2 all 5 chains active
func test_zn10_all_5_chains_active() -> void:
	var z2_chains: Array = ItemData.get_chains_for_zone(2)
	assert_eq(z2_chains.size(), 5, "Zone 2 has all 5 chains")
	assert_has(z2_chains, ItemData.ChainType.CROPS)
	assert_has(z2_chains, ItemData.ChainType.TOOLS)
	assert_has(z2_chains, ItemData.ChainType.CREATURES)
	assert_has(z2_chains, ItemData.ChainType.MUSHROOMS)
	assert_has(z2_chains, ItemData.ChainType.CRYSTALS)


# --- Multi-Requirement Task Tests ---

# ZN-11: Single-requirement task delivery (Task 1: 2x Glowcap)
func test_zn11_single_req_delivery() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	var result := TaskManager.try_deliver_item(3, 4)  # MUSHROOMS max
	assert_true(result, "Glowcap delivery should succeed")
	assert_eq(TaskManager.get_requirement_progress(0, 0), 1)
	assert_false(TaskManager.is_task_completed(0), "Not yet complete (need 2)")
	TaskManager.try_deliver_item(3, 4)
	assert_true(TaskManager.is_task_completed(0), "Task 1 complete")

# ZN-12: Multi-requirement task delivery (Task 2: 1x Star Crystal + 1x Garden Fence)
func test_zn12_multi_req_delivery() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	# Complete Task 1 first
	TaskManager.try_deliver_item(3, 4)
	TaskManager.try_deliver_item(3, 4)
	# Now on Task 2: needs Crystal T5 + Tools T5
	var task := TaskManager.get_current_task()
	assert_eq(task["name"], "Craft a Lantern")
	# Deliver Crystal
	var r1 := TaskManager.try_deliver_item(4, 4)  # CRYSTALS max
	assert_true(r1, "Crystal delivery should succeed")
	assert_false(TaskManager.is_task_completed(1), "Need Tools too")
	# Wrong item should fail
	var r_wrong := TaskManager.try_deliver_item(0, 4)  # CROPS (not needed)
	assert_false(r_wrong, "CROPS not needed for this task")
	# Deliver Tools
	var r2 := TaskManager.try_deliver_item(1, 4)  # TOOLS max
	assert_true(r2, "Tools delivery should succeed")
	assert_true(TaskManager.is_task_completed(1), "Task 2 complete with both requirements")

# ZN-13: Task with quantity > 1 and multiple chains (Task 3: 3x Shiitake + 1x Golden Harvest)
func test_zn13_quantity_and_multi_chain() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	# Complete Tasks 1 & 2
	TaskManager.try_deliver_item(3, 4)
	TaskManager.try_deliver_item(3, 4)
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(1, 4)
	# Now Task 3: 3x Mushroom T3 + 1x Crops T4
	assert_eq(TaskManager.get_current_task()["name"], "Feed the Fox")
	TaskManager.try_deliver_item(3, 3)  # Shiitake 1
	TaskManager.try_deliver_item(3, 3)  # Shiitake 2
	assert_false(TaskManager.is_task_completed(2))
	TaskManager.try_deliver_item(0, 4)  # Golden Harvest
	assert_false(TaskManager.is_task_completed(2), "Still need 1 more Shiitake")
	TaskManager.try_deliver_item(3, 3)  # Shiitake 3
	assert_true(TaskManager.is_task_completed(2), "Task 3 complete")

# ZN-14: Full Zone 2 completion
func test_zn14_zone2_full_completion() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	watch_signals(TaskManager)
	# Task 1: 2x Glowcap
	TaskManager.try_deliver_item(3, 4)
	TaskManager.try_deliver_item(3, 4)
	# Task 2: 1x Star Crystal + 1x Garden Fence
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(1, 4)
	# Task 3: 3x Shiitake + 1x Golden Harvest
	TaskManager.try_deliver_item(3, 3)
	TaskManager.try_deliver_item(3, 3)
	TaskManager.try_deliver_item(3, 3)
	TaskManager.try_deliver_item(0, 4)
	# Task 4: 2x Star Crystal + 2x Glowcap
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(3, 4)
	TaskManager.try_deliver_item(3, 4)
	# Task 5: 1x Phoenix Chicken + 1x Star Crystal + 1x Glowcap
	TaskManager.try_deliver_item(2, 4)
	TaskManager.try_deliver_item(4, 4)
	TaskManager.try_deliver_item(3, 4)

	assert_true(TaskManager.zone_complete, "Zone 2 complete")
	assert_signal_emitted(TaskManager, "zone_completed")
	assert_true(TaskManager.zones_completed.get(2, false))
	# Total rewards: 120+160+180+220+300 = 980 coins, 6+8+10+12+15 = 51 gems
	# Plus Zone 1 rewards: 450 coins, 23 gems
	assert_eq(Economy.coins, 450 + 980, "Total coins from both zones")
	assert_eq(Economy.gems, 23 + 51, "Total gems from both zones")


# --- Save/Load Tests ---

# ZN-15: Multi-zone save/load round-trip
func test_zn15_multizone_save_load() -> void:
	_complete_zone1()
	TaskManager.set_zone(2)
	# Partial progress on Task 1
	TaskManager.try_deliver_item(3, 4)
	var saved := TaskManager.save_data()
	assert_eq(saved["current_zone"], 2)
	assert_true(saved["zones_completed"].get(1, false))
	assert_eq(saved["requirement_progress"][0][0], 1)

	# Reset and reload
	TaskManager.current_zone = 1
	TaskManager.zones_completed = {}
	TaskManager.reset_tasks()
	TaskManager.load_data(saved)

	assert_eq(TaskManager.current_zone, 2)
	assert_true(TaskManager.zones_completed.get(1, false), "Z1 completion persisted")
	assert_eq(TaskManager.get_requirement_progress(0, 0), 1, "Z2 progress persisted")
	assert_true(TaskManager.is_zone_unlocked(2))

# ZN-16: Board save/load with Zone 2 items
func test_zn16_zone2_board_save_load() -> void:
	_place_item(ItemData.ChainType.MUSHROOMS, 2, 0, 0)
	_place_item(ItemData.ChainType.CRYSTALS, 3, 3, 3)
	var save_data: Array = board.get_grid_save_data()
	assert_eq(save_data.size(), 2)
	board.load_grid_data(save_data)
	await get_tree().process_frame
	assert_not_null(board.grid[0][0])
	assert_eq(board.grid[0][0].chain_type, ItemData.ChainType.MUSHROOMS)
	assert_eq(board.grid[0][0].tier, 2)
	assert_not_null(board.grid[3][3])
	assert_eq(board.grid[3][3].chain_type, ItemData.ChainType.CRYSTALS)
	assert_eq(board.grid[3][3].tier, 3)
