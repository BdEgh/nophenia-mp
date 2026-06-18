extends Node

var PhysSkel = load(get_script().resource_path.get_base_dir() + "/actions/phys_skel.tscn")
var HaloAttachment = load(get_script().resource_path.get_base_dir() + "/items/halo/halo_attachment.tscn")
var HaloFollower = load(get_script().resource_path.get_base_dir() + "/items/halo/halo_follower.tscn")

var nia: player
var plinktimer: Timer
var skeleton: Skeleton3D

var hair_ribbon: MeshInstance3D
var head: MeshInstance3D
var ribbon: MeshInstance3D
var scarf: MeshInstance3D
var tail_ribbon: MeshInstance3D
var blouse_ribbon: MeshInstance3D
var mouth: Node3D
var cheese: Node3D
var phys_skel: PhysicalBoneSimulator3D
var halo_att: BoneAttachment3D
var halo_fol: Node3D

var anim_tree: AnimationTree
var anim_player: AnimationPlayer

var puppet_manager: Node
var trans_vignette: Node
var trans_saturation: Node
var default_saturation: float = 1.0

func _ready() -> void:
    nia = game.find("player")
    
    skeleton = nia.get_node("chara/Armature/Skeleton3D")
    plinktimer = nia.get_node("plinktimer")
    anim_tree = nia.get_node("anim_tree")
    anim_player = nia.get_node("anim_player")
    var mp_client = get_tree().get_first_node_in_group("mp").network_client
    puppet_manager = mp_client.get_node("PuppetManager")
    trans_vignette = nia.get_node("indicator_layer/trans_vignette")
    trans_saturation = nia.get_node("indicator_layer/trans_saturation")
    default_saturation = game.active_stage.environment.adjustment_saturation
    
    hair_ribbon = skeleton.get_node("hair_ribbon")      # off
    head = skeleton.get_node("head")                    # on
    ribbon = skeleton.get_node("ribbon")                # off
    scarf = skeleton.get_node("scarf")                  # off
    tail_ribbon = skeleton.get_node("tail_ribbon")      # on
    blouse_ribbon = skeleton.get_node("blouse_ribbon")  # off
    mouth = nia.get_node("cheese_position")             # off -> on
    cheese = nia.get_node("cheese_position/grilled_cheeze") # on -> off
    cheese.visible = false
    mouth.visible = true
    
    phys_skel = PhysSkel.instantiate()
    skeleton.add_child(phys_skel)
    
    add_halo()

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
    impact *= 0.25
    game.active_stage.environment.adjustment_saturation = move_toward(sat, default_saturation + impact, delta)

func _nearby_stuff(delta: float) -> void:
    var impact := _suppress_impact()
    if impact <= 0.0: return
    _suppress_vignette(impact, delta)
    _tune_saturation(impact, delta)

func add_halo():
    halo_att = HaloAttachment.instantiate()
    skeleton.add_child(halo_att)
    halo_fol = HaloFollower.instantiate()
    halo_fol.target_node = halo_att.get_node("halo_marker")
    halo_fol.visible = false
    nia.add_child(halo_fol)

func toggle_roaches() -> void:
    nia.get_node("chara/blob_shadow_arm/bug_step").visible = not nia.get_node("chara/blob_shadow_arm/bug_step").visible

func change_jump_height(height: float) -> void:
    nia._jump_height = height

func halo_toggle():
    halo_fol.visible = not halo_fol.visible

var _eyes_closed := false
func eyes_toggle():
    if _eyes_closed:
        plinktimer.start()
        head.set_blend_shape_value(0, 0)
        _eyes_closed = false
    else:
        plinktimer.stop()
        head.set_blend_shape_value(0, 1.0)
        _eyes_closed = true

func cheese_toggle():
    cheese.visible = not cheese.visible

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_4:
        toggle_roaches()
    if event is InputEventKey and event.pressed and event.keycode == KEY_5:
        eyes_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_6:
        cheese_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_7:
        halo_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_8:
        stupified()
    if event is InputEventKey and event.pressed and event.keycode == KEY_9:
        ragdoll()

func stupified():
    head.set_blend_shape_value(8, 1)
    var excitement := nia._puppy_excitement_value
    create_tween().tween_property(nia, "_puppy_excitement_value", 0, 0.5)
    await get_tree().create_timer(randf_range(0.7, 1.8)).timeout
    await ragdoll()
    head.set_blend_shape_value(8, 0)
    create_tween().tween_property(nia, "_puppy_excitement_value", excitement, 0.5)

var _is_ragdoll: bool = false
func ragdoll():
    if _is_ragdoll or nia.is_paused or nia._howling: return
    _is_ragdoll = true
    nia.stop(true)
    audio.play_snd_spatial(game.loadres("cloth_00"), nia.global_position)
    anim_tree.active = false
    phys_skel.physical_bones_start_simulation()
    var tween = create_tween()
    tween.tween_property(phys_skel, "influence", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
    tween.tween_interval(4.0)
    tween.tween_property(phys_skel, "influence", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
    await tween.finished
    phys_skel.physical_bones_stop_simulation()
    anim_tree.active = true
    nia.unconscious = false
    _is_ragdoll = false
