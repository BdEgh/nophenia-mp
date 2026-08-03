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

func _ready():
    pass

func start_server():
    _server = TCPServer.new()
    var error = _server.listen(port)
    if error != OK:
        ModLoaderLog.error("Failed to start server on port %d - Error: %d" % [port, error], self.name)
        return
    
    ModLoaderLog.info("WebSocket server started on %d" % [port], self.name)

func _process(_delta):
    if not _server:
        return
    
    _handle_new_connections()
    _process_existing_clients()

func _handle_new_connections():
    if _server.is_connection_available():
        var tcp_peer = _server.take_connection()
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
    return randi_range(1000000, 9000000)

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

func close_connection():
    for peer_id in _clients.keys():
        disconnect_peer(peer_id)
    
    if _server:
        _server.stop()
        _server = null
    
    ModLoaderLog.info("WebSocket server closed", self.name)
    connection_closed.emit()

func _exit_tree():
    close_connection()
