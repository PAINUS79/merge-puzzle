extends Node

signal energy_changed(current: int, maximum: int)
signal energy_depleted()
signal energy_recharged()

const MAX_ENERGY: int = 50
const RECHARGE_TIME: float = 120.0  # 2 minutes per energy

var current_energy: int = MAX_ENERGY
var _recharge_timer: float = 0.0
var _last_energy_time: float = 0.0

func _ready() -> void:
	_last_energy_time = Time.get_unix_time_from_system()

func _process(delta: float) -> void:
	if current_energy < MAX_ENERGY:
		_recharge_timer += delta
		if _recharge_timer >= RECHARGE_TIME:
			_recharge_timer -= RECHARGE_TIME
			add_energy(1)
			energy_recharged.emit()

func use_energy(amount: int = 1) -> bool:
	if current_energy < amount:
		energy_depleted.emit()
		return false
	current_energy -= amount
	_last_energy_time = Time.get_unix_time_from_system()
	energy_changed.emit(current_energy, MAX_ENERGY)
	return true

func add_energy(amount: int) -> void:
	current_energy = mini(current_energy + amount, MAX_ENERGY)
	energy_changed.emit(current_energy, MAX_ENERGY)

func refill_energy() -> void:
	current_energy = MAX_ENERGY
	_recharge_timer = 0.0
	energy_changed.emit(current_energy, MAX_ENERGY)

func get_time_to_next() -> float:
	if current_energy >= MAX_ENERGY:
		return 0.0
	return RECHARGE_TIME - _recharge_timer

func save_data() -> Dictionary:
	return {
		"current_energy": current_energy,
		"last_energy_time": Time.get_unix_time_from_system(),
		"recharge_timer": _recharge_timer,
	}

func load_data(data: Dictionary) -> void:
	current_energy = data.get("current_energy", MAX_ENERGY)
	_recharge_timer = data.get("recharge_timer", 0.0)
	var saved_time: float = data.get("last_energy_time", Time.get_unix_time_from_system())
	var elapsed: float = Time.get_unix_time_from_system() - saved_time
	var recovered: int = int(elapsed / RECHARGE_TIME)
	if recovered > 0:
		add_energy(recovered)
		_recharge_timer = fmod(elapsed, RECHARGE_TIME)
	energy_changed.emit(current_energy, MAX_ENERGY)
