extends Node

var chat_ui_layer_res := load(get_script().resource_path.get_base_dir() + "/client/chat_ui_layer.tscn")
var client_res := load(get_script().resource_path.get_base_dir() + "/client/client.tscn")
var network_server_res := load(get_script().resource_path.get_base_dir() + "/server/server.tscn")
var network_client_res := load(get_script().resource_path.get_base_dir() + "/client/client_api.gd")
var mp_version_res := load(get_script().resource_path.get_base_dir() + "/client/mp_version.tscn")

var chat: CanvasLayer
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

var self_steam_id: int
var latest_version: String
var mod_version: String

const _SETTINGS_PATH := "user://mp.cfg"

func _ready() -> void:
    _load_config()
    if "--server" in OS.get_cmdline_args():
        var port_override := -1
        for arg in OS.get_cmdline_args():
            if arg.begins_with("--port="):
                port_override = arg.trim_prefix("--port=").to_int()
        set_network_server(port_override, false)
    
    add_to_group("mp")
    get_tree().node_added.connect(_on_node_added)
    if game.is_steam() and Steam.steamInit():
        default_name = Steam.getPersonaName()
        self_steam_id = Steam.getSteamID()
    
    chat = chat_ui_layer_res.instantiate()
    add_child(chat)
    
    mod_version = ModLoaderMod.get_mod_data("com-multiplayer").manifest.version_number
    if mod_version.ends_with(".0"):
        mod_version = mod_version.left(-2)
    ModLoaderLog.info("Multiplayer v%s is ready" % mod_version, self.name)
    var existing_stage_title := get_tree().get_root().find_child("stage_title", true, false)
    if existing_stage_title:
        call_deferred("_on_stage_title", existing_stage_title)

func _notification(event: int) -> void:
    if event == NOTIFICATION_WM_CLOSE_REQUEST:
        if is_instance_valid(game.active_stage): if game.active_stage.anomaly_occurring: return
        Steam.steamShutdown()

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
    if node.is_in_group("player"):
        call_deferred("_attach_client")
    if node.name == "stage_title":
        call_deferred("_on_stage_title", node)

func _attach_client() -> void:
    var nia = get_tree().get_first_node_in_group("player")
    
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
    var nia = get_tree().get_first_node_in_group("player")
    if not nia:
        return
    nia.set_collision_mask_value(10, mp_cfg.collision)

# todo: get rid of this
func _update_network_client() -> void:
    if not client:
        return
    client.get_node("PatchPhone").client = network_client
    client.get_node("PuppetManager").client = network_client
    client.get_node("PlayerSync").client = network_client
    chat.get_node("ChatUI").client = network_client

func set_network_client() -> void:
    if network_client:
        return
    if not mp_cfg.auto_connect and not network_server:
        return
    network_client = network_client_res.new()
    network_client.name = "NetworkClient"
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

func set_network_server(port: int = -1, run_client: bool = true) -> void:
    if network_server:
        return
    network_server = network_server_res.instantiate()
    network_server.name = "NetworkServer"
    network_server.port = port
    if port == -1:
        network_server.port = mp_cfg.server_port
    add_child(network_server)
    if run_client:
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

var http: HTTPRequest

func _on_stage_title(stage_title: Node3D) -> void:
    var canvas = stage_title.get_node("canvas_layer")
    var mp_control: Control = mp_version_res.instantiate()
    var mp_ver: RichTextLabel = mp_control.get_node("mp_version")
    mp_ver.text = "mp v%s" % [mod_version]
    var mp_upd: RichTextLabel = mp_control.get_node("update_info")
    mp_upd.visible = false
    var button: Button = mp_control.get_node("button")
    button.visible = false
    canvas.add_child(mp_control)
    canvas.move_child(mp_control, stage_title.get_node("canvas_layer/info_version").get_index() + 1)
    
    http = HTTPRequest.new()
    add_child(http)
    var git_version = await _fetch_latest_version()
    if git_version != mod_version:
        mp_upd.text = "(update to v%s available)" % [git_version]
        mp_upd.visible = true
        button.visible = true
        button.pressed.connect(_on_update_pressed.bind(mp_upd))
    else:
        mp_ver.text += " (latest)"

func _fetch_latest_version() -> String:
    http.request("https://api.github.com/repos/bdegh/nophenia-mp/tags")
    var result = await http.request_completed
    var res = result[0]
    var code = result[1]
    var body = result[3]
    if res == OK and code == 200:
        var json = JSON.new()
        if json.parse(body.get_string_from_utf8()) == OK:
            latest_version = json.data[0].name
            return latest_version
        else:
            ModLoaderLog.info("Not a valid json", self.name)
    else:
        ModLoaderLog.error("Fail", self.name)
    return ""

func _on_update_pressed(label: RichTextLabel) -> void:
    if not DirAccess.dir_exists_absolute("res://mods"):
        DirAccess.make_dir_absolute("res://mods")
    label.text = "Downloading..."
    http.download_file = "res://mods/com-multiplayer.zip"
    http.request("https://github.com/BdEgh/nophenia-mp/releases/download/%s/com-multiplayer.zip" % latest_version, ["User-Agent: Godot"])
    var result = await http.request_completed
    var code = result[1]
    if result[0] == OK and code == 200:
        label.text = "Updated. Restarting..."
        await get_tree().create_timer(1.5).timeout
        OS.set_restart_on_exit(true, [])
        get_tree().quit()
    else:
        label.text = "Update failed. Code: %d" % code
