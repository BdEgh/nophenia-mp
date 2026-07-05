extends Node

var phys_skel_scene = load(get_script().resource_path.get_base_dir() + "/actions/phys_skel.tscn")
var halo_attachment_scene = load(get_script().resource_path.get_base_dir() + "/items/halo/halo_attachment.tscn")
var halo_follower_scene = load(get_script().resource_path.get_base_dir() + "/items/halo/halo_follower.tscn")
var eye_fix_material = load(get_script().resource_path.get_base_dir() + "/player_mat_with_vertex_color_fix.tres")
var bp_meshes_scene = load(get_script().resource_path.get_base_dir() + "/items/1420-MHz/meshes.tscn")
var bp_attachments_scene = load(get_script().resource_path.get_base_dir() + "/items/1420-MHz/attachments.tscn")

@export var model: Node

var skeleton: Skeleton3D
var head: MeshInstance3D
var plinktimer: Timer
var anim_tree: AnimationTree
var mouth: Node3D
var cheese: Node3D

var head_mat: Material
var orig_next_pass: Material

var phys_skel: PhysicalBoneSimulator3D
var halo_att: BoneAttachment3D
var halo_fol: Node3D
var bp_meshes: Node3D
var chest_bone: int

var umbrella: Node3D
var umbrella_mesh: MeshInstance3D
var rain_umbrella: AudioStreamPlayer3D
var anim_umbrella: AnimationPlayer
var rain_boots: MeshInstance3D

func _ready() -> void:
    skeleton = model.get_node("chara/Armature/Skeleton3D")
    head = skeleton.get_node("head")
    plinktimer = model.get_node("plinktimer")
    anim_tree = model.get_node("anim_tree")
    mouth = model.get_node("cheese_position")
    cheese = mouth.get_node("grilled_cheeze")
    umbrella = model.get_node("chara/umbrella")
    umbrella_mesh = model.get_node("chara/umbrella/umbrella")
    rain_umbrella = model.get_node("chara/umbrella/umbrella/rain_umbrella")
    anim_umbrella = model.get_node("anim_umbrella")
    rain_boots = model.get_node("chara/Armature/Skeleton3D/rain_boots")

    phys_skel = phys_skel_scene.instantiate()
    skeleton.add_child(phys_skel)

    halo_att = halo_attachment_scene.instantiate()
    skeleton.add_child(halo_att)
    halo_fol = halo_follower_scene.instantiate()
    halo_fol.target_node = halo_att.get_node("halo_marker")
    halo_fol.visible = false
    model.add_child(halo_fol)
    
    bp_meshes = bp_meshes_scene.instantiate()
    bp_meshes.visible = false
    model.add_child(bp_meshes)
    var attachments = bp_attachments_scene.instantiate()
    for child in attachments.get_children():
        attachments.remove_child(child)
        skeleton.add_child(child)
    attachments.queue_free()
    chest_bone = skeleton.find_bone("Chest")
    
    _setup_unique_material()

func _physics_process(_delta):
    if bp_meshes:
        bp_meshes.scale = skeleton.get_bone_pose_scale(chest_bone)
    _umbrella_watcher()

var _mat_next_pass: StandardMaterial3D

func _setup_unique_material():
    var shared_mat = game.loadres("mat_player")
    if not shared_mat:
        return
    
    orig_next_pass = shared_mat.next_pass
    var unique_mat: StandardMaterial3D = shared_mat.duplicate()
    if shared_mat.next_pass:
        unique_mat.next_pass = shared_mat.next_pass.duplicate()
    _mat_next_pass = unique_mat.next_pass
    for mesh in skeleton.find_children("*", "MeshInstance3D", true, false):
        for i in mesh.get_surface_override_material_count():
            if mesh.get_active_material(i) == shared_mat:
                mesh.set_surface_override_material(i, unique_mat)
    head_mat = head.get_active_material(0)

func damage(with_sound: bool = false):
    if _mat_next_pass:
        _mat_next_pass.albedo_color = Color("80131cff")
    if with_sound:
        audio.play_snd_spatial(game.loadres("damage"), head.global_position, 4.0, -1.0, 0.7)
        audio.play_snd_spatial(game.loadres("nia_damage"), head.global_position, 4.0, -1.0, 0.1)

func get_roaches() -> bool:
    return model.get_node("chara/blob_shadow_arm/bug_step").visible

func set_roaches(visible: bool) -> void:
    model.get_node("chara/blob_shadow_arm/bug_step").visible = visible

func set_halo(on: bool) -> void:
    halo_fol.visible = on

func set_surprised(on: bool) -> void:
    if on:
        head.set_blend_shape_value(7, 1.0)
        if head_mat:
            if _mat_next_pass is StandardMaterial3D:
                eye_fix_material.set_shader_parameter("albedo", _mat_next_pass.albedo_color)
            head_mat.next_pass = eye_fix_material
    else:
        head.set_blend_shape_value(7, 0.0)
        if head_mat:
            head_mat.next_pass = _mat_next_pass

func set_eyes_closed(closed: bool) -> void:
    if closed:
        plinktimer.stop()
        head.set_blend_shape_value(0, 1.0)
    else:
        plinktimer.start()
        head.set_blend_shape_value(0, 0)

func dizzy():
    head.set_blend_shape_value(8, 1)
    var has_excitement = "_puppy_excitement_value" in model
    var excitement = model._puppy_excitement_value if has_excitement else 0.0
    if has_excitement:
        create_tween().tween_property(model, "_puppy_excitement_value", 0, 0.5)
    await get_tree().create_timer(randf_range(0.7, 1.8)).timeout
    await ragdoll()
    head.set_blend_shape_value(8, 0)
    if has_excitement:
        create_tween().tween_property(model, "_puppy_excitement_value", excitement, 0.5)

func can_ragdoll() -> bool:
    if _is_ragdoll: return false
    if "is_paused" in model and model.is_paused: return false
    if "_howling" in model and model._howling: return false
    return true

var _is_ragdoll: bool = false
func ragdoll():
    if not can_ragdoll(): return
    _is_ragdoll = true
    if model.has_method("stop"):
        model.stop(true)
    audio.play_snd_spatial(game.loadres("cloth_00"), model.global_position)
    anim_tree.active = false
    phys_skel.physical_bones_start_simulation()
    var tween = create_tween()
    tween.tween_property(phys_skel, "influence", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
    tween.tween_interval(4.0)
    tween.tween_property(phys_skel, "influence", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
    await tween.finished
    phys_skel.physical_bones_stop_simulation()
    anim_tree.active = true
    if "unconscious" in model:
        model.unconscious = false
    _is_ragdoll = false

var _umbrella_toggled := true
func _umbrella_watcher() -> void:
    if _umbrella_toggled and not umbrella.visible:
        _umbrella_toggled = false
        _toggle_umbrella(false)
    if not _umbrella_toggled and umbrella.visible:
        _umbrella_toggled = true
        _toggle_umbrella(true)

func _tween_umbrella(_value):
    umbrella_mesh.set_blend_shape_value(0, _value)

func _toggle_umbrella(_open: bool = true):
    if ! umbrella.visible:
        rain_boots.visible = false
        rain_umbrella.playing = false
        anim_umbrella.active = false
        return
    
    rain_boots.visible = true
    rain_umbrella.playing = true
    anim_umbrella.active = true
    anim_umbrella.play("hold_umbrella")
    create_tween().tween_method(_tween_umbrella, 1.0 * int(_open), 1.0 * int( !_open), 1.1).set_trans(Tween.TRANS_BOUNCE)
    audio.play_snd_spatial(game.loadres("umbrella_open"), umbrella_mesh.global_position, 16.0)
