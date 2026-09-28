extends 'http_router.gd'

var _server
var _key: String

func _init(_path: String, server, key: String) -> void:
    path = _path
    _server = server
    _key = key

func handle_get(request, response) -> void:
    _respond.call_deferred(request, response)

func _respond(request, response) -> void:
    var req_key = str(request.query.get("key", "")).uri_decode()
    if _key.is_empty() or req_key != _key:
        response.json(403, {"error": "Invalid key"})
        return
    if not is_instance_valid(_server):
        response.json(503, {"error": "Server unavailable"})
        return
    var list: Array = []
    for uid in _server.socket._banned_list.get_section_keys("banned_players"):
        var record = _server.socket._banned_list.get_value("banned_players", uid)
        list.append({"uid": uid, "player_name": record.get("player_name", "")})
    response.json(200, list)
