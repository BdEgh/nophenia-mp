#class_name MultiplayerServerProto
extends Node

var Api = load((get_script().resource_path.get_base_dir() + "/../api/pb.gd").simplify_path())
var WebSocketServer = load(get_script().resource_path.get_base_dir() + "/websocket_server.gd")

@export var ping_timeout: float = 120.0 * 1000.0
@export var ping_check_interval: float = 5.0

var socket
var _ping_timer: Timer

var players := {}  # key: uid, value: TClientState
var _last_ping_times: Dictionary = {}  # key: uid, value: unix timestamp

func _ready() -> void:
    _setup_websocket_server()
    _setup_ping_timer()

func _setup_ping_timer():
    _ping_timer = Timer.new()
    _ping_timer.wait_time = ping_check_interval
    _ping_timer.timeout.connect(_check_ping_timeouts)
    _ping_timer.autostart = true
    add_child(_ping_timer)

func _check_ping_timeouts():
    var current_time = Time.get_ticks_msec()
    var timeout_players = []
    
    for peer_id in _last_ping_times:
        var last_ping = _last_ping_times[peer_id]
        var time_diff = current_time - last_ping
        
        if time_diff > ping_timeout:
            timeout_players.append(peer_id)
    
    for peer_id in timeout_players:
        ModLoaderLog.warning("Player %d timed out (no requests for %.0f ms)" % [peer_id, ping_timeout], self.name)
        _disconnect_player(peer_id)

func start_server(host: String = "127.0.0.1", port: int = 42425):
    socket.host = host
    socket.port = port
    socket.start_server()

func _setup_websocket_server():
    socket = WebSocketServer.new()
    add_child(socket)
    
    socket.peer_connected.connect(_on_peer_connected)
    socket.peer_disconnected.connect(_on_peer_disconnected)
    socket.data_received.connect(_on_data_received)

func _on_peer_connected(peer_id: int):
    _last_ping_times[peer_id] = Time.get_ticks_msec()

func _send_other_players_data(peer_id: int):
    var data = Api.TServerData.new()
    
    var msg = data.new_players()
    msg.set_your_uid(peer_id)
    
    for player_id in players:
        if peer_id == player_id or players[player_id] == null:
            continue
        var signed_state = msg.add_signed_state()
        signed_state.set_action(Api.EAction.SET)
        signed_state.set_uid(player_id)
        signed_state.__state.value = players[player_id]

    socket.send_data(data.to_bytes(), peer_id)

func _disconnect_player(peer_id: int):
    var data = Api.TServerData.new()
    var signed_state = data.new_players().add_signed_state()
    signed_state.set_uid(peer_id)
    signed_state.set_action(Api.EAction.DELETE)
    socket.send_data(data.to_bytes(), -peer_id)
    
    _last_ping_times.erase(peer_id)
    players.erase(peer_id)

func _set_player(peer_id: int, signed_state):
    var source = signed_state.get_state()
    if players.get(peer_id) == null:
        players[peer_id] = source
        return
    _merge_state(source, players[peer_id])

func _merge_state(source, target):
    for tag in source.data:
        var field = source.data[tag].field
        if field.value == null:
            continue
        if field.rule == Api.PB_RULE.REPEATED and field.value.size() == 0:
            continue
        if field.rule != Api.PB_RULE.REPEATED and field.value == Api.DEFAULT_VALUES_3[field.type]:
            continue
        target.data[tag].field.value = field.value
        target.data[tag].state = source.data[tag].state

func _on_peer_disconnected(peer_id: int):
    _disconnect_player(peer_id)

func _sync_state(peer_id: int, signed_state):
    var action = signed_state.get_action()
    match action:
        Api.EAction.DELETE:
            _disconnect_player(peer_id)
            return
        Api.EAction.SET:
            _set_player(peer_id, signed_state)
        #Api.EAction.MERGE:
            #_merge_player(peer_id, signed_state)
    
    var data = Api.TServerData.new()
    var player = data.new_players()
    signed_state.set_uid(peer_id)
    player.__signed_state.value.append(signed_state)
    socket.send_data(data.to_bytes(), -peer_id)

func _on_data_received(peer_id: int, data: PackedByteArray):
    _last_ping_times[peer_id] = Time.get_ticks_msec()
    var message = Api.TClientData.new()
    message.from_bytes(data)
    if message.has_signed_state():
        _sync_state(peer_id, message.get_signed_state())
    elif message.has_chat_message():
        var response = Api.TServerData.new()
        var msg = response.new_chat_message()
        msg.set_uid(peer_id)
        msg.set_msg(message.get_chat_message().get_msg())
        socket.send_data(response.to_bytes(), -peer_id)
        ModLoaderLog.info("%d: %s" % [peer_id, message.get_chat_message().get_msg()], self.name)
    elif message.has_sync_request() and message.get_sync_request() == true:
        _send_other_players_data(peer_id)
    elif message.has_ping():
        var response = Api.TServerData.new()
        response.__ping.value = message.get_ping()
        response.get_ping().set_total_online(players.size())
        socket.send_data(response.to_bytes(), peer_id)
