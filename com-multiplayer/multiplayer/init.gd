extends Node

var network_client_res := load(get_script().resource_path.get_base_dir() + "/client/client.tscn")
var network_server_res := load(get_script().resource_path.get_base_dir() + "/server/server.tscn")

var network_client : Node

var server_url := "ws://127.0.0.1"  # Default fallback

func _ready() -> void:
	if "--server" in OS.get_cmdline_args():
		add_child(network_server_res.instantiate())
	
	_load_config()
	
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	
	ModLoaderLog.info("Multiplayer is ready to start", self.name)

func _load_config() -> void:
	var config_path: String = get_script().resource_path.get_base_dir().get_base_dir() + "/config.json"
	
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		return
	var json_string := file.get_as_text()
	file.close()
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		return
	
	if json.data is Dictionary and json.data.has("server_url"):
		server_url = json.data["server_url"]
		ModLoaderLog.info("Loaded server URL from config: %s" % [server_url], self.name)

func _on_node_added(node: Node) -> void:
	call_deferred("_check_if_player", node, true)

func _on_node_removed(node: Node) -> void:
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
		
		client_api.url = server_url
		sync.player = nia
		puppet_manager.spawn_parent = map
		
		add_child(network_client)
	
	if !nia and network_client:
		network_client.queue_free()
