extends Control

## Shop UI — displays gem pack cards and handles purchase flow.

signal shop_closed

@onready var pack_container: VBoxContainer = $Panel/VBox/ScrollContainer/PackContainer
@onready var close_button: Button = $Panel/VBox/TopBar/CloseButton
@onready var restore_button: Button = $Panel/VBox/RestoreButton
@onready var gem_balance_label: Label = $Panel/VBox/TopBar/GemBalance
@onready var status_label: Label = $Panel/VBox/StatusLabel

var _pack_buttons: Dictionary = {}


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	restore_button.pressed.connect(_on_restore_pressed)
	IAPManager.purchase_completed.connect(_on_purchase_completed)
	IAPManager.purchase_failed.connect(_on_purchase_failed)
	IAPManager.restore_completed.connect(_on_restore_completed)
	IAPManager.restore_failed.connect(_on_restore_failed)

	# Connect to gem balance updates from whichever source is available
	var economy = get_tree().root.get_node_or_null("/root/Economy")
	if economy and economy.has_signal("gems_changed"):
		economy.gems_changed.connect(_on_gems_changed)
	else:
		IAPManager.gems_changed.connect(_on_gems_changed)

	_update_gem_balance()
	_build_pack_cards()
	IAPManager._track("shop_opened")


func _update_gem_balance() -> void:
	if gem_balance_label:
		gem_balance_label.text = str(IAPManager.get_gem_balance()) + " gems"


func _build_pack_cards() -> void:
	for child in pack_container.get_children():
		child.queue_free()
	_pack_buttons.clear()

	var products: Array[Dictionary] = IAPManager.get_products()
	if products.is_empty():
		for product_id in IAPManager.PRODUCT_IDS:
			var pack: Dictionary = IAPManager.GEM_PACKS[product_id]
			_create_pack_card(product_id, pack["label"], "$" + str(pack["price_usd"]), pack["gems"])
	else:
		for product in products:
			_create_pack_card(
				product["product_id"],
				product["title"],
				product["localized_price"],
				product["gems"]
			)


func _create_pack_card(product_id: String, title: String, price: String, gems: int) -> void:
	var card := PanelContainer.new()
	card.name = "Card_" + product_id.get_file()

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.22, 0.18, 0.32, 0.95)
	card_style.corner_radius_top_left = 12
	card_style.corner_radius_top_right = 12
	card_style.corner_radius_bottom_left = 12
	card_style.corner_radius_bottom_right = 12
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.55, 0.45, 0.85, 0.6)
	card_style.content_margin_left = 16.0
	card_style.content_margin_top = 12.0
	card_style.content_margin_right = 16.0
	card_style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(1, 0.95, 0.7, 1))
	info_vbox.add_child(title_label)

	var gems_label := Label.new()
	gems_label.text = str(gems) + " Gems"
	gems_label.add_theme_font_size_override("font_size", 20)
	gems_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1, 1))
	info_vbox.add_child(gems_label)

	# Bonus indicator for larger packs
	var pack_info: Dictionary = IAPManager.GEM_PACKS.get(product_id, {})
	var base_gems: float = pack_info.get("price_usd", 1.0) * 100.0
	var actual_gems: int = pack_info.get("gems", gems)
	if actual_gems > int(base_gems) + 5:
		var bonus_pct: int = int((float(actual_gems) / base_gems - 1.0) * 100.0)
		var bonus_label := Label.new()
		bonus_label.text = "+" + str(bonus_pct) + "% bonus!"
		bonus_label.add_theme_font_size_override("font_size", 10)
		bonus_label.add_theme_color_override("font_color", Color(0.4, 1, 0.5, 1))
		info_vbox.add_child(bonus_label)

	hbox.add_child(info_vbox)

	# Buy button
	var buy_button := Button.new()
	buy_button.text = price
	buy_button.custom_minimum_size = Vector2(80, 44)
	buy_button.add_theme_font_size_override("font_size", 14)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.35, 0.65, 0.35, 1)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.content_margin_left = 12.0
	btn_style.content_margin_top = 8.0
	btn_style.content_margin_right = 12.0
	btn_style.content_margin_bottom = 8.0
	buy_button.add_theme_stylebox_override("normal", btn_style)

	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.4, 0.75, 0.4, 1)
	btn_hover.corner_radius_top_left = 8
	btn_hover.corner_radius_top_right = 8
	btn_hover.corner_radius_bottom_left = 8
	btn_hover.corner_radius_bottom_right = 8
	btn_hover.content_margin_left = 12.0
	btn_hover.content_margin_top = 8.0
	btn_hover.content_margin_right = 12.0
	btn_hover.content_margin_bottom = 8.0
	buy_button.add_theme_stylebox_override("hover", btn_hover)

	buy_button.pressed.connect(_on_buy_pressed.bind(product_id))
	hbox.add_child(buy_button)

	card.add_child(hbox)
	pack_container.add_child(card)
	_pack_buttons[product_id] = buy_button


func _on_buy_pressed(product_id: String) -> void:
	_set_buttons_disabled(true)
	_set_status("Processing purchase...")
	IAPManager.purchase(product_id)


func _on_purchase_completed(_product_id: String, gems_awarded: int) -> void:
	_set_status("Added " + str(gems_awarded) + " gems!")
	_set_buttons_disabled(false)
	_update_gem_balance()
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(_clear_status)


func _on_purchase_failed(_product_id: String, reason: String) -> void:
	_set_status(reason)
	_set_buttons_disabled(false)
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(_clear_status)


func _on_restore_pressed() -> void:
	_set_buttons_disabled(true)
	_set_status("Restoring purchases...")
	IAPManager.restore_purchases()


func _on_restore_completed(restored_ids: Array) -> void:
	if restored_ids.is_empty():
		_set_status("No purchases to restore")
	else:
		_set_status("Restore complete!")
	_set_buttons_disabled(false)
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(_clear_status)


func _on_restore_failed(reason: String) -> void:
	_set_status("Restore failed: " + reason)
	_set_buttons_disabled(false)
	var timer := get_tree().create_timer(3.0)
	timer.timeout.connect(_clear_status)


func _on_gems_changed(_amount: int) -> void:
	_update_gem_balance()


func _on_close_pressed() -> void:
	IAPManager._track("shop_closed")
	shop_closed.emit()


func _set_buttons_disabled(disabled: bool) -> void:
	for button: Button in _pack_buttons.values():
		button.disabled = disabled
	restore_button.disabled = disabled


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text
		status_label.visible = true


func _clear_status() -> void:
	if status_label:
		status_label.text = ""
		status_label.visible = false
