extends Node

var client_res := load(get_script().resource_path.get_base_dir() + "/client/client.tscn")
var network_server_res := load(get_script().resource_path.get_base_dir() + "/server/server.tscn")
var network_client_res := load(get_script().resource_path.get_base_dir() + "/client/client_api.gd")

var client : Node
var network_server : Node
var network_client : Node

var mp_cfg_res := load(get_script().resource_path.get_base_dir() + "/mp_cfg.gd")
var mp_cfg = mp_cfg_res.new()
var default_name: String = [
    "cheese", "milk", "tea",
    "coffee", "fish", "pumpkin",
    "melon", "apple", "banana",
    "berry", "honey", "sugar",
    "kiwi", "mango", "orange"
].pick_random()

const _SETTINGS_PATH := "user://mp.cfg"

func _ready() -> void:
    if "--server" in OS.get_cmdline_args():
        set_network_server()
    
    _load_config()
    add_to_group("mp")
    set_network_client()
    get_tree().node_added.connect(_on_node_added)
    get_tree().node_removed.connect(_on_node_removed)
    if game.is_steam() and Steam.steamInit():
        default_name = Steam.getPersonaName()
    
    ModLoaderLog.info("Multiplayer is ready", self.name)

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

func _on_node_added(node: Node) -> void:
    call_deferred("_check_if_player", node, true)

func _on_node_removed(_node: Node) -> void:
    call_deferred("_attach_client")

func _check_if_player(node: Node, _added: bool) -> void:
    if node.is_in_group("player"):
        _attach_client()

func _attach_client() -> void:
    var nia = game.nia
    
    if nia:
        if not nia.tree_exited.is_connected(_on_nia_exited):
            nia.tree_exited.connect(_on_nia_exited, CONNECT_ONE_SHOT)
        if client == null:
            var map = game.active_stage
            if map.anomaly_occurring:
                return
                
            set_network_client()
            client = client_res.instantiate()
            client.get_node("PlayerSync").nia = nia
            _update_network_client()
            add_child(client)
            if network_client:
                network_client.request_sync()
        apply_player_collision()

func apply_player_collision() -> void:
    var nia = game.nia
    if not nia:
        return
    nia.set_collision_mask_value(10, mp_cfg.collision)

# todo: get rid of this
func _update_network_client() -> void:
    if not client:
        return
    client.get_node("PatchPhone").client = network_client
    client.get_node("PuppetManager").client = network_client
    client.get_node("ChatUILayer/ChatUI").client = network_client
    client.get_node("PlayerSync").client = network_client

func set_network_client() -> void:
    if network_client:
        return
    if not mp_cfg.auto_connect and not network_server:
        return
    network_client = network_client_res.new()
    network_client.name = "ClientApi"
    if network_server:
        network_client.url = "ws://127.0.0.1:%d" % mp_cfg.server_port
    else:
        network_client.url = mp_cfg.address
    add_child(network_client)
    _update_network_client()
    network_client.request_sync()

func drop_network_client() -> void:
    if not network_client:
        return
    network_client.queue_free()
    network_client = null
    _update_network_client()

func set_network_server() -> void:
    if network_server:
        return
    network_server = network_server_res.instantiate()
    network_server.name = "NetworkServer"
    network_server.port = mp_cfg.server_port
    add_child(network_server)
    drop_network_client()
    set_network_client()

func drop_network_server() -> void:
    if not network_server:
        return
    network_server.queue_free()
    network_server = null
    drop_network_client()
    if mp_cfg.auto_connect:
        set_network_client()

func _on_nia_exited() -> void:
    if client:
        client.queue_free()
        client = null
