#class_name WebSocketServer
extends Node

signal data_received(peer_id: int, data: PackedByteArray)
signal connection_closed()

signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)

@export var host: String = "*"
@export var port: int = 42424

var _server: TCPServer
var _clients: Dictionary = {}
var _banned_list := ConfigFile.new()
var _ban_reload_timer := Timer.new()
var _ban_reload_error: int = OK

const BANNED_LIST_PATH := "user://banned_list.ini"

func _ready():
    add_child(_ban_reload_timer)
    _ban_reload_timer.timeout.connect(_reload_banned_list)

func start_server():
    _ban_reload_error = OK
    _banned_list = ConfigFile.new()
    var load_error := _banned_list.load(BANNED_LIST_PATH)
    if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
        ModLoaderLog.error("Could not load banned_list.ini: %d" % load_error, self.name)
        return
    _server = TCPServer.new()
    var error = _server.listen(port)
    if error != OK:
        ModLoaderLog.error("Failed to start server on port %d - Error: %d" % [port, error], self.name)
        return
    
    _ban_reload_timer.start(1.0)
    ModLoaderLog.info("WebSocket server started on %d" % [port], self.name)

func _process(_delta):
    if not _server:
        return
    
    _handle_new_connections()
    _process_existing_clients()

func _reload_banned_list() -> void:
    var banned_list := ConfigFile.new()
    var error := banned_list.load(BANNED_LIST_PATH)
    # A missing file may be an editor replacing it during a save. Keep current bans.
    if error != OK:
        if error != ERR_FILE_NOT_FOUND and error != _ban_reload_error:
            ModLoaderLog.error("Could not reload banned_list.ini: %d" % error, self.name)
        _ban_reload_error = error
        return
    _ban_reload_error = OK
    if banned_list.encode_to_text() == _banned_list.encode_to_text():
        return
    _banned_list = banned_list
    for uid in _clients.keys():
        if _is_address_banned(_clients[uid].get_connected_host()):
            disconnect_peer(uid)
    ModLoaderLog.info("Reloaded banned_list.ini", self.name)

func _handle_new_connections():
    if _server.is_connection_available():
        var tcp_peer = _server.take_connection()
        if _is_address_banned(tcp_peer.get_connected_host()):
            tcp_peer.disconnect_from_host()
            return
        var ws_peer = WebSocketPeer.new()
        ws_peer.outbound_buffer_size = 1024 * 1024 * 2
        ws_peer.accept_stream(tcp_peer)
        
        var peer_id = _generate_peer_id()
        _clients[peer_id] = ws_peer
        ModLoaderLog.info("Client connected ; peer_id: %d ; host: %s" % \
            [peer_id, ws_peer.get_connected_host()], self.name)
        peer_connected.emit(peer_id)

func _process_existing_clients():
    var disconnected_peers = []
    for peer_id in _clients:
        var client = _clients[peer_id] as WebSocketPeer
        client.poll()
        
        var state = client.get_ready_state()
        if state == WebSocketPeer.STATE_OPEN:
            _process_client_data(peer_id, client)
        elif state == WebSocketPeer.STATE_CLOSED:
            disconnected_peers.append(peer_id)
    
    _cleanup_disconnected_peers(disconnected_peers)

func _process_client_data(peer_id: int, client: WebSocketPeer):
    while client.get_available_packet_count() > 0:
        var data = client.get_packet()
        data_received.emit(peer_id, data)

func _cleanup_disconnected_peers(disconnected_peers: Array):
    for peer_id in disconnected_peers:
        _clients.erase(peer_id)
        ModLoaderLog.info("Client disconnected: %d" % peer_id, self.name)
        peer_disconnected.emit(peer_id)

func _generate_peer_id() -> int:
    var peer_id := randi_range(1000000, 9000000)
    while _clients.has(peer_id) or _banned_list.has_section_key("banned_players", str(peer_id)):
        peer_id = randi_range(1000000, 9000000)
    return peer_id

func _is_address_banned(address: String) -> bool:
    if _banned_list.get_value("banned", address, false):
        return true
    if _banned_list.has_section("banned_players"):
        for uid in _banned_list.get_section_keys("banned_players"):
            var record = _banned_list.get_value("banned_players", uid)
            if record is Dictionary and record.get("ip", "") == address:
                return true
    return false

func send_data(data: PackedByteArray, peer_id: int = -1):
    if peer_id == -1:
        broadcast_to_all(data)
    elif peer_id < -1:
        broadcast_to_all(data, -peer_id)
    else:
        send_to_peer(data, peer_id)

func broadcast_to_all(data: PackedByteArray, exclude_peer: int = -1):
    var sent_count = 0
    for client_id in _clients:
        if exclude_peer != client_id and _send_to_client(client_id, data):
            sent_count += 1
    
    #ModLoaderLog.debug("Broadcasted data to %d clients" % sent_count, self.name)

func send_to_peer(data: PackedByteArray, peer_id: int):
    if not _clients.has(peer_id):
        ModLoaderLog.warning("Client %d not found" % peer_id, self.name)
        return
    
    if _send_to_client(peer_id, data):
        #ModLoaderLog.debug("Sent data to client %d" % peer_id, self.name)
        pass

func send_to_peers(data: PackedByteArray, peer_ids: Array[int]):
    var sent_count = 0
    
    for peer_id in peer_ids:
        if _send_to_client(peer_id, data):
            sent_count += 1
    
    #ModLoaderLog.debug("Sent data to %d/%d specified clients" % [sent_count, peer_ids.size()], self.name)

func _send_to_client(peer_id: int, data: PackedByteArray) -> bool:
    if not _clients.has(peer_id):
        return false
    
    var client = _clients[peer_id] as WebSocketPeer
    if client.get_ready_state() == WebSocketPeer.STATE_OPEN:
        client.send(data)
        return true
    else:
        ModLoaderLog.warning("Client %d is not connected" % peer_id, self.name)
        return false

func disconnect_peer(peer_id: int):
    if _clients.has(peer_id):
        var client = _clients[peer_id] as WebSocketPeer
        client.close()
        _clients.erase(peer_id)
        ModLoaderLog.info("Disconnected client: %d" % peer_id, self.name)
        peer_disconnected.emit(peer_id)

func get_connected_peers() -> Array[int]:
    var peer_ids: Array[int] = []
    for peer_id in _clients.keys():
        peer_ids.append(peer_id)
    return peer_ids

func get_peer_count() -> int:
    return _clients.size()

func is_peer_connected(peer_id: int) -> bool:
    return _clients.has(peer_id) and _clients[peer_id].get_ready_state() == WebSocketPeer.STATE_OPEN

func ban_peer(peer_id: int, player_name: String) -> Error:
    if not is_peer_connected(peer_id):
        return ERR_DOES_NOT_EXIST
    var address: String = _clients[peer_id].get_connected_host()
    var banned_list := ConfigFile.new()
    var error := banned_list.load(BANNED_LIST_PATH)
    if error != OK and error != ERR_FILE_NOT_FOUND:
        return error
    banned_list.set_value("banned_players", str(peer_id), {
        "ip": address,
        "uid": peer_id,
        "player_name": player_name,
    })
    error = banned_list.save(BANNED_LIST_PATH)
    if error != OK:
        return error
    _banned_list = banned_list
    for uid in _clients.keys():
        if _clients[uid].get_connected_host() == address:
            disconnect_peer(uid)
    return OK

func unban_peer(peer_id: int) -> Error:
    var banned_list := ConfigFile.new()
    var error := banned_list.load(BANNED_LIST_PATH)
    if error == ERR_FILE_NOT_FOUND:
        return ERR_DOES_NOT_EXIST
    if error != OK:
        return error
    if not banned_list.has_section_key("banned_players", str(peer_id)):
        return ERR_DOES_NOT_EXIST
    banned_list.erase_section_key("banned_players", str(peer_id))
    error = banned_list.save(BANNED_LIST_PATH)
    if error != OK:
        return error
    _banned_list = banned_list
    return OK

func close_connection():
    _ban_reload_timer.stop()
    for peer_id in _clients.keys():
        disconnect_peer(peer_id)
    
    if _server:
        _server.stop()
        _server = null
    
    ModLoaderLog.info("WebSocket server closed", self.name)
    connection_closed.emit()

func _exit_tree():
    close_connection()
