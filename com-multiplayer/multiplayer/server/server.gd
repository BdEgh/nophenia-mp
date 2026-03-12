extends Control

var MultiplayerServerProto = load(get_script().resource_path.get_base_dir() + "/server_api.gd")

@onready var server = %ServerApi
@onready var host_input: LineEdit = %HostInput
@onready var port_input: SpinBox = %PortInput
@onready var start_button: Button = %StartButton
@onready var status_label: Label = %StatusLabel
@onready var log_text: RichTextLabel = %LogText

var is_running: bool = false

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	if server and server.socket:
		server.socket.peer_connected.connect(_on_peer_connected)
		server.socket.peer_disconnected.connect(_on_peer_disconnected)
	
	_update_ui()
	_add_log("[color=gray]Server ready to start[/color]")
	_check_autostart()

func _check_autostart():
	var args = OS.get_cmdline_args()
	if "--server" in args:
		_on_start_pressed()

func _on_start_pressed():
	var host = host_input.text
	var port = int(port_input.value)
	
	_add_log("[color=yellow]Starting server on %s:%d...[/color]" % [host, port])
	
	server.start_server(host, port)
	is_running = true
	
	_add_log("[color=green]Server started successfully![/color]")
	_add_log("[color=gray]Waiting for connections...[/color]")
	
	_update_ui()

func _on_peer_connected(peer_id: int):
	_add_log("[color=green]Player %d connected[/color]" % peer_id)

func _on_peer_disconnected(peer_id: int):
	_add_log("[color=yellow]Player %d disconnected[/color]" % peer_id)

func _update_ui():
	if is_running:
		status_label.text = "Status: Running on %s:%d" % [host_input.text, int(port_input.value)]
		status_label.add_theme_color_override("font_color", Color.GREEN)
		start_button.disabled = true
		host_input.editable = false
		port_input.editable = false
	else:
		status_label.text = "Status: Stopped"
		status_label.add_theme_color_override("font_color", Color.RED)
		start_button.disabled = false
		host_input.editable = true
		port_input.editable = true

func _add_log(message: String):
	var timestamp = Time.get_time_string_from_system()
	var text = "[%s] %s\n" % [timestamp, message]
	log_text.append_text(text)
	ModLoaderLog.info(text, self.name)

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_Q:
		visible = !visible
