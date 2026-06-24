extends Control

var MultiplayerServerProto = load(get_script().resource_path.get_base_dir() + "/server_api.gd")

@export var port: int = 42424

@onready var server = %ServerApi
@onready var status_label: Label = %StatusLabel
@onready var log_text: RichTextLabel = %LogText

func _ready():
    status_label.text = "Running on %s:%d" % ["*", port]
    if ModLoader:
        ModLoader.logged.connect(_on_mod_loader_logged)
    server.start_server(port)

func _on_mod_loader_logged(log_entry) -> void:
    if log_entry.mod_name != server.name:
        return
    var timestamp = Time.get_time_string_from_system()
    var text = "[%s][%s]: %s\n" % [timestamp, log_entry.type, log_entry.message]
    log_text.append_text(text)

func _input(event):
    if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
        visible = !visible
