@tool
extends MarginContainer

enum Type { All, Accessories, Body, Head, Paws }

@export var cus: Control
@export var item: MeshInstance3D
@export var preview: MeshInstance3D
@export var iname: String
@export var itype: Type

@onready var button: Button = %Button
@onready var item_name: RichTextLabel = %Item_Name
@onready var item_class: RichTextLabel = %Item_Class
@onready var item_preview: Node3D = %item_preview

var do_save := false

func _ready() -> void:
    button.pivot_offset_ratio = Vector2(0.5, 0.5)
    item_name.text = iname
    item_class.text = Type.keys()[itype]
    item_preview.item = preview if preview else item

func _on_button_toggled(toggled_on: bool) -> void:
    item.visible = toggled_on
    if do_save:
        cus.save_state()
        if item.visible:
            cus.auto_disable(itype, iname)

func _on_button_mouse_entered() -> void:
    button.grab_focus()

func _on_button_mouse_exited() -> void:
    button.release_focus()

var tween: Tween

func _on_button_focus_entered() -> void:
    if tween and tween.is_running():
        tween.kill()
    tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.set_parallel(true)
    tween.tween_property(button, "scale:x", 1.1, 0.1)
    tween.tween_property(button, "scale:y", 1.1, 0.1)

func _on_button_focus_exited() -> void:
    if tween and tween.is_running():
        tween.kill()
    tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
    tween.set_parallel(true)
    tween.tween_property(button, "scale", Vector2.ONE, 0.15)
