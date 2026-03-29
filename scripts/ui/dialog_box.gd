extends PanelContainer

signal dialog_finished()

@onready var portrait: TextureRect = $HBox/Portrait
@onready var name_label: Label = $HBox/VBox/NameLabel
@onready var text_label: RichTextLabel = $HBox/VBox/TextLabel
@onready var next_button: Button = $HBox/VBox/NextButton

var _dialog_queue: Array = []
var _current_index: int = 0
var _is_showing: bool = false

const STORY_BEATS: Dictionary = {
	"arrival": [
		{"speaker": "Hazel", "portrait": "res://assets/portraits/hazel.svg",
		 "text": "Welcome, dear one. If you're reading this, the farm is yours now. I know it looks rough, but there's still magic here — you just have to coax it out."},
		{"speaker": "Bramble", "portrait": "res://assets/portraits/bramble.svg",
		 "text": "Oi! You must be the new owner! I'm Bramble — been looking after this place since Hazel left. Well... 'looking after' might be generous."},
	],
	"first_merge": [
		{"speaker": "Bramble", "portrait": "res://assets/portraits/bramble.svg",
		 "text": "See those items on the board? Tap a Seed Pouch to get started, then drag matching items together. That's the magic of merging!"},
		{"speaker": "Bramble", "portrait": "res://assets/portraits/bramble.svg",
		 "text": "Keep merging to create better and better items. You'll need the best ones to restore the garden!"},
	],
	"garden_restored": [
		{"speaker": "Hazel", "portrait": "res://assets/portraits/hazel.svg",
		 "text": "Oh, you can feel it, can't you? The garden remembers what it was. Every plant you nurture brings back a little of the old magic."},
		{"speaker": "Bramble", "portrait": "res://assets/portraits/bramble.svg",
		 "text": "Would you look at that! The garden's coming alive again! Hazel would be so proud."},
	],
	"cliffhanger": [
		{"speaker": "Bramble", "portrait": "res://assets/portraits/bramble.svg",
		 "text": "You know... it wasn't just the plants that left when the magic faded. The others — the forest folk — they went too."},
		{"speaker": "Bramble", "portrait": "res://assets/portraits/bramble.svg",
		 "text": "But if the garden's waking up... maybe they'll come back. Maybe. There's more farm to restore beyond the garden, you know."},
	],
}

func _ready() -> void:
	visible = false
	next_button.pressed.connect(_advance_dialog)

func show_story_beat(beat_key: String) -> void:
	if not STORY_BEATS.has(beat_key):
		return
	_dialog_queue = STORY_BEATS[beat_key]
	_current_index = 0
	_is_showing = true
	visible = true
	_show_current_line()

func show_custom_dialog(lines: Array) -> void:
	_dialog_queue = lines
	_current_index = 0
	_is_showing = true
	visible = true
	_show_current_line()

func _show_current_line() -> void:
	if _current_index >= _dialog_queue.size():
		_close_dialog()
		return
	var line: Dictionary = _dialog_queue[_current_index]
	if name_label:
		name_label.text = line.get("speaker", "")
	if text_label:
		text_label.text = line.get("text", "")
	if portrait:
		var tex_path: String = line.get("portrait", "")
		if tex_path != "":
			var tex = load(tex_path)
			if tex:
				portrait.texture = tex
				portrait.visible = true
		else:
			portrait.visible = false
	if next_button:
		if _current_index >= _dialog_queue.size() - 1:
			next_button.text = "Close"
		else:
			next_button.text = "Next"

func _advance_dialog() -> void:
	_current_index += 1
	_show_current_line()

func _close_dialog() -> void:
	_is_showing = false
	visible = false
	_dialog_queue = []
	_current_index = 0
	dialog_finished.emit()

func is_showing() -> bool:
	return _is_showing
