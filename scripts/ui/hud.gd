extends Control

@onready var energy_bar: ProgressBar = $TopBar/HBox/EnergyBar
@onready var energy_label: Label = $TopBar/HBox/EnergyLabel
@onready var coin_label: Label = $TopBar/HBox/CoinLabel
@onready var gem_label: Label = $TopBar/HBox/GemLabel
@onready var task_panel: PanelContainer = $TaskPanel
@onready var task_name_label: Label = $TaskPanel/TaskVBox/TaskName
@onready var task_desc_label: Label = $TaskPanel/TaskVBox/TaskDesc
@onready var task_progress_label: Label = $TaskPanel/TaskVBox/TaskProgress

func _ready() -> void:
	EnergyManager.energy_changed.connect(_on_energy_changed)
	Economy.coins_changed.connect(_on_coins_changed)
	Economy.gems_changed.connect(_on_gems_changed)
	TaskManager.task_updated.connect(_on_task_updated)
	TaskManager.task_completed.connect(_on_task_completed)
	_update_all()

func _update_all() -> void:
	_on_energy_changed(EnergyManager.current_energy, EnergyManager.MAX_ENERGY)
	_on_coins_changed(Economy.coins)
	_on_gems_changed(Economy.gems)
	_update_task_display()

func _on_energy_changed(current: int, maximum: int) -> void:
	if energy_bar:
		energy_bar.max_value = maximum
		energy_bar.value = current
	if energy_label:
		energy_label.text = str(current) + "/" + str(maximum)

func _on_coins_changed(amount: int) -> void:
	if coin_label:
		coin_label.text = str(amount)

func _on_gems_changed(amount: int) -> void:
	if gem_label:
		gem_label.text = str(amount)

func _on_task_updated(_task_index: int) -> void:
	_update_task_display()

func _on_task_completed(_task_index: int) -> void:
	_update_task_display()

func _update_task_display() -> void:
	var task: Dictionary = TaskManager.get_current_task()
	if task.is_empty():
		var zone_name: String = "Zone " + str(TaskManager.current_zone)
		if task_name_label:
			task_name_label.text = zone_name + " Complete!"
		if task_desc_label:
			task_desc_label.text = "All tasks finished."
		if task_progress_label:
			task_progress_label.text = ""
		return
	if task_name_label:
		task_name_label.text = task["name"]
	if task_desc_label:
		task_desc_label.text = task["description"]
	if task_progress_label:
		# Build progress string from all requirements
		var requirements: Array = task["requirements"]
		var parts: Array = []
		for req_idx in range(requirements.size()):
			var req: Dictionary = requirements[req_idx]
			var progress: int = TaskManager.get_requirement_progress(TaskManager.current_task_index, req_idx)
			var needed: int = req["count"]
			var item_name: String = ItemData.get_item_name(req["chain"], req["tier"])
			parts.append(str(progress) + "/" + str(needed) + " " + item_name)
		task_progress_label.text = " | ".join(parts)
