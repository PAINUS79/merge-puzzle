extends Control

@onready var energy_bar: ProgressBar = $TopBar/EnergyBar
@onready var energy_label: Label = $TopBar/EnergyLabel
@onready var coin_label: Label = $TopBar/CoinLabel
@onready var gem_label: Label = $TopBar/GemLabel
@onready var task_panel: VBoxContainer = $TaskPanel
@onready var task_name_label: Label = $TaskPanel/TaskName
@onready var task_desc_label: Label = $TaskPanel/TaskDesc
@onready var task_progress_label: Label = $TaskPanel/TaskProgress

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
		if task_name_label:
			task_name_label.text = "Zone 1 Complete!"
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
		var progress: int = TaskManager.get_task_progress(TaskManager.current_task_index)
		var required: int = task["required_count"]
		task_progress_label.text = str(progress) + "/" + str(required)
