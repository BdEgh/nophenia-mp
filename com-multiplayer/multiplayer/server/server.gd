extends Control

var MultiplayerServerProto = load(get_script().resource_path.get_base_dir() + "/server_api.gd")

@export var port: int = 42424

@onready var server = %ServerApi
@onready var status_label: Label = %StatusLabel
@onready var log_text: RichTextLabel = %LogText

func _ready():
    if server and server.socket:
        server.socket.peer_connected.connect(_on_peer_connected)
        server.socket.peer_disconnected.connect(_on_peer_disconnected)
    
    status_label.text = "Running on %s:%d" % ["*", port]
    server.start_server(port)

func _on_peer_connected(peer_id: int):
    _add_log("[color=green]Player %d connected[/color]" % peer_id)

func _on_peer_disconnected(peer_id: int):
    _add_log("[color=yellow]Player %d disconnected[/color]" % peer_id)

func _add_log(message: String):
    var timestamp = Time.get_time_string_from_system()
    var text = "[%s] %s\n" % [timestamp, message]
    log_text.append_text(text)
    ModLoaderLog.info(text, self.name)

func _input(event):
    if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
        visible = !visible
