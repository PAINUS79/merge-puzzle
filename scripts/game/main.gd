extends Node2D
## Main scene controller for Merge Puzzle.
## Manages game state and scene transitions.

@onready var hud: Control = $UI/HUD
@onready var shop: Control = $UI/Shop
@onready var shop_button: Button = $UI/HUD/ShopButton

func _ready() -> void:
	print("Merge Puzzle - Main scene loaded")
	shop_button.pressed.connect(_on_shop_button_pressed)
	shop.shop_closed.connect(_on_shop_closed)
	shop.visible = false
	_initialize_game()

func _initialize_game() -> void:
	pass

func _on_shop_button_pressed() -> void:
	shop.visible = true

func _on_shop_closed() -> void:
	shop.visible = false
