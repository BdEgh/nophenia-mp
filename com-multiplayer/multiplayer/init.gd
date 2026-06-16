extends Node

var network_client_res := load(get_script().resource_path.get_base_dir() + "/client/client.tscn")
var network_server_res := load(get_script().resource_path.get_base_dir() + "/server/server.tscn")
var patched_interactable_res := load(get_script().resource_path.get_base_dir() + "/patches/interactable/patched_interactable.gd")

var network_client : Node

var auto_connect := false
var address := "ws://127.0.0.1"
var server_port := 42424
var rng_seed := 0

const _SETTINGS_PATH := "mp.cfg"

func _ready() -> void:
    if "--server" in OS.get_cmdline_args():
        add_child(network_server_res.instantiate())
    
    _load_config()

    add_to_group("mp_init")
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)
    _patch_existing(get_tree().root)

    seed(rng_seed)
    ModLoaderLog.info("RNG seed: %d" % rng_seed, self.name)
    ModLoaderLog.info("Multiplayer is ready to start", self.name)

func _load_config() -> void:
    var cfg := ConfigFile.new()
    cfg.load(_SETTINGS_PATH)
    address = cfg.get_value("multiplayer", "address", "wss://super-cirno.duckdns.org:42424")
    auto_connect = cfg.get_value("multiplayer", "auto_connect", false)
    server_port = cfg.get_value("multiplayer", "server_port", 42424)
    rng_seed = cfg.get_value("game", "seed", 1337)
    ModLoaderLog.info("Loaded server URL from config: %s" % [address], self.name)

func _save_config() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("multiplayer", "auto_connect", auto_connect)
    cfg.set_value("multiplayer", "address",      address)
    cfg.set_value("multiplayer", "server_port",  server_port)
    cfg.set_value("game",        "seed",         rng_seed)
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
    var nia = game.find("player")
    
    if nia and network_client == null:
        var map = game.active_stage
        if map.anomaly_occurring:
            return
        
        network_client = network_client_res.instantiate()
        
        var client_api = network_client.get_node("ClientApi")
        var sync = network_client.get_node("PlayerSync")
        var puppet_manager = network_client.get_node("PuppetManager")
        var phone_patcher = network_client.get_node("PhonePatcher")
        
        client_api.url = address
        sync.nia = nia
        puppet_manager.spawn_parent = map
        phone_patcher.nia = nia
        
        add_child(network_client)
    
    if !nia and network_client:
        network_client.queue_free()
