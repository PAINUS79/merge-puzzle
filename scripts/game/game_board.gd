extends Node2D

signal merge_performed(chain_type: int, new_tier: int)
signal item_sold(chain_type: int, tier: int, value: int)
signal board_full()
signal item_tapped(item: MergeItem)

const COLS: int = 7
const ROWS: int = 9
const CELL_SIZE: int = 48
const GUTTER: int = 6
const MARGIN_X: int = 16
const MARGIN_Y: int = 80  # Top margin for HUD space

var grid: Array = []  # 2D array [col][row] of MergeItem or null
var _dragged_item: MergeItem = null
var _highlight_cells: Array = []
var _grid_background: Node2D = null
var _item_layer: Node2D = null
var _last_merge_data: Dictionary = {}
var _sell_timer: float = 0.0
var _sell_item: MergeItem = null
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_touch_held: bool = false

func _ready() -> void:
	_grid_background = Node2D.new()
	_grid_background.name = "GridBackground"
	add_child(_grid_background)
	_item_layer = Node2D.new()
	_item_layer.name = "ItemLayer"
	add_child(_item_layer)
	_init_grid()
	_draw_grid_background()

func _init_grid() -> void:
	grid = []
	for col in range(COLS):
		var column: Array = []
		for row in range(ROWS):
			column.append(null)
		grid.append(column)

func _draw_grid_background() -> void:
	for child in _grid_background.get_children():
		child.queue_free()
	for col in range(COLS):
		for row in range(ROWS):
			var cell := ColorRect.new()
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.position = _grid_to_world(col, row)
			cell.color = Color(0.96, 0.93, 0.87, 1.0)  # Light beige
			_grid_background.add_child(cell)
			# Cell border
			var border := ReferenceRect.new()
			border.size = Vector2(CELL_SIZE, CELL_SIZE)
			border.position = _grid_to_world(col, row)
			border.border_color = Color(0.85, 0.82, 0.75, 1.0)
			border.border_width = 1.0
			border.editor_only = false
			_grid_background.add_child(border)

func _grid_to_world(col: int, row: int) -> Vector2:
	var x: float = MARGIN_X + col * (CELL_SIZE + GUTTER)
	var y: float = MARGIN_Y + row * (CELL_SIZE + GUTTER)
	return Vector2(x, y)

func _grid_to_world_center(col: int, row: int) -> Vector2:
	return _grid_to_world(col, row) + Vector2(CELL_SIZE / 2.0, CELL_SIZE / 2.0)

func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var col: int = int((world_pos.x - MARGIN_X) / (CELL_SIZE + GUTTER))
	var row: int = int((world_pos.y - MARGIN_Y) / (CELL_SIZE + GUTTER))
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return Vector2i(-1, -1)
	# Check if actually within the cell bounds (not in gutter)
	var cell_pos: Vector2 = _grid_to_world(col, row)
	if world_pos.x < cell_pos.x or world_pos.x > cell_pos.x + CELL_SIZE:
		return Vector2i(-1, -1)
	if world_pos.y < cell_pos.y or world_pos.y > cell_pos.y + CELL_SIZE:
		return Vector2i(-1, -1)
	return Vector2i(col, row)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_start(event.position)
		else:
			_on_touch_end(event.position)
	elif event is InputEventScreenDrag:
		_on_touch_drag(event.position)
	# Also handle mouse for desktop testing
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_touch_start(event.position)
			else:
				_on_touch_end(event.position)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _dragged_item:
			_on_touch_drag(event.position)

func _process(delta: float) -> void:
	# Long-press sell detection
	if _is_touch_held and _sell_item and not _dragged_item:
		_sell_timer += delta
		if _sell_timer >= 0.5:
			_sell_item_action(_sell_item)
			_is_touch_held = false
			_sell_item = null
			_sell_timer = 0.0

func _on_touch_start(pos: Vector2) -> void:
	var grid_pos: Vector2i = _world_to_grid(pos)
	if grid_pos.x < 0:
		return
	var item: MergeItem = grid[grid_pos.x][grid_pos.y]
	if item == null:
		return
	_touch_start_pos = pos
	_touch_start_time = Time.get_ticks_msec() / 1000.0
	_is_touch_held = true
	_sell_item = item
	_sell_timer = 0.0

func _on_touch_drag(pos: Vector2) -> void:
	# Start drag if moved enough
	if _is_touch_held and _sell_item and not _dragged_item:
		if pos.distance_to(_touch_start_pos) > 8.0:
			_is_touch_held = false
			_sell_timer = 0.0
			_dragged_item = _sell_item
			_sell_item = null
			_dragged_item.start_drag(pos)
			_update_highlights()
	if _dragged_item:
		_dragged_item.update_drag(pos)
		_update_highlights()

func _on_touch_end(pos: Vector2) -> void:
	_is_touch_held = false
	_sell_item = null
	_sell_timer = 0.0
	if _dragged_item == null:
		return
	var grid_pos: Vector2i = _world_to_grid(pos)
	_clear_highlights()
	if grid_pos.x >= 0:
		var target_item: MergeItem = grid[grid_pos.x][grid_pos.y]
		if target_item != null and target_item != _dragged_item and _dragged_item.can_merge_with(target_item):
			_perform_merge(_dragged_item, target_item, grid_pos.x, grid_pos.y)
		elif target_item == null:
			_move_item(_dragged_item, grid_pos.x, grid_pos.y)
		else:
			_dragged_item.end_drag()
			_dragged_item.snap_back()
	else:
		_dragged_item.end_drag()
		_dragged_item.snap_back()
	_dragged_item = null

func _perform_merge(source: MergeItem, target: MergeItem, to_col: int, to_row: int) -> void:
	if not EnergyManager.use_energy(1):
		source.end_drag()
		source.snap_back()
		return
	var new_tier: int = source.tier + 1
	var chain: int = source.chain_type
	# Remove source from grid
	grid[source.grid_col][source.grid_row] = null
	# Remove target from grid
	grid[to_col][to_row] = null
	# Animate removal
	source.end_drag()
	source.play_merge_animation()
	target.play_merge_animation()
	# Create new merged item
	var new_item := _create_item(chain, new_tier, to_col, to_row)
	new_item.play_spawn_animation()
	_last_merge_data = {"chain_type": chain, "tier": new_tier}
	merge_performed.emit(chain, new_tier)
	# Check if this item can be delivered to a task
	if new_tier == ItemData.MAX_TIER:
		TaskManager.try_deliver_item(chain, new_tier)
	# Auto-save
	_auto_save()

func _move_item(item: MergeItem, to_col: int, to_row: int) -> void:
	grid[item.grid_col][item.grid_row] = null
	grid[to_col][to_row] = item
	item.grid_col = to_col
	item.grid_row = to_row
	item.end_drag()
	var tween := item.create_tween()
	tween.tween_property(item, "position", _grid_to_world_center(to_col, to_row), 0.15)

func _sell_item_action(item: MergeItem) -> void:
	var value: int = item.get_sell_value()
	Economy.add_coins(value)
	grid[item.grid_col][item.grid_row] = null
	item_sold.emit(item.chain_type, item.tier, value)
	item.play_merge_animation()  # Reuse disappear animation
	_auto_save()

func _create_item(chain_type: int, tier: int, col: int, row: int) -> MergeItem:
	var item := MergeItem.new()
	_item_layer.add_child(item)
	item.setup(chain_type, tier, col, row)
	item.position = _grid_to_world_center(col, row)
	grid[col][row] = item
	return item

func spawn_item(chain_type: int, tier: int) -> MergeItem:
	var empty_cells: Array = _get_empty_cells()
	if empty_cells.is_empty():
		board_full.emit()
		return null
	var cell: Vector2i = empty_cells[randi() % empty_cells.size()]
	var item := _create_item(chain_type, tier, cell.x, cell.y)
	item.play_spawn_animation()
	_auto_save()
	return item

func spawn_item_at(chain_type: int, tier: int, col: int, row: int) -> MergeItem:
	if grid[col][row] != null:
		return null
	var item := _create_item(chain_type, tier, col, row)
	item.play_spawn_animation()
	return item

func _get_empty_cells() -> Array:
	var cells: Array = []
	for col in range(COLS):
		for row in range(ROWS):
			if grid[col][row] == null:
				cells.append(Vector2i(col, row))
	return cells

func get_empty_adjacent_cells(col: int, row: int) -> Array:
	var cells: Array = []
	var directions: Array = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for dir in directions:
		var nc: int = col + dir.x
		var nr: int = row + dir.y
		if nc >= 0 and nc < COLS and nr >= 0 and nr < ROWS and grid[nc][nr] == null:
			cells.append(Vector2i(nc, nr))
	return cells

func is_board_full() -> bool:
	return _get_empty_cells().is_empty()

func _update_highlights() -> void:
	# Could add visual highlight for valid merge targets
	pass

func _clear_highlights() -> void:
	pass

func _auto_save() -> void:
	SaveManager.save_game(get_grid_save_data(), {})

func get_grid_save_data() -> Array:
	var data: Array = []
	for col in range(COLS):
		for row in range(ROWS):
			var item: MergeItem = grid[col][row]
			if item != null:
				data.append(item.save_data())
	return data

func load_grid_data(data: Array) -> void:
	# Clear existing items
	for col in range(COLS):
		for row in range(ROWS):
			if grid[col][row] != null:
				grid[col][row].queue_free()
				grid[col][row] = null
	# Recreate items
	for item_data in data:
		_create_item(
			item_data["chain_type"],
			item_data["tier"],
			item_data["col"],
			item_data["row"]
		)
