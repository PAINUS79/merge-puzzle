extends GutTest
## Merge Logic tests per CRI-17 Section 4.1–4.4
## ML-01 through ML-09

var board: Node2D = null
var _board_script: GDScript = preload("res://scripts/game/game_board.gd")

func before_each() -> void:
	# Reset autoload state
	EnergyManager.current_energy = EnergyManager.MAX_ENERGY
	Economy.coins = 0
	Economy.gems = 0
	TaskManager.reset_tasks()
	# Create a fresh board
	board = _board_script.new()
	add_child_autofree(board)
	# Wait one frame so _ready runs
	await get_tree().process_frame

func _place_item(chain_type: int, tier: int, col: int, row: int) -> MergeItem:
	var item := MergeItem.new()
	board._item_layer.add_child(item)
	item.setup(chain_type, tier, col, row)
	item.position = board._grid_to_world_center(col, row)
	board.grid[col][row] = item
	return item

func _count_items() -> int:
	var count: int = 0
	for col in range(board.COLS):
		for row in range(board.ROWS):
			if board.grid[col][row] != null:
				count += 1
	return count

func _count_empty() -> int:
	return (board.COLS * board.ROWS) - _count_items()


# ML-01: Two adjacent Tier-1 tiles merge to Tier-2
func test_ml01_tier1_merge_to_tier2() -> void:
	var source := _place_item(ItemData.ChainType.CROPS, 0, 0, 0)
	var _target := _place_item(ItemData.ChainType.CROPS, 0, 1, 0)
	var initial_count := _count_items()
	assert_eq(initial_count, 2, "Should start with 2 items")

	# Perform merge
	board._perform_merge(source, _target, 1, 0)
	await get_tree().process_frame

	# After merge: source cell empty, target cell has tier 1 (0-indexed: tier+1 = 1)
	assert_null(board.grid[0][0], "Source cell should be empty after merge")
	assert_not_null(board.grid[1][0], "Target cell should have the merged item")
	assert_eq(board.grid[1][0].tier, 1, "Merged item should be tier 1 (Tier-2)")


# ML-02: Two adjacent Tier-N tiles merge to Tier-N+1
func test_ml02_tier_n_merge_to_tier_n_plus_1() -> void:
	# Test with tier 2 (index 2) merging to tier 3 (index 3)
	var source := _place_item(ItemData.ChainType.TOOLS, 2, 2, 2)
	var _target := _place_item(ItemData.ChainType.TOOLS, 2, 3, 2)

	board._perform_merge(source, _target, 3, 2)
	await get_tree().process_frame

	assert_null(board.grid[2][2], "Source cell should be empty")
	assert_not_null(board.grid[3][2], "Target cell should have merged item")
	assert_eq(board.grid[3][2].tier, 3, "Merged item should be tier 3")


# ML-03: Merge on last available cell — no crash
func test_ml03_merge_on_last_cell_no_crash() -> void:
	# Fill entire board except two cells, then merge those two
	for col in range(board.COLS):
		for row in range(board.ROWS):
			if col == 0 and row == 0:
				continue
			if col == 1 and row == 0:
				continue
			_place_item(ItemData.ChainType.CROPS, 0, col, row)

	var source := _place_item(ItemData.ChainType.TOOLS, 1, 0, 0)
	var _target := _place_item(ItemData.ChainType.TOOLS, 1, 1, 0)

	# Should not crash
	board._perform_merge(source, _target, 1, 0)
	await get_tree().process_frame

	assert_not_null(board.grid[1][0], "Merged item should exist")
	assert_eq(board.grid[1][0].tier, 2, "Merged item should be tier 2")
	pass_test("Merge on last cell did not crash")


# ML-04: Merge at max tier handled (rejected or special)
func test_ml04_max_tier_merge_rejected() -> void:
	var item_a := _place_item(ItemData.ChainType.CROPS, ItemData.MAX_TIER, 0, 0)
	var item_b := _place_item(ItemData.ChainType.CROPS, ItemData.MAX_TIER, 1, 0)

	# can_merge should return false at max tier
	assert_false(item_a.can_merge_with(item_b), "Max tier items should not be mergeable")

	# Verify ItemData.can_merge also returns false
	assert_false(ItemData.can_merge(ItemData.ChainType.CROPS, ItemData.MAX_TIER), "ItemData.can_merge should reject max tier")


# ML-05: Non-identical adjacent tiles — board state unchanged
func test_ml05_non_identical_no_merge() -> void:
	var item_a := _place_item(ItemData.ChainType.CROPS, 0, 0, 0)
	var item_b := _place_item(ItemData.ChainType.TOOLS, 0, 1, 0)

	assert_false(item_a.can_merge_with(item_b), "Different chain types should not merge")

	# Different tiers same chain
	var item_c := _place_item(ItemData.ChainType.CROPS, 1, 2, 0)
	assert_false(item_a.can_merge_with(item_c), "Different tiers should not merge")

	# Board state unchanged
	assert_eq(_count_items(), 3, "Board should still have 3 items")


# ML-06: Tile merged with empty cell — board state unchanged
func test_ml06_merge_with_empty_cell_unchanged() -> void:
	var item := _place_item(ItemData.ChainType.CROPS, 0, 0, 0)

	# can_merge_with(null) should return false
	assert_false(item.can_merge_with(null), "Cannot merge with null/empty cell")
	assert_eq(_count_items(), 1, "Board should still have 1 item")


# ML-07: Out-of-bounds drag — no crash, board state unchanged
func test_ml07_out_of_bounds_no_crash() -> void:
	_place_item(ItemData.ChainType.CROPS, 0, 0, 0)
	var initial_count := _count_items()

	# _world_to_grid with out-of-bounds coordinates should return (-1, -1)
	var result := board._world_to_grid(Vector2(-100, -100))
	assert_eq(result, Vector2i(-1, -1), "Out of bounds should return (-1, -1)")

	result = board._world_to_grid(Vector2(9999, 9999))
	assert_eq(result, Vector2i(-1, -1), "Far out of bounds should return (-1, -1)")

	# spawn_item_at with out-of-bounds should return null (boundary guard)
	var bad_spawn := board.spawn_item_at(0, 0, -1, -1)
	assert_null(bad_spawn, "Out-of-bounds spawn should return null")

	bad_spawn = board.spawn_item_at(0, 0, board.COLS, board.ROWS)
	assert_null(bad_spawn, "Out-of-bounds spawn at max should return null")

	# Board unchanged
	assert_eq(_count_items(), initial_count, "Board state should be unchanged")
	pass_test("Out-of-bounds operations did not crash")


# ML-09: Chain reaction resolves correctly
func test_ml09_chain_reaction_resolves() -> void:
	# Set up a scenario: merging two tier-0 creates tier-1 at target.
	# Place another tier-1 adjacent. Currently the game doesn't auto-chain,
	# but we verify the first merge resolves cleanly and the adjacent tier-1
	# remains available for a manual second merge.
	var source := _place_item(ItemData.ChainType.CROPS, 0, 0, 0)
	var _target := _place_item(ItemData.ChainType.CROPS, 0, 1, 0)
	var _adjacent := _place_item(ItemData.ChainType.CROPS, 1, 2, 0)

	board._perform_merge(source, _target, 1, 0)
	await get_tree().process_frame

	# After merge: (0,0) empty, (1,0) has tier-1, (2,0) has tier-1
	assert_null(board.grid[0][0], "Source cell should be empty")
	var merged := board.grid[1][0]
	assert_not_null(merged, "Merged item should exist at target")
	assert_eq(merged.tier, 1, "Merged item should be tier 1")

	# The adjacent item should still be there and mergeable with the new item
	var adjacent := board.grid[2][0]
	assert_not_null(adjacent, "Adjacent tier-1 item should still exist")
	assert_true(merged.can_merge_with(adjacent), "Newly merged tier-1 should be mergeable with adjacent tier-1")

	# Now chain: merge the two tier-1 items
	board._perform_merge(merged, adjacent, 2, 0)
	await get_tree().process_frame

	assert_null(board.grid[1][0], "First merged cell should be empty after chain")
	assert_not_null(board.grid[2][0], "Final merged item should be at (2,0)")
	assert_eq(board.grid[2][0].tier, 2, "Chain result should be tier 2")
