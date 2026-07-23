extends Node

func _init() -> void:
    ModLoaderLog.info("Init", self.name)
    
    var mod_init_root = get_script().resource_path.get_base_dir() + "/multiplayer/init.gd"
    var mod = load(mod_init_root).new()
    add_child(mod)

func _ready() -> void:
    ModLoaderLog.info("Ready", self.name)
