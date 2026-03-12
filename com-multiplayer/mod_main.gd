extends Node

# feel free to reuse
# meow~

const MOD_DIR := "com-multiplayer"
const LOG_NAME := "com-multiplayer:Main"

func _init() -> void:
	ModLoaderLog.info("Init", LOG_NAME)

	var mod_init_root = get_script().resource_path.get_base_dir() + "/multiplayer/init.gd"
	var mod = load(mod_init_root).new()
	add_child(mod)

func _ready() -> void:
	ModLoaderLog.info("Ready", LOG_NAME)
