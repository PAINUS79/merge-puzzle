extends Node

enum ChainType { CROPS, TOOLS, CREATURES }

const CHAINS: Dictionary = {
	ChainType.CROPS: [
		{ "name": "Seed", "sprite": "res://assets/items/crops_t1.svg", "sell_value": 1 },
		{ "name": "Sprout", "sprite": "res://assets/items/crops_t2.svg", "sell_value": 2 },
		{ "name": "Bush", "sprite": "res://assets/items/crops_t3.svg", "sell_value": 4 },
		{ "name": "Harvest Basket", "sprite": "res://assets/items/crops_t4.svg", "sell_value": 8 },
		{ "name": "Golden Harvest", "sprite": "res://assets/items/crops_t5.svg", "sell_value": 16 },
	],
	ChainType.TOOLS: [
		{ "name": "Twig", "sprite": "res://assets/items/tools_t1.svg", "sell_value": 1 },
		{ "name": "Stick", "sprite": "res://assets/items/tools_t2.svg", "sell_value": 2 },
		{ "name": "Plank", "sprite": "res://assets/items/tools_t3.svg", "sell_value": 4 },
		{ "name": "Fence Post", "sprite": "res://assets/items/tools_t4.svg", "sell_value": 8 },
		{ "name": "Garden Fence", "sprite": "res://assets/items/tools_t5.svg", "sell_value": 16 },
	],
	ChainType.CREATURES: [
		{ "name": "Egg", "sprite": "res://assets/items/creatures_t1.svg", "sell_value": 1 },
		{ "name": "Chick", "sprite": "res://assets/items/creatures_t2.svg", "sell_value": 2 },
		{ "name": "Hen", "sprite": "res://assets/items/creatures_t3.svg", "sell_value": 4 },
		{ "name": "Rooster", "sprite": "res://assets/items/creatures_t4.svg", "sell_value": 8 },
		{ "name": "Phoenix Chicken", "sprite": "res://assets/items/creatures_t5.svg", "sell_value": 16 },
	],
}

const MAX_TIER: int = 4  # 0-indexed, so tier 5 = index 4

const POUCH_COOLDOWN: float = 8.0
const POUCH_MAX_CHARGES: int = 5
const POUCH_RECHARGE_TIME: float = 90.0

func get_item_name(chain_type: int, tier: int) -> String:
	return CHAINS[chain_type][tier]["name"]

func get_item_sprite_path(chain_type: int, tier: int) -> String:
	return CHAINS[chain_type][tier]["sprite"]

func get_sell_value(chain_type: int, tier: int) -> int:
	return CHAINS[chain_type][tier]["sell_value"]

func can_merge(chain_type: int, tier: int) -> bool:
	return tier < MAX_TIER

func get_chain_name(chain_type: int) -> String:
	match chain_type:
		ChainType.CROPS: return "Crops"
		ChainType.TOOLS: return "Tools"
		ChainType.CREATURES: return "Creatures"
		_: return "Unknown"
