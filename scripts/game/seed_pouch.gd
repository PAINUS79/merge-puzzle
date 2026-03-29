class_name SeedPouch
extends PanelContainer

signal pouch_tapped(chain_type: int)

@export var chain_type: int = 0

var charges: int = ItemData.POUCH_MAX_CHARGES
var cooldown_timer: float = 0.0
var is_on_cooldown: bool = false
var _recharge_timer: float = 0.0
var _cooldown_duration: float = ItemData.POUCH_COOLDOWN
var _recharge_duration: float = ItemData.POUCH_RECHARGE_TIME

@onready var icon: TextureRect = $VBox/Icon
@onready var charge_label: Label = $VBox/ChargeLabel
@onready var cooldown_bar: ProgressBar = $VBox/CooldownBar
@onready var tap_button: Button = $VBox/TapButton

func _ready() -> void:
	_load_pouch_icon()
	_update_display()
	tap_button.pressed.connect(_on_tap)
	cooldown_bar.visible = false

func _load_pouch_icon() -> void:
	var sprite_path: String = ItemData.get_item_sprite_path(chain_type, 0)
	if sprite_path != "" and icon:
		var tex = load(sprite_path)
		if tex:
			icon.texture = tex

func _process(delta: float) -> void:
	if is_on_cooldown:
		cooldown_timer -= delta
		cooldown_bar.value = (cooldown_timer / _cooldown_duration) * 100.0
		if cooldown_timer <= 0.0:
			is_on_cooldown = false
			cooldown_bar.visible = false
	# Recharge charges over time
	var max_charges: int = ItemData.ZONE2_POUCH_MAX_CHARGES if ItemData.is_zone2_chain(chain_type) else ItemData.POUCH_MAX_CHARGES
	if charges < max_charges:
		_recharge_timer += delta
		if _recharge_timer >= _recharge_duration:
			_recharge_timer -= _recharge_duration
			charges = mini(charges + 1, max_charges)
			_update_display()

func _on_tap() -> void:
	if is_on_cooldown or charges <= 0:
		return
	charges -= 1
	is_on_cooldown = true
	_cooldown_duration = ItemData.ZONE2_POUCH_COOLDOWN if ItemData.is_zone2_chain(chain_type) else ItemData.POUCH_COOLDOWN
	_recharge_duration = ItemData.ZONE2_POUCH_RECHARGE_TIME if ItemData.is_zone2_chain(chain_type) else ItemData.POUCH_RECHARGE_TIME
	cooldown_timer = _cooldown_duration
	cooldown_bar.visible = true
	cooldown_bar.value = 100.0
	_update_display()
	pouch_tapped.emit(chain_type)

func _update_display() -> void:
	if charge_label:
		charge_label.text = str(charges)
	if tap_button:
		tap_button.disabled = charges <= 0

func get_chain_name() -> String:
	return ItemData.get_chain_name(chain_type)

func save_data() -> Dictionary:
	return {
		"chain_type": chain_type,
		"charges": charges,
		"cooldown_timer": cooldown_timer,
		"is_on_cooldown": is_on_cooldown,
		"recharge_timer": _recharge_timer,
	}

func load_data(data: Dictionary) -> void:
	charges = data.get("charges", ItemData.POUCH_MAX_CHARGES)
	cooldown_timer = data.get("cooldown_timer", 0.0)
	is_on_cooldown = data.get("is_on_cooldown", false)
	_recharge_timer = data.get("recharge_timer", 0.0)
	cooldown_bar.visible = is_on_cooldown
	_update_display()
