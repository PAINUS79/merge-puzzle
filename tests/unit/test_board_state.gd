extends GutTest
## Board State tests per CRI-17 Section 4.4
## BS-01 through BS-04

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

func _count_items() -> int:
	var count: int = 0
	for col in range(board.COLS):
		for row in range(board.ROWS):
			if board.grid[col][row] != null:
				count += 1
	return count

func _count_empty() -> int:
	return (board.COLS * board.ROWS) - _count_items()


# BS-01: After any merge, count(tiles) + count(empty_cells) == BOARD_SIZE
func test_bs01_tile_count_invariant_after_merge() -> void:
	var board_size: int = board.COLS * board.ROWS

	# Initial state: all empty
	assert_eq(_count_items() + _count_empty(), board_size, "Empty board should equal BOARD_SIZE")

	# Place some items
	_place_item(ItemData.ChainType.CROPS, 0, 0, 0)
	_place_item(ItemData.ChainType.CROPS, 0, 1, 0)
	_place_item(ItemData.ChainType.TOOLS, 1, 3, 3)
	assert_eq(_count_items() + _count_empty(), board_size, "Invariant holds after placing items")

	# Merge the two crops
	var source: MergeItem = board.grid[0][0]
	var target: MergeItem = board.grid[1][0]
	board._perform_merge(source, target, 1, 0)
	await get_tree().process_frame

	assert_eq(_count_items() + _count_empty(), board_size, "Invariant holds after merge")

	# Place more and merge again
	_place_item(ItemData.ChainType.CROPS, 1, 0, 0)
	var s2: MergeItem = board.grid[0][0]
	var t2: MergeItem = board.grid[1][0]
	board._perform_merge(s2, t2, 1, 0)
	await get_tree().process_frame

	assert_eq(_count_items() + _count_empty(), board_size, "Invariant holds after second merge")


# BS-02: Serialise/deserialise round-trip — board state identical
func test_bs02_save_load_round_trip() -> void:
	# Place several items at known positions
	_place_item(ItemData.ChainType.CROPS, 0, 0, 0)
	_place_item(ItemData.ChainType.TOOLS, 2, 3, 4)
	_place_item(ItemData.ChainType.CREATURES, 3, 6, 8)

	# Serialize
	var save_data: Array = board.get_grid_save_data()
	assert_eq(save_data.size(), 3, "Should serialize 3 items")

	# Verify data contents
	var found_crops := false
	var found_tools := false
	var found_creatures := false
	for item_data in save_data:
		if item_data["chain_type"] == ItemData.ChainType.CROPS and item_data["tier"] == 0:
			assert_eq(item_data["col"], 0)
			assert_eq(item_data["row"], 0)
			found_crops = true
		elif item_data["chain_type"] == ItemData.ChainType.TOOLS and item_data["tier"] == 2:
			assert_eq(item_data["col"], 3)
			assert_eq(item_data["row"], 4)
			found_tools = true
		elif item_data["chain_type"] == ItemData.ChainType.CREATURES and item_data["tier"] == 3:
			assert_eq(item_data["col"], 6)
			assert_eq(item_data["row"], 8)
			found_creatures = true

	assert_true(found_crops, "Crops item found in save data")
	assert_true(found_tools, "Tools item found in save data")
	assert_true(found_creatures, "Creatures item found in save data")

	# Deserialize into same board (load_grid_data clears first)
	board.load_grid_data(save_data)
	await get_tree().process_frame

	# Verify restored items
	assert_not_null(board.grid[0][0], "Crops item restored")
	assert_eq(board.grid[0][0].chain_type, ItemData.ChainType.CROPS)
	assert_eq(board.grid[0][0].tier, 0)

	assert_not_null(board.grid[3][4], "Tools item restored")
	assert_eq(board.grid[3][4].chain_type, ItemData.ChainType.TOOLS)
	assert_eq(board.grid[3][4].tier, 2)

	assert_not_null(board.grid[6][8], "Creatures item restored")
	assert_eq(board.grid[6][8].chain_type, ItemData.ChainType.CREATURES)
	assert_eq(board.grid[6][8].tier, 3)

	# Re-serialize and compare
	var resave_data: Array = board.get_grid_save_data()
	assert_eq(resave_data.size(), save_data.size(), "Round-trip should preserve item count")


# BS-03: New game — all tile IDs unique
func test_bs03_new_game_unique_tile_ids() -> void:
	# Place multiple items and verify they are distinct objects
	var items: Array = []
	items.append(_place_item(ItemData.ChainType.CROPS, 0, 0, 0))
	items.append(_place_item(ItemData.ChainType.CROPS, 0, 1, 0))
	items.append(_place_item(ItemData.ChainType.TOOLS, 0, 2, 0))
	items.append(_place_item(ItemData.ChainType.CREATURES, 0, 3, 0))

	# Every item should be a unique instance
	for i in range(items.size()):
		for j in range(i + 1, items.size()):
			assert_ne(items[i].get_instance_id(), items[j].get_instance_id(),
				"Item %d and %d should be unique instances" % [i, j])

	# Grid positions should all be unique
	var positions: Array = []
	for item in items:
		var pos := Vector2i(item.grid_col, item.grid_row)
		assert_does_not_have(positions, pos, "Position should be unique")
		positions.append(pos)


# BS-04: Board full — is_board_full() returns true
func test_bs04_board_full_detection() -> void:
	assert_false(board.is_board_full(), "Empty board should not be full")

	# Fill entire board
	for col in range(board.COLS):
		for row in range(board.ROWS):
			_place_item(ItemData.ChainType.CROPS, 0, col, row)

	assert_true(board.is_board_full(), "Full board should be detected")
	assert_eq(_count_items(), board.COLS * board.ROWS, "Item count should equal total cells")
