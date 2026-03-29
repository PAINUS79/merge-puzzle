class_name SeedPouch
extends PanelContainer

signal pouch_tapped(chain_type: int)

@export var chain_type: int = 0

var charges: int = ItemData.POUCH_MAX_CHARGES
var cooldown_timer: float = 0.0
var is_on_cooldown: bool = false
var _recharge_timer: float = 0.0

@onready var icon: TextureRect = $VBox/Icon
@onready var charge_label: Label = $VBox/ChargeLabel
@onready var cooldown_bar: ProgressBar = $VBox/CooldownBar
@onready var tap_button: Button = $VBox/TapButton

func _ready() -> void:
	_update_display()
	tap_button.pressed.connect(_on_tap)
	cooldown_bar.visible = false

func _process(delta: float) -> void:
	if is_on_cooldown:
		cooldown_timer -= delta
		cooldown_bar.value = (cooldown_timer / ItemData.POUCH_COOLDOWN) * 100.0
		if cooldown_timer <= 0.0:
			is_on_cooldown = false
			cooldown_bar.visible = false
	# Recharge charges over time
	if charges < ItemData.POUCH_MAX_CHARGES:
		_recharge_timer += delta
		if _recharge_timer >= ItemData.POUCH_RECHARGE_TIME:
			_recharge_timer -= ItemData.POUCH_RECHARGE_TIME
			charges = mini(charges + 1, ItemData.POUCH_MAX_CHARGES)
			_update_display()

func _on_tap() -> void:
	if is_on_cooldown or charges <= 0:
		return
	charges -= 1
	is_on_cooldown = true
	cooldown_timer = ItemData.POUCH_COOLDOWN
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
