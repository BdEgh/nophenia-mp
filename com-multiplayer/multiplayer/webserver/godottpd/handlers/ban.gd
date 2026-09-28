extends 'http_router.gd'

var _server
var _key: String

func _init(_path: String, server, key: String) -> void:
    path = _path
    _server = server
    _key = key

func handle_post(request, response) -> void:
    _respond.call_deferred(request, response)

func _respond(request, response) -> void:
    var req_key = str(request.query.get("key", "")).uri_decode()
    if _key.is_empty() or req_key != _key:
        response.json(403, {"error": "Invalid key"})
        return
    if not is_instance_valid(_server):
        response.json(503, {"error": "Server unavailable"})
        return
    var uid := str(request.query.get("uid", ""))
    if not uid.is_valid_int():
        response.json(400, {"error": "Invalid uid"})
        return
    var error = _server.socket.ban_peer(uid.to_int(), str(_server._names.get(uid.to_int(), "")))
    if error == ERR_DOES_NOT_EXIST:
        response.json(404, {"error": "Player not found"})
    elif error != OK:
        response.json(500, {"error": "Could not save ban"})
    else:
        response.json(200, {"uid": uid.to_int(), "banned": true})
