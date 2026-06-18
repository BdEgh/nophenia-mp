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

func _ready() -> void:
    nia = game.find("player")
    
    skeleton = nia.get_node("chara/Armature/Skeleton3D")
    plinktimer = nia.get_node("plinktimer")
    anim_tree = nia.get_node("anim_tree")
    anim_player = nia.get_node("anim_player")
    
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
