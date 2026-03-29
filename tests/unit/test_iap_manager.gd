extends "res://addons/gut/test.gd"

## Tests for IAPManager — validates product definitions, purchase flow,
## and receipt persistence in stub mode (non-iOS).

var iap: Node = null


func before_each() -> void:
	iap = preload("res://scripts/game/iap_manager.gd").new()
	iap.name = "IAPManager"
	add_child(iap)
	# Wait for _ready to finish and stub products to load
	await get_tree().process_frame


func after_each() -> void:
	if iap:
		iap.queue_free()
		iap = null


# ── Product definitions ──────────────────────────────────────────────────────

func test_gem_packs_has_three_products() -> void:
	assert_eq(iap.GEM_PACKS.size(), 3, "Should define exactly 3 gem packs")


func test_product_ids_match_gem_packs() -> void:
	for product_id in iap.PRODUCT_IDS:
		assert_true(iap.GEM_PACKS.has(product_id), "PRODUCT_IDS entry '%s' should exist in GEM_PACKS" % product_id)


func test_gem_pack_100_definition() -> void:
	var pack: Dictionary = iap.GEM_PACKS["com.mergegrove.gems100"]
	assert_eq(pack["gems"], 100)
	assert_almost_eq(pack["price_usd"], 0.99, 0.001)


func test_gem_pack_600_definition() -> void:
	var pack: Dictionary = iap.GEM_PACKS["com.mergegrove.gems600"]
	assert_eq(pack["gems"], 600)
	assert_almost_eq(pack["price_usd"], 4.99, 0.001)


func test_gem_pack_1400_definition() -> void:
	var pack: Dictionary = iap.GEM_PACKS["com.mergegrove.gems1400"]
	assert_eq(pack["gems"], 1400)
	assert_almost_eq(pack["price_usd"], 9.99, 0.001)


# ── Stub mode product loading ────────────────────────────────────────────────

func test_stub_products_loaded_on_non_ios() -> void:
	assert_true(iap.is_ready, "Should be ready after _ready in stub mode")
	var products: Array[Dictionary] = iap.get_products()
	assert_eq(products.size(), 3, "Should have 3 stub products")


func test_stub_products_have_required_fields() -> void:
	var products: Array[Dictionary] = iap.get_products()
	for product in products:
		assert_true(product.has("product_id"), "Product should have product_id")
		assert_true(product.has("title"), "Product should have title")
		assert_true(product.has("price"), "Product should have price")
		assert_true(product.has("localized_price"), "Product should have localized_price")
		assert_true(product.has("gems"), "Product should have gems")


func test_stub_product_localized_prices_have_dollar_sign() -> void:
	var products: Array[Dictionary] = iap.get_products()
	for product in products:
		assert_string_starts_with(product["localized_price"], "$")


# ── Pack info lookup ─────────────────────────────────────────────────────────

func test_get_pack_info_valid_id() -> void:
	var info: Dictionary = iap.get_pack_info("com.mergegrove.gems100")
	assert_eq(info["gems"], 100)


func test_get_pack_info_invalid_id() -> void:
	var info: Dictionary = iap.get_pack_info("com.invalid.product")
	assert_true(info.is_empty(), "Should return empty dict for unknown product")


# ── Purchase flow (stub) ─────────────────────────────────────────────────────

func test_purchase_unknown_product_emits_failure() -> void:
	watch_signals(iap)
	iap.purchase("com.invalid.product")
	assert_signal_emitted(iap, "purchase_failed")


func test_purchase_duplicate_while_pending_emits_failure() -> void:
	watch_signals(iap)
	iap.purchase("com.mergegrove.gems100")
	# Second purchase while first is pending
	iap.purchase("com.mergegrove.gems600")
	assert_signal_emitted(iap, "purchase_failed")


func test_stub_purchase_completes_and_awards_gems() -> void:
	watch_signals(iap)
	iap.purchase("com.mergegrove.gems100")
	# Wait for stub timer (0.5s + buffer)
	await get_tree().create_timer(0.7).timeout
	assert_signal_emitted(iap, "purchase_completed")
	# Verify gem balance updated
	assert_eq(iap.get_gem_balance(), 100)


func test_stub_purchase_records_receipt() -> void:
	iap.purchase("com.mergegrove.gems600")
	await get_tree().create_timer(0.7).timeout
	assert_eq(iap.purchase_history.size(), 1, "Should record one purchase")
	assert_eq(iap.purchase_history[0]["product_id"], "com.mergegrove.gems600")
	assert_eq(iap.purchase_history[0]["gems"], 600)


# ── Restore (stub) ──────────────────────────────────────────────────────────

func test_restore_with_no_history_emits_empty() -> void:
	watch_signals(iap)
	iap.restore_purchases()
	assert_signal_emitted(iap, "restore_completed")


# ── Bonus calculation sanity ─────────────────────────────────────────────────

func test_larger_packs_have_bonus_value() -> void:
	# $4.99 at 100 gems/$ = 499 base, actual 600 = bonus
	var pack_600: Dictionary = iap.GEM_PACKS["com.mergegrove.gems600"]
	var base_600: float = pack_600["price_usd"] * 100.0
	assert_gt(pack_600["gems"], int(base_600), "600 gem pack should offer bonus over base rate")

	# $9.99 at 100 gems/$ = 999 base, actual 1400 = bonus
	var pack_1400: Dictionary = iap.GEM_PACKS["com.mergegrove.gems1400"]
	var base_1400: float = pack_1400["price_usd"] * 100.0
	assert_gt(pack_1400["gems"], int(base_1400), "1400 gem pack should offer bonus over base rate")
