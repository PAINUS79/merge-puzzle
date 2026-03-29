class_name MergeItem
extends Sprite2D

signal drag_started(item: MergeItem)
signal drag_ended(item: MergeItem)
signal sell_requested(item: MergeItem)

var chain_type: int = 0
var tier: int = 0
var grid_col: int = 0
var grid_row: int = 0
var is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _original_position: Vector2 = Vector2.ZERO
var _original_z: int = 0
var _sell_timer: float = 0.0
var _sell_hold_time: float = 0.5

func setup(p_chain_type: int, p_tier: int, p_col: int, p_row: int) -> void:
	chain_type = p_chain_type
	tier = p_tier
	grid_col = p_col
	grid_row = p_row
	_update_sprite()

func _update_sprite() -> void:
	var path: String = ItemData.get_item_sprite_path(chain_type, tier)
	var tex := load(path)
	if tex:
		texture = tex
		# Scale to fit 48x48 cell
		var tex_size: Vector2 = tex.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			scale = Vector2(44.0 / tex_size.x, 44.0 / tex_size.y)

func get_item_name() -> String:
	return ItemData.get_item_name(chain_type, tier)

func get_sell_value() -> int:
	return ItemData.get_sell_value(chain_type, tier)

func can_merge_with(other: MergeItem) -> bool:
	if other == null:
		return false
	return chain_type == other.chain_type and tier == other.tier and ItemData.can_merge(chain_type, tier)

func start_drag(touch_pos: Vector2) -> void:
	is_dragging = true
	_original_position = position
	_original_z = z_index
	z_index = 100
	_drag_offset = position - touch_pos
	# Scale up feedback
	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.15, 0.1)
	drag_started.emit(self)

func update_drag(touch_pos: Vector2) -> void:
	if is_dragging:
		position = touch_pos + _drag_offset

func end_drag() -> void:
	is_dragging = false
	z_index = _original_z
	var tween := create_tween()
	tween.tween_property(self, "scale", scale / 1.15, 0.1)
	drag_ended.emit(self)

func snap_back() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", _original_position, 0.2).set_ease(Tween.EASE_OUT)

func play_merge_animation() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", scale * 1.5, 0.15)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.tween_callback(queue_free)

func play_spawn_animation() -> void:
	var target_scale: Vector2 = scale
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", target_scale * 1.2, 0.15).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", target_scale, 0.1).set_ease(Tween.EASE_IN)

func save_data() -> Dictionary:
	return {
		"chain_type": chain_type,
		"tier": tier,
		"col": grid_col,
		"row": grid_row,
	}
