extends Node

var http_server_script = load((get_script().resource_path.get_base_dir() + "/godottpd/http_server.gd").simplify_path())
var get_stages_script = load((get_script().resource_path.get_base_dir() + "/godottpd/handlers/get_stages.gd").simplify_path())
var load_stage_script = load((get_script().resource_path.get_base_dir() + "/godottpd/handlers/load_stage.gd").simplify_path())
var get_player_list_script = load(get_script().resource_path.get_base_dir() + "/godottpd/handlers/get_player_list.gd")
var ban_script = load(get_script().resource_path.get_base_dir() + "/godottpd/handlers/ban.gd")
var unban_script = load(get_script().resource_path.get_base_dir() + "/godottpd/handlers/unban.gd")
var get_ban_list_script = load(get_script().resource_path.get_base_dir() + "/godottpd/handlers/get_ban_list.gd")

var server = null

#func _ready() -> void:
    #start_server(8080)

func start_server(port: int, multiplayer_server, key: String) -> void:
    if server != null:
        stop_server()
    server = http_server_script.new()
    server.port = port
    server.register_router(get_stages_script.new("/get_stages"))
    server.register_router(load_stage_script.new("/load_stage", "res://remote_stages"))
    server.register_router(get_player_list_script.new("/get_player_list", multiplayer_server, key))
    server.register_router(ban_script.new("/ban", multiplayer_server, key))
    server.register_router(unban_script.new("/unban", multiplayer_server, key))
    server.register_router(get_ban_list_script.new("/get_ban_list", multiplayer_server, key))
    add_child(server)
    server.enable_cors(["http://localhost:%d" % port])
    server.start()
    ModLoaderLog.info("http server started on port %s" % port, self.name)

func stop_server() -> void:
    if server == null:
        return
    server.stop()
    server.queue_free()
    ModLoaderLog.info("http server stopped", self.name)
