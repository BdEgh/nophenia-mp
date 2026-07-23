extends Node

var phys_skel_scene = load(get_script().resource_path.get_base_dir() + "/actions/phys_skel.tscn")
var halo_attachment_scene = load(get_script().resource_path.get_base_dir() + "/items/halo/halo_attachment.tscn")
var halo_follower_scene = load(get_script().resource_path.get_base_dir() + "/items/halo/halo_follower.tscn")
var eye_fix_material = load(get_script().resource_path.get_base_dir() + "/player_mat_with_vertex_color_fix.tres")
var items_glb = load(get_script().resource_path.get_base_dir() + "/items/1420-MHz/items/items_model.glb")
var bell_scene = load(get_script().resource_path.get_base_dir() + "/items/1420-MHz/bell/bell_scene.tscn")
var bell_bone_attachment_scene = load(get_script().resource_path.get_base_dir() + "/items/1420-MHz/bell/bell_bone_attachment.tscn")

@export var model: Node

var skeleton: Skeleton3D
var head: MeshInstance3D
var plinktimer: Timer
var anim_tree: AnimationTree
var mouth: Node3D
var cheese: Node3D
var bell: Node3D

var head_mat: Material
var orig_next_pass: Material

var phys_skel: PhysicalBoneSimulator3D
var halo_att: BoneAttachment3D
var halo_fol: Node3D

var umbrella: Node3D
var umbrella_mesh: MeshInstance3D
var rain_umbrella: AudioStreamPlayer3D
var anim_umbrella: AnimationPlayer
var rain_boots: MeshInstance3D

var item_meshes: Array
var neko_items: Array
var head_items: Node3D
var heads: Array

func _ready() -> void:
    skeleton = model.get_node("chara/Armature/Skeleton3D")
    head = skeleton.get_node("head")
    head.visibility_changed.connect(_on_head_visibility_changed)
    plinktimer = model.get_node("plinktimer")
    anim_tree = model.get_node("anim_tree")
    mouth = model.get_node("cheese_position")
    cheese = mouth.get_node("grilled_cheeze")
    umbrella = model.get_node("chara/umbrella")
    umbrella_mesh = model.get_node("chara/umbrella/umbrella")
    rain_umbrella = model.get_node("chara/umbrella/umbrella/rain_umbrella")
    anim_umbrella = model.get_node("anim_umbrella")
    rain_boots = model.get_node("chara/Armature/Skeleton3D/rain_boots")
    _setup_unique_material()
    
    phys_skel = phys_skel_scene.instantiate()
    skeleton.add_child(phys_skel)
    
    halo_att = halo_attachment_scene.instantiate()
    skeleton.add_child(halo_att)
    halo_fol = halo_follower_scene.instantiate()
    halo_fol.target_node = halo_att.get_node("halo_marker")
    halo_fol.visible = false
    model.add_child(halo_fol)
    
    var items_root: Node3D = items_glb.instantiate()
    var items_skel = items_root.get_node("Armature/Skeleton3D")
    heads = ["head", "head for hats", "Short hair head", "Short hair head for hats"]
    head_items = Node3D.new()
    head_items.name = "HeadItems"
    skeleton.add_child(head_items)
    for child: MeshInstance3D in items_skel.get_children():
        var new_mesh = child.duplicate()
        if new_mesh.name in ["Hat", "Paws"]:
            neko_items.append(new_mesh)
        if new_mesh.name in ["Hat", "Glasses round", "Glasses red"]:
            head_items.add_child(new_mesh)
        else:
            skeleton.add_child(new_mesh)
        new_mesh.skeleton = new_mesh.get_path_to(skeleton)
        item_meshes.append(new_mesh)
    items_root.queue_free()
    
    bell = bell_scene.instantiate()
    model.add_child(bell)
    skeleton.add_child(bell_bone_attachment_scene.instantiate())
    var bell_mesh = bell.get_node("Armature_001/Skeleton3D/bell")
    bell_mesh.name = "Bell"
    item_meshes.append(bell_mesh)
    var blue_bell_mesh = bell.get_node("Armature_001/Skeleton3D/bell blue")
    blue_bell_mesh.name = "Blue Bell"
    item_meshes.append(blue_bell_mesh)
    #if rain_boots:
        #item_meshes.append(rain_boots)
    if umbrella:
        #item_meshes.append(umbrella_mesh)
        umbrella.visibility_changed.connect(_on_umbrella_visibility_changed.bind(umbrella))
        #umbrella_mesh.visibility_changed.connect(_on_umbrella_visibility_changed.bind(umbrella_mesh))
    
    _stage_lit_items(item_meshes)
    _stage_lit_items([head])
    
    for i in item_meshes:
        i.visibility_changed.connect(_on_custom_item_visibility_changed.bind(i))
        i.visible = false

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
    await get_tree().create_timer(0.6).timeout
    _stage_lit_items([head])

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

func _on_umbrella_visibility_changed(umbrella_node: Node3D) -> void:
    _toggle_umbrella(umbrella_node.visible)

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

func _on_custom_item_visibility_changed(_mesh: MeshInstance3D):
    var stretch_down = Vector3(randf_range(1.1, 1.25), 1.0, randf_range(0.75, 0.85))
    var stretch_up = Vector3(randf_range(0.85, 0.9), 1.0, randf_range(1.1, 1.25))
    await create_tween().tween_property(skeleton, "scale", stretch_up, 0.15) \
        .from(stretch_down).finished
    await create_tween().tween_property(skeleton, "scale", Vector3.ONE, 0.1).finished
    #await create_tween().tween_property(mesh, "scale", Vector3.ONE, 0.25).from(Vector3(randf_range(1.3, 1.6), randf_range(0.3, 0.9), randf_range(1.3, 1.6))).finished

func _on_head_visibility_changed():
    head_items.visible = head.visible

func _stage_lit_items(items: Array) -> void:
    for _n in items:
        if is_instance_valid(_n):
            if _n is MeshInstance3D:
                if _n.get_active_material(0).next_pass:
                    _n.get_active_material(0).next_pass.albedo_color = game.active_stage_light
                else:
                    for _i in _n.get_surface_override_material_count():
                        if _n.get_active_material(_i) is StandardMaterial3D:
                            _n.get_active_material(_i).albedo_color.r = game.active_stage_light.r
                            _n.get_active_material(_i).albedo_color.g = game.active_stage_light.g
                            _n.get_active_material(_i).albedo_color.b = game.active_stage_light.b
                        else:
                            if _n.get_active_material(_i) is ShaderMaterial:
                                if _n.get_active_material(_i).get_shader_parameter("color2"):
                                    _n.get_active_material(_i).set_shader_parameter("color2", game.active_stage_light)
            elif _n is CPUParticles3D:
                if _n.is_in_group("stage_lit_particle_color"):
                    _n.color = game.active_stage_light
                else:
                    if _n.material_override is StandardMaterial3D: _n.material_override.albedo_color = game.active_stage_light
            elif _n is Light3D:
                _n.light_color = game.active_stage_light.lightened(0.4)
            else:
                if _n.get("color"): _n.color = game.active_stage_light
                if _n.get("modulate"): _n.modulate = game.active_stage_light
