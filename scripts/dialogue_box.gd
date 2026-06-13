extends Control
# Bottom-of-screen dialogue box with typewriter text and a speaker name.
# Call start(speaker, lines); advances on the "interact" input; emits finished.

signal finished
signal state_changed(active: bool)

@onready var panel: Panel = $Panel
@onready var name_label: Label = $Panel/VBox/NameLabel
@onready var body_label: RichTextLabel = $Panel/VBox/BodyLabel
@onready var hint_label: Label = $Panel/VBox/HintLabel

@export var chars_per_second: float = 45.0

var lines: Array = []
var index: int = 0
var active: bool = false
var typing: bool = false
var _elapsed: float = 0.0

func _ready() -> void:
	hide_box()

func is_active() -> bool:
	return active

func show_box() -> void:
	visible = true

func hide_box() -> void:
	visible = false
	active = false
	state_changed.emit(false)

func start(speaker: String, dialogue_lines: Array) -> void:
	lines = dialogue_lines.duplicate()
	index = 0
	active = true
	state_changed.emit(true)
	show_box()
	_show_line(speaker)

func _show_line(speaker: String) -> void:
	name_label.text = speaker
	body_label.visible_characters = 0
	body_label.text = lines[index]
	hint_label.visible = false
	typing = true
	_elapsed = 0.0

func _process(delta: float) -> void:
	if not typing:
		return
	_elapsed += delta
	var target = floor(_elapsed * chars_per_second)
	if target != body_label.visible_characters:
		body_label.visible_characters = int(target)
	if body_label.visible_characters >= body_label.get_total_character_count():
		typing = false
		hint_label.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not active or not event.is_action_pressed("interact"):
		return
	get_viewport().set_input_as_handled()
	advance()

func advance() -> void:
	if typing:
		# Fast-forward current line.
		body_label.visible_characters = body_label.get_total_character_count()
		typing = false
		hint_label.visible = true
		return
	index += 1
	if index >= lines.size():
		hide_box()
		finished.emit()
	else:
		_show_line(name_label.text)
