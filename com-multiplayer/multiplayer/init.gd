extends Node

var network_client_res := load(get_script().resource_path.get_base_dir() + "/client/client.tscn")
var network_server_res := load(get_script().resource_path.get_base_dir() + "/server/server.tscn")
var patched_interactable_res := load(get_script().resource_path.get_base_dir() + "/patches/interactable/patched_interactable.gd")

var network_server : Node
var network_client : Node

var mp_cfg_res := load(get_script().resource_path.get_base_dir() + "/mp_cfg.gd")
var mp_cfg = mp_cfg_res.new()

const _SETTINGS_PATH := "user://mp.cfg"

func _ready() -> void:
    if "--server" in OS.get_cmdline_args():
        network_server = network_server_res.instantiate()
        add_child(network_server)
    
    _load_config()

    add_to_group("mp")
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)
    _patch_existing(get_tree().root)

    seed(mp_cfg.rng_seed)
    ModLoaderLog.info("RNG seed: %d" % mp_cfg.rng_seed, self.name)
    ModLoaderLog.info("Multiplayer is ready to start", self.name)

func _load_config() -> void:
    var cfg := ConfigFile.new()
    if cfg.load(_SETTINGS_PATH) != OK:
        return
    for _prop in mp_cfg.get_script().get_script_property_list():
        if cfg.has_section_key("setting", _prop.name):
            mp_cfg.set(_prop.name, cfg.get_value("setting", _prop.name))
    ModLoaderLog.info("Loaded server URL from config: %s" % [mp_cfg.address], self.name)

func save_config() -> void:
    var cfg := ConfigFile.new()
    for _prop in mp_cfg.get_script().get_script_property_list():
        cfg.set_value("setting", _prop.name, mp_cfg.get(_prop.name))
    cfg.save(_SETTINGS_PATH)

func _patch_existing(node: Node) -> void:
    _try_patch(node)
    for child in node.get_children():
        _patch_existing(child)

func _try_patch(node: Node) -> bool:
    if node is interactable:
        node.set_script(patched_interactable_res)
        return true
    return false

func _on_node_added(node: Node) -> void:
    call_deferred("_check_if_player", node, true)

func _on_node_removed(_node: Node) -> void:
    call_deferred("_attach_client")

func _check_if_player(node: Node, _added: bool) -> void:
    if node.is_in_group("player"):
        _attach_client()

func _attach_client() -> void:
    var nia = game.nia
    
    if nia and network_client == null:
        var map = game.active_stage
        if map.anomaly_occurring:
            return
        
        network_client = network_client_res.instantiate()
        
        var client_api = network_client.get_node("ClientApi")
        client_api.url = mp_cfg.address
        
        add_child(network_client)
    
    if !nia and network_client:
        network_client.queue_free()
