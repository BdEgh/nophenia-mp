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
	var error = _websocket.connect_to_url(url)
	
	if error != OK:
		ModLoaderLog.error("Failed to connect to %s - Error: %d" % [url, error], self.name)
		connection_failed.emit()
		return
	
	if auto_reconnect:
		_reconnect_timer.start()
	
	ModLoaderLog.info("Connecting to %s..." % url, self.name)

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
		ModLoaderLog.info("Connected to server", self.name)
		connection_established.emit()
		_reconnect_timer.stop()
	
	_process_incoming_data()

func _handle_closed_state():
	if _is_connected:
		_is_connected = false
		ModLoaderLog.warning("Connection closed", self.name)
		connection_closed.emit()
		if auto_reconnect:
			_reconnect_timer.start()

func _process_incoming_data():
	while _websocket.get_available_packet_count() > 0:
		var data = _websocket.get_packet()
		data_received.emit(0, data)  # Server peer_id is always 0

func send_data(data: PackedByteArray, peer_id: int = -1):
	if not _websocket or _websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		#ModLoaderLog.debug("Not connected to server", self.name)
		return
	
	_websocket.send(data)
	#ModLoaderLog.debug("Raw data sent to server", self.name)

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
	ModLoaderLog.info("WebSocket client connection closed", self.name)
	connection_closed.emit()

func _attempt_reconnect():
	if not _is_connected:
		ModLoaderLog.info("Attempting to reconnect...", self.name)
		connect_to_server()

func _exit_tree():
	close_connection()
