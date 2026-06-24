extends Node

var PhysSkel = load(get_script().resource_path.get_base_dir() + "/actions/phys_skel.tscn")
var HaloAttachment = load(get_script().resource_path.get_base_dir() + "/items/halo/halo_attachment.tscn")
var HaloFollower = load(get_script().resource_path.get_base_dir() + "/items/halo/halo_follower.tscn")
var EyeFixMat = load(get_script().resource_path.get_base_dir() + "/player_mat_with_vertex_color_fix.tres")
var BPMeshes = load(get_script().resource_path.get_base_dir() + "/items/1420-MHz/meshes.tscn")
var BPAttachments = load(get_script().resource_path.get_base_dir() + "/items/1420-MHz/attachments.tscn")

var model: Node

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

func apply_patches(model_node):
    model = model_node
    skeleton = model.get_node("chara/Armature/Skeleton3D")
    head = skeleton.get_node("head")
    plinktimer = model.get_node("plinktimer")
    anim_tree = model.get_node("anim_tree")
    mouth = model.get_node("cheese_position")
    cheese = mouth.get_node("grilled_cheeze")
    head_mat = head.get_active_material(0)
    if head_mat:
        orig_next_pass = head_mat.next_pass

    phys_skel = PhysSkel.instantiate()
    skeleton.add_child(phys_skel)

    halo_att = HaloAttachment.instantiate()
    skeleton.add_child(halo_att)
    halo_fol = HaloFollower.instantiate()
    halo_fol.target_node = halo_att.get_node("halo_marker")
    halo_fol.visible = false
    model.add_child(halo_fol)
    
    bp_meshes = BPMeshes.instantiate()
    bp_meshes.visible = false
    model.add_child(bp_meshes)
    var attachments = BPAttachments.instantiate()
    for child in attachments.get_children():
        attachments.remove_child(child)
        skeleton.add_child(child)
    attachments.queue_free()
    chest_bone = skeleton.find_bone("Chest")

func _physics_process(_delta):
    if bp_meshes:
        bp_meshes.scale = skeleton.get_bone_pose_scale(chest_bone)

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
            if orig_next_pass is StandardMaterial3D:
                EyeFixMat.set_shader_parameter("albedo", orig_next_pass.albedo_color)
            head_mat.next_pass = EyeFixMat
    else:
        head.set_blend_shape_value(7, 0.0)
        if head_mat:
            head_mat.next_pass = orig_next_pass

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
