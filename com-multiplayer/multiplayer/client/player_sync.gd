#class_name PlayerNetworkSync
extends Node

var Api = load((get_script().resource_path.get_base_dir() + "/../api/pb.gd").simplify_path())
var MultiplayerClientProto = load(get_script().resource_path.get_base_dir() + "/client_api.gd")

@export var player: CharacterBody3D
@export var client: Node
@export var update_rate: float = 0.15
@export var position_threshold: float = 0.2
@export var velocity_threshold: float = 0.01
@export var rotation_threshold: float = 0.01
@export var full_update_rate: float = 100

var _full_state_timer: Timer
var _update_timer: Timer

var _last_position: Vector3 = Vector3.ZERO
var _last_velocity: Vector3 = Vector3.ZERO
var _last_rotation: Vector3 = Vector3.ZERO
var _last_animation: String = ""
var _last_animation_speed: float = 1.0
var _visual_root: Node3D = null
var _was_howling: bool = false

func _ready():
	if not player:
		ModLoaderLog.error("No player assigned!", self.name)
		return
	
	if not client:
		ModLoaderLog.error("No network_client assigned!", self.name)
		return
	
	# Get the chara node for rotation tracking
	if player.has_node("chara"):
		_visual_root = player.get_node("chara")
	
	_last_position = player.global_position
	_last_velocity = player.velocity
	_last_rotation = _visual_root.rotation if _visual_root else Vector3.ZERO
	
	_patch_phone()
	
	_update_timer = Timer.new()
	_update_timer.wait_time = update_rate
	_update_timer.autostart = true
	_update_timer.timeout.connect(_check_and_send_updates.bind(false))
	add_child(_update_timer)
	
	_full_state_timer = Timer.new()
	_full_state_timer.wait_time = full_update_rate
	_full_state_timer.autostart = true
	_full_state_timer.timeout.connect(_check_and_send_updates.bind(true))
	add_child(_full_state_timer)

func _physics_process(_delta):
	if not player:
		return
	
	var is_howling = player._howling
	if is_howling and not _was_howling:
		send_action("HOWL")
	_was_howling = is_howling

func _check_and_send_updates(force: bool):
	if not player or not client:
		return
	
	if not client.socket or not client.socket.connected():
		return
	
	var current_position = player.global_position
	var current_velocity = player.velocity
	var current_rotation = _visual_root.rotation if _visual_root else Vector3.ZERO
	
	var position_changed = current_position.distance_to(_last_position) > position_threshold
	var velocity_changed = current_velocity.distance_to(_last_velocity) > velocity_threshold
	var rotation_changed = (current_rotation - _last_rotation).length() > rotation_threshold
	
	var current_animation = ""
	var current_animation_speed = 1.0
	var animation_changed = false
	
	if player.has_node("anim_tree"):
		var anim_tree = player.get_node("anim_tree")
		if anim_tree is AnimationTree:
			var playback = anim_tree.get("parameters/playback")
			if playback:
				current_animation = playback.get_current_node()
				animation_changed = current_animation != _last_animation
	
	if force or position_changed or velocity_changed or rotation_changed or animation_changed:
		_send_state_update(current_position, current_velocity, current_rotation, current_animation, current_animation_speed)
		
		_last_position = current_position
		_last_velocity = current_velocity
		_last_rotation = current_rotation
		_last_animation = current_animation
		_last_animation_speed = current_animation_speed

func _send_state_update(pos: Vector3, vel: Vector3, rot: Vector3, anim: String, anim_speed: float):
	var state = Api.TClientState.new()
	
	state.set_world_hash(game.active_stage.stage_name.hash())
	
	var position = state.new_position()
	position.add_vector(pos.x)
	position.add_vector(pos.y)
	position.add_vector(pos.z)
	
	var velocity = state.new_velocity()
	velocity.add_vector(vel.x)
	velocity.add_vector(vel.y)
	velocity.add_vector(vel.z)
	
	var rotation = state.new_rotation()
	rotation.add_vector(rot.x)
	rotation.add_vector(rot.y)
	rotation.add_vector(rot.z)
	
	var animation = state.new_animation()
	animation.set_name(anim)
	animation.set_speed(anim_speed)
	animation.set_playing(true)
	
	client.send_state_update(state)

func send_action(action: String):
	if not client or not client.socket or not client.socket.connected():
		return
	client.send_chat_message("DO:" + action)

func _patch_phone():
	var pause_menu = player.get_node("pause_menu")
	var screen_view = pause_menu.get_node("screen/screen_view")
	var options_vbox = screen_view.get_node("menu/options/margin_container/scroll_container/v_box_container")
	var menu_control = screen_view.get_node("menu")
	
	var option_multiplayer_scene = load(get_script().resource_path.get_base_dir() + "/ui_phone/option_multiplayer.tscn")
	var multiplayer_scene = load(get_script().resource_path.get_base_dir() + "/ui_phone/multiplayer.tscn")
	
	var option_multiplayer = option_multiplayer_scene.instantiate()
	option_multiplayer.name = "option_multiplayer"
	
	var multiplayer_screen = multiplayer_scene.instantiate()
	multiplayer_screen.name = "multiplayer"
	multiplayer_screen.visible = false
	var info_label = multiplayer_screen.get_node("margin_container/v_box_container2/nine_patch_rect2/margin_container/info")
	if info_label:
		info_label.client = client
		info_label.puppet_manager = get_node("../PuppetManager")
	
	options_vbox.add_child(option_multiplayer)
	var exitgame_option = options_vbox.get_node_or_null("option_exitgame")
	if exitgame_option:
		options_vbox.move_child(option_multiplayer, exitgame_option.get_index())
	
	menu_control.add_child(multiplayer_screen)
	multiplayer_screen.layout_mode = 1
	option_multiplayer._screen = multiplayer_screen
