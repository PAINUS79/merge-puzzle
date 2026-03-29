extends Node

## IAPManager — autoload singleton for in-app purchases.
## Wraps Godot's iOS InAppStore plugin with a platform-agnostic API.
## Falls back to a stub on non-iOS platforms for development/testing.

signal products_loaded(products: Array[Dictionary])
signal purchase_completed(product_id: String, gems_awarded: int)
signal purchase_failed(product_id: String, reason: String)
signal restore_completed(restored_ids: Array)
signal restore_failed(reason: String)

# ── Product definitions ──────────────────────────────────────────────────────
const GEM_PACKS: Dictionary = {
	"com.mergegrove.gems100": {"gems": 100, "price_usd": 0.99, "label": "Handful of Gems"},
	"com.mergegrove.gems600": {"gems": 600, "price_usd": 4.99, "label": "Pouch of Gems"},
	"com.mergegrove.gems1400": {"gems": 1400, "price_usd": 9.99, "label": "Chest of Gems"},
}

const PRODUCT_IDS: Array = [
	"com.mergegrove.gems100",
	"com.mergegrove.gems600",
	"com.mergegrove.gems1400",
]

# ── State ────────────────────────────────────────────────────────────────────
var _store: Object = null
var _is_ios: bool = false
var _products_cache: Array[Dictionary] = []
var _pending_purchase: String = ""
var is_ready: bool = false

# ── Purchase history (for restore + receipt tracking) ────────────────────────
const RECEIPT_PATH: String = "user://iap_receipts.json"
var purchase_history: Array[Dictionary] = []

# ── Internal gem balance (used when Economy autoload is not present) ─────────
var _internal_gems: int = 0
signal gems_changed(amount: int)


func _ready() -> void:
	_load_purchase_history()
	if Engine.has_singleton("InAppStore"):
		_store = Engine.get_singleton("InAppStore")
		_is_ios = true
		_request_products()
	else:
		push_warning("IAPManager: InAppStore not available — running in stub mode")
		_setup_stub_products()


# ── Public API ───────────────────────────────────────────────────────────────

func get_products() -> Array[Dictionary]:
	return _products_cache


func get_pack_info(product_id: String) -> Dictionary:
	if GEM_PACKS.has(product_id):
		return GEM_PACKS[product_id]
	return {}


func purchase(product_id: String) -> void:
	if _pending_purchase != "":
		purchase_failed.emit(product_id, "Another purchase is already in progress")
		return
	if not GEM_PACKS.has(product_id):
		purchase_failed.emit(product_id, "Unknown product ID")
		return

	_pending_purchase = product_id

	if _is_ios:
		var result: Dictionary = _store.purchase({"product_id": product_id})
		if result.get("status", -1) != OK:
			_pending_purchase = ""
			purchase_failed.emit(product_id, "Failed to initiate purchase")
	else:
		# Stub: simulate successful purchase after a short delay
		var timer := get_tree().create_timer(0.5)
		timer.timeout.connect(_on_stub_purchase_success)


func restore_purchases() -> void:
	if _is_ios:
		var result: Dictionary = _store.restore_purchases()
		if result.get("status", -1) != OK:
			restore_failed.emit("Failed to initiate restore")
	else:
		# Stub: simulate restore with purchase history
		var restored: Array = []
		for receipt in purchase_history:
			restored.append(receipt["product_id"])
		restore_completed.emit(restored)


# ── iOS StoreKit callbacks ───────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if not _is_ios or _store == null:
		return

	while _store.get_pending_event_count() > 0:
		var event: Dictionary = _store.pop_pending_event()
		_handle_store_event(event)


func _handle_store_event(event: Dictionary) -> void:
	var event_type: String = event.get("type", "")

	match event_type:
		"product_info":
			_on_products_received(event)
		"purchase":
			_on_purchase_result(event)
		"restore":
			_on_restore_result(event)
		_:
			push_warning("IAPManager: Unhandled store event type: %s" % event_type)


func _on_products_received(event: Dictionary) -> void:
	_products_cache.clear()
	var ids: PackedStringArray = event.get("ids", PackedStringArray())
	var titles: PackedStringArray = event.get("titles", PackedStringArray())
	var prices: PackedStringArray = event.get("prices", PackedStringArray())
	var localized_prices: PackedStringArray = event.get("localized_prices", PackedStringArray())

	for i in range(ids.size()):
		var product_id: String = ids[i]
		var pack: Dictionary = GEM_PACKS.get(product_id, {})
		_products_cache.append({
			"product_id": product_id,
			"title": titles[i] if i < titles.size() else pack.get("label", product_id),
			"price": prices[i] if i < prices.size() else str(pack.get("price_usd", "?")),
			"localized_price": localized_prices[i] if i < localized_prices.size() else ("$" + str(pack.get("price_usd", "?"))),
			"gems": pack.get("gems", 0),
		})

	is_ready = true
	products_loaded.emit(_products_cache)


func _on_purchase_result(event: Dictionary) -> void:
	var result: String = event.get("result", "error")
	var product_id: String = _pending_purchase

	if result == "ok":
		var pack: Dictionary = GEM_PACKS.get(product_id, {})
		var gem_amount: int = pack.get("gems", 0)
		_award_gems(gem_amount)
		_record_purchase(product_id, gem_amount)
		_track("iap_purchase_completed", {
			"product_id": product_id,
			"gems": gem_amount,
			"price_usd": pack.get("price_usd", 0),
		})
		_pending_purchase = ""
		purchase_completed.emit(product_id, gem_amount)
	elif result == "cancelled":
		_track("iap_purchase_cancelled", {"product_id": product_id})
		_pending_purchase = ""
		purchase_failed.emit(product_id, "Purchase cancelled")
	else:
		var error_msg: String = event.get("message", "Unknown error")
		_track("iap_purchase_failed", {"product_id": product_id, "error": error_msg})
		_pending_purchase = ""
		purchase_failed.emit(product_id, error_msg)


func _on_restore_result(event: Dictionary) -> void:
	var result: String = event.get("result", "error")

	if result == "ok":
		var product_id: String = event.get("product_id", "")
		if GEM_PACKS.has(product_id):
			# For consumables, we just acknowledge the restore
			# Gems were already awarded on original purchase
			pass
		restore_completed.emit([product_id])
	elif result == "completed":
		# All restores finished
		restore_completed.emit([])
	else:
		restore_failed.emit(event.get("message", "Restore failed"))


# ── Stub mode (non-iOS) ─────────────────────────────────────────────────────

func _setup_stub_products() -> void:
	_products_cache.clear()
	for product_id in PRODUCT_IDS:
		var pack: Dictionary = GEM_PACKS[product_id]
		_products_cache.append({
			"product_id": product_id,
			"title": pack["label"],
			"price": str(pack["price_usd"]),
			"localized_price": "$%s" % str(pack["price_usd"]),
			"gems": pack["gems"],
		})
	is_ready = true
	products_loaded.emit(_products_cache)


func _on_stub_purchase_success() -> void:
	var product_id: String = _pending_purchase
	var pack: Dictionary = GEM_PACKS.get(product_id, {})
	var gem_amount: int = pack.get("gems", 0)
	_award_gems(gem_amount)
	_record_purchase(product_id, gem_amount)
	_track("iap_purchase_completed", {
		"product_id": product_id,
		"gems": gem_amount,
		"price_usd": pack.get("price_usd", 0),
		"stub": true,
	})
	_pending_purchase = ""
	purchase_completed.emit(product_id, gem_amount)


# ── Product request ──────────────────────────────────────────────────────────

func _request_products() -> void:
	if _store == null:
		return
	var result: Dictionary = _store.request_product_info({"product_ids": PRODUCT_IDS})
	if result.get("status", -1) != OK:
		push_warning("IAPManager: Failed to request product info")
		_setup_stub_products()


# ── Purchase history persistence ─────────────────────────────────────────────

func _record_purchase(product_id: String, gems: int) -> void:
	purchase_history.append({
		"product_id": product_id,
		"gems": gems,
		"timestamp": Time.get_unix_time_from_system(),
	})
	_save_purchase_history()


func _save_purchase_history() -> void:
	var file := FileAccess.open(RECEIPT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"purchases": purchase_history}))
		file.close()


func _load_purchase_history() -> void:
	if not FileAccess.file_exists(RECEIPT_PATH):
		return
	var file := FileAccess.open(RECEIPT_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	if json.data is Dictionary:
		var purchases = json.data.get("purchases", [])
		if purchases is Array:
			for p in purchases:
				if p is Dictionary:
					purchase_history.append(p)


# ── Safe singleton helpers ───────────────────────────────────────────────────

func _award_gems(amount: int) -> void:
	var economy = _get_autoload("Economy")
	if economy and economy.has_method("add_gems"):
		economy.add_gems(amount)
	else:
		_internal_gems += amount
		gems_changed.emit(_internal_gems)


func get_gem_balance() -> int:
	var economy = _get_autoload("Economy")
	if economy and "gems" in economy:
		return economy.gems
	return _internal_gems


func _track(event_name: String, properties: Dictionary = {}) -> void:
	var analytics = _get_autoload("AnalyticsManager")
	if analytics and analytics.has_method("track"):
		analytics.track(event_name, properties)


func _get_autoload(singleton_name: String) -> Node:
	if not get_tree() or not get_tree().root:
		return null
	return get_tree().root.get_node_or_null("/root/" + singleton_name)
