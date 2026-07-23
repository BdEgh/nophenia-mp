extends Node

var patched_player_res := load(get_script().resource_path.get_base_dir() + "/patched_player.gd")

@export var player_sync: Node

var nia: Node

func _ready() -> void:
    nia = player_sync.nia
    _patch_player()

func _patch_player() -> void:
    var exported_data: Dictionary = {}
    for property in nia.get_property_list():
        if property.usage & PROPERTY_USAGE_EDITOR and property.name != "script":
            var property_name: String = property.name
            exported_data[property_name] = nia.get(property_name)
    nia.set_script(patched_player_res)
    for property_name in exported_data:
        nia.set(property_name, exported_data[property_name])
    nia.player_sync = player_sync
    nia._ready()
