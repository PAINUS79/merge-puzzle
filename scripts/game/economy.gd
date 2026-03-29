extends Node

signal coins_changed(amount: int)
signal gems_changed(amount: int)

var coins: int = 0
var gems: int = 0

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

func add_gems(amount: int) -> void:
	gems += amount
	gems_changed.emit(gems)

func spend_gems(amount: int) -> bool:
	if gems < amount:
		return false
	gems -= amount
	gems_changed.emit(gems)
	return true

func save_data() -> Dictionary:
	return {
		"coins": coins,
		"gems": gems,
	}

func load_data(data: Dictionary) -> void:
	coins = data.get("coins", 0)
	gems = data.get("gems", 0)
	coins_changed.emit(coins)
	gems_changed.emit(gems)
