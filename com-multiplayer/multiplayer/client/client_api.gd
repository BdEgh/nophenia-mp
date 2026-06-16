#class_name MultiplayerClientProto
extends Node

var Api = load((get_script().resource_path.get_base_dir() + "/../api/pb.gd").simplify_path())
var WebSocketClient = load(get_script().resource_path.get_base_dir() + "/websocket_client.gd")

signal connected_to_server()
signal disconnected_from_server()
signal connection_failed()
signal player_set(player_id: int, state)
#signal player_merge(player_id: int, state)
signal player_delete(player_id: int)
signal player_message(player_id: int, message: String)
signal self_id(id: int)

@export var url := "ws://127.0.0.1:42424"

@export var ping_interval: float = 10.0
@export var auto_reconnect: bool = true

var socket
var _ping_timer: Timer

func _ready():
    _setup_websocket_client()
    _setup_ping_timer()
    socket.url = url
    socket.connect_to_server()

func _setup_websocket_client():
    socket = WebSocketClient.new()
    socket.auto_reconnect = auto_reconnect
    add_child(socket)
    
    socket.connection_established.connect(_on_connection_established)
    socket.connection_failed.connect(_on_connection_failed)
    socket.connection_closed.connect(_on_connection_closed)
    socket.data_received.connect(_on_data_received)

func _setup_ping_timer():
    _ping_timer = Timer.new()
    _ping_timer.wait_time = ping_interval
    _ping_timer.timeout.connect(_send_ping)
    add_child(_ping_timer)

func disconnect_from_server():
    _ping_timer.stop()
    socket.disconnect_from_server()

## Websocket Signals

func _on_connection_established():
    ModLoaderLog.info("Connected to server", self.name)
    connected_to_server.emit()
    _send_sync_request()
    
    _ping_timer.start()

func _on_connection_failed():
    ModLoaderLog.error("Failed to connect to server", self.name)
    connection_failed.emit()

func _on_connection_closed():
    ModLoaderLog.warning("Disconnected from server", self.name)
    _ping_timer.stop()
    disconnected_from_server.emit()

func _emit_player_state(peer_id: int, signed_state):
    match signed_state.get_action():
        Api.EAction.DELETE:
            player_delete.emit(peer_id)
        Api.EAction.SET:
            player_set.emit(peer_id, signed_state.get_state())
        #Api.EAction.MERGE:
            #player_merge.emit(peer_id, signed_state.get_state())

func _on_data_received(stub: int, data: PackedByteArray):
    var message = Api.TServerData.new()
    message.from_bytes(data)
    
    if message.has_players():
        if message.get_players().get_your_uid() != 0:
            self_id.emit(message.get_players().get_your_uid())
        for signed_state in message.get_players().get_signed_state():
            _emit_player_state(signed_state.get_uid(), signed_state)
    if message.has_chat_message():
        var signed_message = message.get_chat_message()
        player_message.emit(signed_message.get_uid(), signed_message.get_msg())
    
    if message.has_ping():
        var ping = message.get_ping()
        ping.get_ping_id()
        var delta = Time.get_ticks_msec() - ping.get_timestamp()
        ModLoaderLog.info("Ping response in %d ms" % delta, self.name)

## Client to server interactions

func _send_ping():
    if not socket.connected():
        return
    
    var data = Api.TClientData.new()
    var ping = data.new_ping()
    ping.set_ping_id(randi())
    ping.set_timestamp(Time.get_ticks_msec())
    
    socket.send_data(data.to_bytes())

func _send_sync_request():
    var data = Api.TClientData.new()
    data.set_sync_request(true)
    socket.send_data(data.to_bytes())

func send_chat_message(message: String):
    var data = Api.TClientData.new()
    var msg = data.new_chat_message()
    msg.set_msg(message)
    socket.send_data(data.to_bytes())

func send_state_update(message):
    var data = Api.TClientData.new()
    
    var signed_state = data.new_signed_state()
    signed_state.set_action(Api.EAction.SET)
    signed_state.__state.value = message
    
    socket.send_data(data.to_bytes())
