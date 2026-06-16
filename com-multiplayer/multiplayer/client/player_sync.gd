#class_name PlayerNetworkSync
extends Node

var Api = load((get_script().resource_path.get_base_dir() + "/../api/pb.gd").simplify_path())
var MultiplayerClientProto = load(get_script().resource_path.get_base_dir() + "/client_api.gd")

@export var nia: CharacterBody3D
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
    if not nia:
        ModLoaderLog.error("No player assigned!", self.name)
        return
    if not client:
        ModLoaderLog.error("No network_client assigned!", self.name)
        return
    
    if nia.has_node("chara"):
        _visual_root = nia.get_node("chara")
    
    _last_position = nia.global_position
    _last_velocity = nia.velocity
    _last_rotation = _visual_root.rotation if _visual_root else Vector3.ZERO
    
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
    if not nia:
        return
    
    var is_howling = nia._howling
    if is_howling and not _was_howling:
        send_action("HOWL")
    _was_howling = is_howling

func _check_and_send_updates(force: bool):
    if not nia or not client:
        return
    
    if not client.socket or not client.socket.connected():
        return
    
    var current_position = nia.global_position
    var current_velocity = nia.velocity
    var current_rotation = _visual_root.rotation if _visual_root else Vector3.ZERO
    
    var position_changed = current_position.distance_to(_last_position) > position_threshold
    var velocity_changed = current_velocity.distance_to(_last_velocity) > velocity_threshold
    var rotation_changed = (current_rotation - _last_rotation).length() > rotation_threshold
    
    var current_animation = ""
    var current_animation_speed = 1.0
    var animation_changed = false
    
    if nia.has_node("anim_tree"):
        var anim_tree = nia.get_node("anim_tree")
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
