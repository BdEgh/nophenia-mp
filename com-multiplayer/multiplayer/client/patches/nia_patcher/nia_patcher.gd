extends Node

var SharedPatcher = load(get_script().resource_path.get_base_dir() + "/shared_patcher.gd")

@export var player_sync: Node
var shared_patcher: Node

var nia: player

var puppet_manager: Node
var trans_vignette: Node
var trans_saturation: Node
var default_saturation: float = 1.0

func _ready() -> void:
    nia = player_sync.nia

    var mp_client = get_tree().get_first_node_in_group("mp").client
    puppet_manager = mp_client.get_node("PuppetManager")
    trans_vignette = nia.get_node("indicator_layer/trans_vignette")
    trans_saturation = nia.get_node("indicator_layer/trans_saturation")
    default_saturation = game.active_stage.environment.adjustment_saturation

    shared_patcher = SharedPatcher.new()
    nia.add_child(shared_patcher)
    shared_patcher.apply_patches(nia)
    shared_patcher.cheese.visible = false
    shared_patcher.mouth.visible = true

func _physics_process(delta: float) -> void:
    _nearby_stuff(delta)

func _suppress_impact() -> float:
    if not puppet_manager: return 0.0
    var nearest := INF
    for puppet in puppet_manager.puppets.values():
        if not puppet:
            continue
        var pup_body = puppet.get_node("nia")
        nearest = min(nearest, nia.global_position.distance_to(pup_body.global_position))
    return clampf(inverse_lerp(6.0, 2.0, nearest), 0.0, 1.0)

func _suppress_vignette(impact: float, delta: float) -> void:
    if not nia or not nia.is_sitting or nia.is_paused: return
    if nia._vignette_tween: nia._vignette_tween.kill()
    var vig_mat: Material = trans_vignette.material
    var sat_mat: Material = trans_saturation.material
    var alpha: float = vig_mat.get_shader_parameter("alpha")
    var value: float = sat_mat.get_shader_parameter("value")
    vig_mat.set_shader_parameter("alpha", move_toward(alpha, 1.0 - impact, delta / 0.8))
    sat_mat.set_shader_parameter("value", move_toward(value, 0.4 + 0.6 * impact, delta / 1.8))

func _tune_saturation(impact: float, delta: float) -> void:
    var sat = game.active_stage._world_env.environment.adjustment_saturation
    impact *= 0.2
    game.active_stage.environment.adjustment_saturation = move_toward(sat, default_saturation + impact, delta)

func _nearby_stuff(delta: float) -> void:
    var impact := _suppress_impact()
    if impact <= 0.0: return
    _suppress_vignette(impact, delta)
    _tune_saturation(impact, delta)

func toggle_roaches() -> void:
    shared_patcher.set_roaches(not shared_patcher.get_roaches())
    if shared_patcher.get_roaches():
        player_sync.send_action("ROACHES")
    else:
        player_sync.send_action("UNROACHES")

func change_jump_height(height: float) -> void:
    nia._jump_height = height

func halo_toggle():
    shared_patcher.set_halo(not shared_patcher.halo_fol.visible)
    if shared_patcher.halo_fol.visible:
        player_sync.send_action("HALO")
    else:
        player_sync.send_action("UNHALO")

var _surprised := false
func surprised_toggle():
    _surprised = not _surprised
    shared_patcher.set_surprised(_surprised)
    if _surprised:
        player_sync.send_action("WOW")
    else:
        player_sync.send_action("UNWOW")

var _eyes_closed := false
func eyes_toggle():
    _eyes_closed = not _eyes_closed
    shared_patcher.set_eyes_closed(_eyes_closed)
    if _eyes_closed:
        player_sync.send_action("YUMENIKKI")
    else:
        player_sync.send_action("UNYUMENIKKI")

func cheese_toggle():
    shared_patcher.set_cheese(not shared_patcher.cheese.visible)
    if shared_patcher.cheese.visible:
        player_sync.send_action("CHEESE")
    else:
        player_sync.send_action("UNCHEESE")

func dizzy():
    player_sync.send_action("DIZZY")
    shared_patcher.dizzy()

func ragdoll():
    if not shared_patcher.can_ragdoll(): return
    player_sync.send_action("RAGDOLL")
    shared_patcher.ragdoll()

func _unhandled_input(event: InputEvent) -> void:
    if get_tree().get_first_node_in_group("player") and get_tree().get_first_node_in_group("player").is_paused:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_3:
        surprised_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_4:
        toggle_roaches()
    if event is InputEventKey and event.pressed and event.keycode == KEY_5:
        eyes_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_6:
        cheese_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_7:
        halo_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_8:
        dizzy()
    if event is InputEventKey and event.pressed and event.keycode == KEY_9:
        ragdoll()
