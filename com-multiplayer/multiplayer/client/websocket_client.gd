#class_name WebSocketClient
extends Node

signal data_received(peer_id: int, data: PackedByteArray)
signal connection_closed()

signal connection_established()
signal connection_failed()

@export var url := "ws://127.0.0.1:42424"
@export var auto_reconnect: bool = true
@export var reconnect_interval: float = 5.0

var _websocket: WebSocketPeer
var _reconnect_timer: Timer
var _is_connected: bool = false

func _ready():
    _setup_reconnect_timer()

func _setup_reconnect_timer():
    _reconnect_timer = Timer.new()
    _reconnect_timer.wait_time = reconnect_interval
    _reconnect_timer.timeout.connect(_attempt_reconnect)
    add_child(_reconnect_timer)

func connect_to_server():
    _websocket = WebSocketPeer.new()
    _websocket.inbound_buffer_size = 1024 * 1024 * 2
    var error = _websocket.connect_to_url(url)
    
    if error != OK:
        printerr("Failed to connect to %s - Error: %d" % [url, error])
        connection_failed.emit()
        return
    
    if auto_reconnect:
        _reconnect_timer.start()
    
    print("Connecting to %s..." % url)

func _process(_delta):
    if not _websocket:
        return
    
    _websocket.poll()
    var state = _websocket.get_ready_state()
    
    match state:
        WebSocketPeer.STATE_OPEN:
            _handle_open_state()
        WebSocketPeer.STATE_CLOSED:
            _handle_closed_state()

func _handle_open_state():
    if not _is_connected:
        _is_connected = true
        print("Connected to server")
        connection_established.emit()
        _reconnect_timer.stop()
    
    _process_incoming_data()

func _handle_closed_state():
    if _is_connected:
        _is_connected = false
        print("Connection closed")
        connection_closed.emit()
        if auto_reconnect:
            _reconnect_timer.start()

func _process_incoming_data():
    while _websocket.get_available_packet_count() > 0:
        var data = _websocket.get_packet()
        data_received.emit(0, data)  # Server peer_id is always 0

func send_data(data: PackedByteArray, peer_id: int = -1):
    if not _websocket or _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
        #print("Not connected to server")
        return
    
    _websocket.send(data)
    #print("Raw data sent to server")

func send_to_server(data: Variant):
    send_data(data)

func connected() -> bool:
    return _is_connected and _websocket and _websocket.get_ready_state() == WebSocketPeer.STATE_OPEN

func get_connection_state() -> WebSocketPeer.State:
    if _websocket:
        return _websocket.get_ready_state()
    return WebSocketPeer.STATE_CLOSED

func disconnect_from_server():
    auto_reconnect = false
    close_connection()

func enable_auto_reconnect(enable: bool = true):
    auto_reconnect = enable
    if not enable:
        _reconnect_timer.stop()

func set_reconnect_interval(interval: float):
    reconnect_interval = interval
    _reconnect_timer.wait_time = interval

func close_connection():
    if _websocket:
        _websocket.close()
        _websocket = null
    
    _is_connected = false
    _reconnect_timer.stop()
    print("WebSocket client connection closed")
    connection_closed.emit()

func _attempt_reconnect():
    if not _is_connected:
        print("Attempting to reconnect...")
        connect_to_server()

func _exit_tree():
    close_connection()
