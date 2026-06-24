extends Node

@export var id: int = 0
var nia_instance: Node3D
var name_label: Label3D
var player_name: String = ""
var floating_message_scene: PackedScene

func teleport_to(pos: Vector3):
    nia_instance.teleport_to(pos)

func apply_state(state):
    nia_instance.apply_state(state)

func _init() -> void:
    var nia_scene = load("res://resource/nia.tscn")
    if not nia_scene:
        ModLoaderLog.error("Failed to load nia.tscn", self.name)
        return
    
    nia_instance = nia_scene.instantiate()
    nia_instance.set_script(
        load(get_script().resource_path.get_base_dir() + "/puppet.gd")
    )
    _remove_unwanted_nodes(nia_instance)
    self.add_child(nia_instance)
    
    floating_message_scene = load(
        get_script().resource_path.get_base_dir() + "/ui_chat/floating_chat_message.tscn"
    )

func _ready() -> void:
    name_label = get_node("NameLabel")
    name_label.text = player_name
    name_label.reparent(nia_instance, false)

func set_player_name(value: String) -> void:
    player_name = value
    if name_label:
        name_label.text = value

func show_chat_message(message: String):
    if message.begins_with("DO:"):
        return
    
    var floating_msg = floating_message_scene.instantiate()
    var cheese = nia_instance.get_node("cheese_position")
    var chara = nia_instance.get_node("chara")
    var forward_offset = -chara.global_transform.basis.z.normalized() * 0.25
    floating_msg.global_position = cheese.global_position + forward_offset + Vector3(0, 0.25, 0)
    game.active_stage.add_child(floating_msg)
    floating_msg.set_message(message)
    audio.play_snd_spatial(game.loadres("phone_keypad_short"), cheese.global_position, 10.0, -1, 0.8, "snd")

func _remove_unwanted_nodes(node: Node):
    var nodes_to_remove = [
        "photo_mode_layer",
        "indicator_layer",
        "freecam",
        "pause_menu",
        "cam_box",
        "remote_transform_3d",
        "freecam_idle_timer",
        "fall_velocity"
    ]
    for node_name in nodes_to_remove:
        var child = node.get_node_or_null(node_name)
        if child:
            child.queue_free()

func _input(event):
    if event is InputEventKey and event.pressed and event.keycode == KEY_0:
        name_label.visible = !name_label.visible
