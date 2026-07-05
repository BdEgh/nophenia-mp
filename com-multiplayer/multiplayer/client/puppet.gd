#class_name MultiplayerPuppet
extends CharacterBody3D

var SharedPatcher = load(get_script().resource_path.get_base_dir() + "/patches/nia_patcher/shared_patcher.gd")

@export var interpolation_speed: float = 10.0
@export var rotation_speed: float = 15.0
@export var extrapolation_enabled: bool = true
@export var max_extrapolation_time: float = 0.3

var shared_patcher: Node

var target_position: Vector3 = Vector3.ZERO
var target_velocity: Vector3 = Vector3.ZERO
var target_rotation: Vector3 = Vector3.ZERO
var animation_speed: float = 1.0
var time_since_last_update: float = 0.0

var _vel_len: float = 0.0
var _is_sitting: bool = false

var chara: Node3D
var head: MeshInstance3D
var collider: CollisionShape3D
var animation_tree: AnimationTree
var anim_player: AnimationPlayer
var anim_tail: AnimationPlayer
var anim_ear_twitch: AnimationPlayer
var playback

var blob_shadow_arm: SpringArm3D
var blob_shadow: DecalCompatibility
var blob_shadow_fix: Node3D
var ray_foot: RayCast3D
var indicator_lookat: LookAtModifier3D
var indicator_marker: Marker3D
var eartimer: Timer
var headtimer: Timer
var plinktimer: Timer

func _init():
    shared_patcher = SharedPatcher.new()
    
    chara = get_node("chara")
    head = chara.get_node("Armature/Skeleton3D/head")
    collider = get_node("collider")
    collider.shape = collider.shape.duplicate()
    
    animation_tree = get_node("anim_tree")
    anim_player = get_node("anim_player")
    anim_tail = get_node("anim_tail")
    anim_ear_twitch = get_node("anim_ear_twitch")
    animation_tree.active = true
    animation_tree.set("parameters/idle_walk_run/blend_position", Vector2.ZERO)
    playback = animation_tree.get("parameters/playback")
    
    blob_shadow_arm = chara.get_node("blob_shadow_arm")
    blob_shadow_fix = chara.get_node("blob_shadow_arm/blob_shadow_fix")
    blob_shadow = chara.get_node("blob_shadow_arm/blob_shadow_fix/blob_shadow")
    ray_foot = get_node("ray_foot")
    indicator_lookat = chara.get_node("Armature/Skeleton3D/indicator_lookat")
    indicator_marker = chara.get_node("Armature/Skeleton3D/indicator_marker")
    look_at_find_timer = Timer.new()
    look_at_find_timer.wait_time = 0.5
    look_at_find_timer.autostart = true
    look_at_find_timer.timeout.connect(_find_look_at_target)
    add_child(look_at_find_timer)
    eartimer = get_node("eartimer")
    #eartimer.timeout.connect(_on_eartimer_timeout)
    headtimer = get_node("headtimer")
    #headtimer.timeout.connect(_on_headtimer_timeout)
    plinktimer = get_node("plinktimer")
    #plinktimer.timeout.connect(_on_plinktimer_timeout)

func _vanilla_ready_parts() -> void:
    pass

func _ready():
    shared_patcher.model = self
    add_child(shared_patcher)
    _vanilla_ready_parts()

func _physics_process(delta: float):
    time_since_last_update += delta
    
    var extrapolated_position = target_position
    if extrapolation_enabled and time_since_last_update < max_extrapolation_time:
        extrapolated_position = target_position + (target_velocity * time_since_last_update)
    global_position = global_position.lerp(extrapolated_position, interpolation_speed * delta)
    if chara:
        chara.rotation.y = lerp_angle(chara.rotation.y, target_rotation.y, rotation_speed * delta)
    velocity = target_velocity
    _vel_len = (abs(velocity.x) + abs(velocity.z))
    
    _angle_shadow()
    _update_look_at(delta)
    
    if playback.get_current_node() == "idle_walk_run":
        var blend_pos = Vector2(_vel_len * 0.2, 0)
        animation_tree.set("parameters/idle_walk_run/blend_position", blend_pos)
    
    move_and_slide()

func _set_sitting(sitting: bool):
    if sitting == _is_sitting:
        return
    audio.play_snd_spatial(game.loadres("cloth_00"), self.global_position, 8.0)
    _is_sitting = sitting
    if sitting:
        blob_shadow.visible = false
        collider.shape.height = 0.8
        collider.position.y = 0.66 - 0.25
    else:
        blob_shadow.visible = true
        collider.shape.height = 1.3
        collider.position.y = 0.66

func apply_state(state):
    time_since_last_update = 0.0
    
    if state.has_position():
        var pos_data = state.get_position().get_vector()
        if pos_data.size() >= 3:
            target_position = Vector3(pos_data[0], pos_data[1], pos_data[2])
            if global_position.distance_to(target_position) > 10.0:
                global_position = target_position
    
    if state.has_velocity():
        var vel_data = state.get_velocity().get_vector()
        if vel_data.size() >= 3:
            target_velocity = Vector3(vel_data[0], vel_data[1], vel_data[2])
    
    if state.has_rotation():
        var rot_data = state.get_rotation().get_vector()
        if rot_data.size() >= 3:
            target_rotation = Vector3(rot_data[0], rot_data[1], rot_data[2])
    
    if state.has_visibility():
        _apply_visibility(state.get_visibility())

    if state.has_animation():
        var anim = state.get_animation()
        var anim_name = anim.get_name()
        var anim_speed = anim.get_speed()
        var is_playing = anim.get_playing()
        
        if anim_name == "":
            return
        
        if animation_tree and is_playing:
            if playback.get_current_node() != anim_name:
                playback.travel(anim_name)
                _set_sitting(anim_name == "sit")
            if anim_speed != animation_speed:
                animation_speed = anim_speed
                animation_tree.set("parameters/TimeScale/scale", anim_speed)

func _apply_visibility(visibility):
    for path in visibility.get_hidden():
        var node = get_node_or_null(path)
        if node:
            node.visible = false
    for path in visibility.get_shown():
        var node = get_node_or_null(path)
        if node:
            node.visible = true

func teleport_to(pos: Vector3):
    global_position = pos
    target_position = pos

func _align_with_y(xform, new_y):
    xform.basis.y = new_y
    xform.basis.x = - xform.basis.z.cross(new_y)
    xform.basis = xform.basis.orthonormalized()
    return xform

func _angle_shadow():
    var _blob_shadow_size = snapped(clamp(0.8 - ((blob_shadow_arm.get_hit_length() - 0.8) / 3.0), 0.4, 0.8), 0.1)
    blob_shadow.size = Vector3(_blob_shadow_size, 1.0, _blob_shadow_size)
    if get_floor_angle(): blob_shadow_fix.global_transform = _align_with_y(blob_shadow_fix.global_transform, ray_foot.get_collision_normal())

var _howling: bool = false

func howl():
    _howling = true
    head.set_blend_shape_value(8, 1.0)
    head.set_blend_shape_value(9, 1.0)
    head.set_blend_shape_value(12, 1.0)
    audio.play_snd_spatial(game.loadres("awoo"), self.global_position, 12.0, -1.0, 0.6)
    await create_tween().tween_property( %indicator_marker, "position:z", 0.01, 1.4).set_trans(Tween.TRANS_SINE).finished
    await create_tween().tween_property( %indicator_marker, "position:z", 0.008, 0.4).set_trans(Tween.TRANS_CUBIC).set_delay(0.7).finished
    head.set_blend_shape_value(8, 0.0)
    head.set_blend_shape_value(9, 0.0)
    head.set_blend_shape_value(12, 0.0)
    _howling = false

func _on_plinktimer_timeout() -> void :
    if !_howling and playback.get_current_node() != "smile":
        head.set_blend_shape_value(0, 0.5)
        audio.play_snd_spatial(game.loadres("blink"), head.global_position)
        await get_tree().create_timer(0.1).timeout
        head.set_blend_shape_value(0, 1.0)
        
        await get_tree().create_timer(randf_range(0.05, 0.4)).timeout
        head.set_blend_shape_value(0, 0.5)
        await get_tree().create_timer(0.1).timeout
        head.set_blend_shape_value(0, 0.0)
    plinktimer.start(randf_range(0, 5.0))

var _head_timer: Tween
func _on_headtimer_timeout() -> void :
    if !_howling and !look_at_target:
        if indicator_lookat.duration != 2.0: indicator_lookat.duration = 2.0
        _head_timer = game.tween(_head_timer)
        await _head_timer.tween_property(indicator_marker, "position:x", randf_range(-0.004, 0.004), randf_range(0.2, 1.1)).set_trans(Tween.TRANS_CUBIC).finished
    #if !is_sitting && !_is_running && !_howling && !_denial && !_is_sequence:
        #_head_timer = game.tween(_head_timer)
        #await _head_timer.tween_property( %indicator_marker, "position:x", randf_range(-0.004, 0.004), randf_range(0.2, 1.1)).set_trans(Tween.TRANS_CUBIC).finished
    #else:
        #if %indicator_marker.position.x != 0:
            #_head_timer = game.tween(_head_timer)
            #await _head_timer.tween_property( %indicator_marker, "position:x", 0.0, randf_range(0.2, 1.1)).set_trans(Tween.TRANS_CUBIC).finished
    var _time: float = randf_range(0.5, 12.0)
    if game.active_stage.anomaly_occurring: _time = randf_range(0.1, 0.5)
    headtimer.start(_time)

func _on_eartimer_timeout() -> void :
    anim_ear_twitch.play("twitch")
    eartimer.start(randi_range(1, 12))

var _pawprint_queue: Array
var _step_tween: Tween
var _cd_step: bool = false
func _take_step():
    var _temp_height: float = clamp(_vel_len, 1.6, 5.0)
    var _to_play: Array
    match game.active_stage.weather:
        1:
            _to_play.append(game.loadres("step_rain"))
        2, 4:
            _to_play.append(game.loadres("step_snowy"))
    var _pitch: float = randf_range(0.9, 1.1)
    if game.active_stage.anomaly_occurring: _pitch -= 0.3
    
    _to_play.append(game.loadres("step_regular"))
    
    var _temp_floors: Array
    if ray_foot.is_colliding():
        _temp_floors.append( ray_foot.get_collider().get_parent() if ray_foot.get_collider() is not RigidBody3D else %ray_foot.get_collider())
    for _s in get_slide_collision_count():
        var _sc = get_slide_collision(_s).get_collider() if get_slide_collision(_s).get_collider() is RigidBody3D else get_slide_collision(_s).get_collider().get_parent()
        if _sc not in _temp_floors: _temp_floors.append(_sc)
    for _floor in _temp_floors:
        if _floor.has_meta("extras"):
            if _floor.get_meta("extras") is Dictionary:
                for _n in _floor.get_meta("extras"):
                    var _step = game.loadres("step_%s" % _n)
                    if _step: _to_play.append(_step)
                    if "footprint" in _n:
                        var _pawprint = game.loadres("pawprint").instantiate()
                        game.active_stage.call_deferred("add_child", _pawprint)
                        _pawprint.set_deferred("global_position", ray_foot.get_collision_point())
                        _pawprint.set_deferred("global_rotation", chara.global_rotation)
                        _pawprint_queue.append(_pawprint)
                        if len(_pawprint_queue) > 10:
                            var _temp_pawprint = _pawprint_queue.pop_front()
                            if is_instance_valid(_temp_pawprint): _temp_pawprint.remove()
    _pitch = clamp(_pitch, 0.4, 2.0)
    if velocity:
        _step_tween = game.tween(_step_tween)
        _step_tween.tween_property(chara, "position:y", 0.02 * _temp_height, 0.5 / _temp_height).set_trans(Tween.TRANS_SINE)
        _step_tween.tween_property(chara, "position:y", 0.0, 0.5 / _temp_height).set_trans(Tween.TRANS_SINE)
    for _a in _to_play:
        var _vol_adjust: float
        if _a is not Array:
            if _a.bpm:
                _vol_adjust = _a.bpm
        elif _a is Array:
            for _x in _a:
                if _x.bpm:
                    _vol_adjust = _x.bpm
        if !_cd_step: audio.play_snd_spatial(_a, self.global_position, 16.0, _pitch, clamp(randf_range(2.4, 2.8) - _vol_adjust, 0.0, 5.0))
    
    _cd_step = true
    await get_tree().create_timer(0.1).timeout
    _cd_step = false

var look_at_find_timer: Timer
var look_at_target: Node3D = null
var look_at_range: float = 5.0
var look_at_angle: float = 60.0

func _update_look_at(delta: float):
    if look_at_target:
        if indicator_lookat and indicator_marker:
            var to_target = (look_at_target.global_position - chara.global_position).normalized()
            var right = -chara.global_transform.basis.x.dot(to_target)
            var fwd = chara.global_transform.basis.z.dot(to_target)
            indicator_marker.position.x = lerp(indicator_marker.position.x, clamp(right * 0.004, -0.004, 0.004), delta * 2.0)
            indicator_marker.position.z = lerp(indicator_marker.position.z, clamp(0.010 + fwd * 0.002, 0.008, 0.012), delta * 2.0)

func _find_look_at_target():
    var best_target: Node3D = null
    var best_score: float = -1.0
    
    var targets: Array
    var mp_client = get_tree().get_first_node_in_group("mp").client
    var puppet_manager = mp_client.get_node("PuppetManager")
    if puppet_manager and puppet_manager.has_method("get_all_puppets"):
        targets = puppet_manager.get_all_puppets()
    targets.append(get_tree().get_first_node_in_group("player"))
    
    for target in targets:
        if target != self:
            if global_position.distance_to(target.global_position) > 8.0:
                continue
            var score = _calc_look_at_target_score(target)
            if score > best_score:
                best_score = score
                best_target = target
    
    if best_score > 0.0:
        look_at_target = best_target
    else:
        look_at_target = null

func _calc_look_at_target_score(candidate: Node3D) -> float:
    if not candidate:
        return -1.0
    
    var distance = global_position.distance_to(candidate.global_position)
    if distance > look_at_range:
        return -1.0
    
    var direction_to_candidate = (candidate.global_position - global_position).normalized()
    var forward = -chara.global_transform.basis.z.normalized()
    var dot_product = forward.dot(direction_to_candidate)
    var angle = rad_to_deg(acos(clamp(dot_product, -1.0, 1.0)))
    if angle > look_at_angle:
        return -1.0
    
    var distance_score = 1.0 - (distance / look_at_range)
    var angle_score = 1.0 - (angle / look_at_angle)
    return distance_score * 0.6 + angle_score * 0.4
