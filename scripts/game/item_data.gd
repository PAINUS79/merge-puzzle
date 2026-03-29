extends Node

enum ChainType { CROPS, TOOLS, CREATURES, MUSHROOMS, CRYSTALS }

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
	ChainType.MUSHROOMS: [
		{ "name": "Spore", "sprite": "res://assets/zone2/chains/mushroom_t1.svg", "sell_value": 1 },
		{ "name": "Cap Sprout", "sprite": "res://assets/zone2/chains/mushroom_t2.svg", "sell_value": 3 },
		{ "name": "Button Mushroom", "sprite": "res://assets/zone2/chains/mushroom_t3.svg", "sell_value": 6 },
		{ "name": "Shiitake Cluster", "sprite": "res://assets/zone2/chains/mushroom_t4.svg", "sell_value": 12 },
		{ "name": "Glowcap", "sprite": "res://assets/zone2/chains/mushroom_t5.svg", "sell_value": 24 },
	],
	ChainType.CRYSTALS: [
		{ "name": "Shard", "sprite": "res://assets/zone2/chains/crystal_t1.svg", "sell_value": 1 },
		{ "name": "Rough Gem", "sprite": "res://assets/zone2/chains/crystal_t2.svg", "sell_value": 3 },
		{ "name": "Polished Stone", "sprite": "res://assets/zone2/chains/crystal_t3.svg", "sell_value": 6 },
		{ "name": "Prism", "sprite": "res://assets/zone2/chains/crystal_t4.svg", "sell_value": 12 },
		{ "name": "Star Crystal", "sprite": "res://assets/zone2/chains/crystal_t5.svg", "sell_value": 24 },
	],
}

const MAX_TIER: int = 4  # 0-indexed, so tier 5 = index 4

const POUCH_COOLDOWN: float = 8.0
const POUCH_MAX_CHARGES: int = 5
const POUCH_RECHARGE_TIME: float = 90.0

# Zone 2 pouch overrides (harder resource pressure)
const ZONE2_POUCH_COOLDOWN: float = 10.0
const ZONE2_POUCH_MAX_CHARGES: int = 4
const ZONE2_POUCH_RECHARGE_TIME: float = 100.0

# Zone-to-chain mapping
const ZONE_CHAINS: Dictionary = {
	1: [ChainType.CROPS, ChainType.TOOLS, ChainType.CREATURES],
	2: [ChainType.CROPS, ChainType.TOOLS, ChainType.CREATURES, ChainType.MUSHROOMS, ChainType.CRYSTALS],
}

# Chains introduced in each zone (for pouch config)
const ZONE_NEW_CHAINS: Dictionary = {
	1: [ChainType.CROPS, ChainType.TOOLS, ChainType.CREATURES],
	2: [ChainType.MUSHROOMS, ChainType.CRYSTALS],
}

func get_chains_for_zone(zone: int) -> Array:
	return ZONE_CHAINS.get(zone, ZONE_CHAINS[1])

func is_zone2_chain(chain_type: int) -> bool:
	return chain_type == ChainType.MUSHROOMS or chain_type == ChainType.CRYSTALS

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
		ChainType.MUSHROOMS: return "Spores"
		ChainType.CRYSTALS: return "Crystals"
		_: return "Unknown"
