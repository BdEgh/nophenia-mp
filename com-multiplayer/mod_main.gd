extends Node

func _init() -> void:
    print("Init")
    
    var mod_init_root = get_script().resource_path.get_base_dir() + "/multiplayer/init.gd"
    var mod = load(mod_init_root).new()
    add_child(mod)

func _ready() -> void:
    print("Ready")
