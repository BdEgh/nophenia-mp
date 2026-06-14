extends PanelContainer

@onready var timer: Timer = $Timer

var pictures: Array[Node]
var current: Control

func _ready() -> void:
	pictures = find_children("Picture*", "Control", false)
	for p: Control in pictures: p.modulate.a = 0.0
	_show_picture()

func _on_timer_timeout() -> void:
	_show_picture()

func _show_picture() -> void:
	var old := current
	current = pictures.filter(func(x): return x != old).pick_random()
	current.z_index = 2
	await create_tween().tween_property(current, "modulate:a", 1.0, 1.0).from(0.0).finished
	if old:
		old.z_index = 0
		old.modulate.a = 0.0
	current.z_index = 1
