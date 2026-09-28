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
    var players: Array = []
    for uid in _server.players:
        var stage_hash := -1
        var state = _server.players.get(uid)
        if state and state.get_world_hash():
            stage_hash = state.get_world_hash()
        players.append({"uid": uid, "name": _server._names.get(uid, ""), "stage_hash": stage_hash})
    response.json(200, players)
