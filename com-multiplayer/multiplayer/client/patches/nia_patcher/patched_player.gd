extends player
class_name patched_player

var cus_ui_layer_res := load(get_script().resource_path.get_base_dir() + "/../../cus_ui_layer.tscn")
var shared_patcher_res = load(get_script().resource_path.get_base_dir() + "/shared_patcher.gd")
var meow_sfx = load(get_script().resource_path.get_base_dir() + "/items/1420-MHz/sfx/meow0.wav")

var player_sync: Node
var shared_patcher: Node

var puppet_manager: Node
var trans_vignette: Node
var trans_saturation: Node

var surprised := false
var eyes_closed := false
var default_saturation: float = 1.0

func _ready() -> void:
    shared_patcher = shared_patcher_res.new()
    shared_patcher.model = self
    add_child(shared_patcher)
    shared_patcher.cheese.visible = false
    shared_patcher.mouth.visible = true
    
    var mp_client = get_tree().get_first_node_in_group("mp").client
    puppet_manager = mp_client.get_node("PuppetManager")
    trans_vignette = get_node("indicator_layer/trans_vignette")
    trans_saturation = get_node("indicator_layer/trans_saturation")
    default_saturation = game.active_stage.environment.adjustment_saturation
    
    if game.active_stage.weather != 1: # rain
        %umbrella_rain_feedback.emitting = false
        %rain_umbrella.playing = false
    
    var cus = cus_ui_layer_res.instantiate()
    add_child(cus)
    
    if game.active_stage.sequence:
        _play_sequence()

func _play_sequence() -> void:
    _head.set_blend_shape_value(0, 1.0)
    %cam_arm.spring_length = 4.0
    %cam_arm.collision_mask = 0
    %view.fov = 50
    vignette(true)
    _is_sequence = true
    $anim_player.play("sequence_00")
    audio.play_snd_spatial(game.loadres("cloth_00"), self.global_position, 8.0)
    game.find("pause_menu").process_mode = Node.PROCESS_MODE_DISABLED
    unconscious = true
    is_paused = true
    %nia_outline_trans.show()
    %cam_box.rotation_degrees.y = 40
    create_tween().tween_property( %cam_box, "rotation_degrees:x", -2.0, 7.0).from(15.0).set_trans(Tween.TRANS_SINE)
    create_tween().tween_property( %cam_box, "rotation_degrees:y", 40.0, 8.0).from(50.0).set_trans(Tween.TRANS_SINE)
    game.loadres("mat_player").next_pass.transparency = 4
    game.loadres("mat_player").next_pass.render_priority = 30
    game.loadres("mat_player").next_pass.depth_draw_mode = 1
    await create_tween().tween_property( %nia_outline_trans.get_active_material(0), "albedo_color:a", 0.0, 5.0).from(1.0).set_delay(2.0).finished
    _head.set_blend_shape_value(0, 0.5)
    await get_tree().create_timer(1.0).timeout
    _head.set_blend_shape_value(0, 1.0)
    await get_tree().create_timer(1.0).timeout
    _head.set_blend_shape_value(0, 0.5)
    await get_tree().create_timer(1.0).timeout
    _head.set_blend_shape_value(0, 0.1)
    await get_tree().create_timer(3.0).timeout
    audio.play_snd_spatial(game.loadres("cloth_00"), self.global_position, 8.0)
    %nia_outline_trans.hide()
    unconscious = false
    is_paused = false
    game.find("pause_menu").process_mode = Node.PROCESS_MODE_INHERIT
    _is_sequence = false
    vignette(false)
    $anim_player.stop(true)
    await get_tree().create_timer(0.2).timeout
    %cam_arm.collision_mask = 17
    _take_step()
    
    game.loadres("mat_player").next_pass.render_priority = -1

func _unhandled_input(event: InputEvent) -> void:
    if get_tree().get_first_node_in_group("player") and get_tree().get_first_node_in_group("player").is_paused:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_3:
        surprised_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_4:
        eyes_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_6:
        cheese_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_7:
        halo_toggle()
    if event is InputEventKey and event.pressed and event.keycode == KEY_8:
        dizzy()
    if event is InputEventKey and event.pressed and event.keycode == KEY_9:
        ragdoll()
    if event is InputEventKey and event.pressed and event.keycode == KEY_U:
        umbrella_toggle()
    super(event)

func _howl():
    if _howling or is_sitting: return
    if game.active_stage.anomaly_occurring:
        no()
        return
    _howling = true
    var neko_value := 0
    for item in shared_patcher.neko_items:
        if item.visible: neko_value += 25
    if randi_range(0, 100) > neko_value:
        player_sync.send_action("HOWL")
        _head.set_blend_shape_value(8, 1.0)
        _head.set_blend_shape_value(9, 1.0)
        _head.set_blend_shape_value(12, 1.0)
        audio.play_snd_spatial(game.loadres("awoo"), self.global_position, 12.0, -1.0, 0.6)
        await create_tween().tween_property( %indicator_marker, "position:z", 0.01, 1.4).set_trans(Tween.TRANS_SINE).finished
        await create_tween().tween_property( %indicator_marker, "position:z", 0.008, 0.4).set_trans(Tween.TRANS_CUBIC).set_delay(0.7).finished
        game.add_stat("stat_howl")
        _head.set_blend_shape_value(8, 0.0)
        _head.set_blend_shape_value(9, 0.0)
        _head.set_blend_shape_value(12, 0.0)
    else:
        player_sync.send_action("MEOW")
        audio.play_snd_spatial(meow_sfx, self.global_position, 12.0, randf_range(1.0, 1.3), 0.6)
        await create_tween().tween_property( %indicator_marker, "position:z", 0.009, 0.4).set_trans(Tween.TRANS_SINE).finished
        game.add_stat("stat_meow")
        await create_tween().tween_property( %indicator_marker, "position:z", 0.008, 0.4).set_trans(Tween.TRANS_SINE).finished
        shared_patcher.set_surprised(true)
        await get_tree().create_timer(randf_range(1.0, 1.2)).timeout
        shared_patcher.set_surprised(false)
    _howling = false

func _ceiling_check():
    $ray_ceiling.force_raycast_update()
    if $ray_ceiling.is_colliding() and !_beneath_ceiling:
        _beneath_ceiling = true
        _ceiling_tween = game.tween(_ceiling_tween)
        _ceiling_tween.tween_method(_tween_audio_filter, 20000, 5000, 0.4).set_trans(Tween.TRANS_SINE)
        AudioServer.set_bus_effect_enabled(5, 0, true)
    elif !$ray_ceiling.is_colliding() and _beneath_ceiling:
        _beneath_ceiling = false
        _ceiling_tween = game.tween(_ceiling_tween)
        await _ceiling_tween.tween_method(_tween_audio_filter, 5000, 20000, 0.3).set_trans(Tween.TRANS_CIRC).finished
        AudioServer.set_bus_effect_enabled(5, 0, false)
    if %umbrella.visible:
        if game.active_stage.weather != 1: # rain
            %umbrella_rain_feedback.emitting = false
            %rain_umbrella.playing = false
        else:
            %umbrella_rain_feedback.emitting = !_beneath_ceiling
            %rain_umbrella.playing = !_beneath_ceiling
    if game.active_stage.weather_height:
        if _beneath_ceiling:
            if self.global_position.y >= game.active_stage.weather_height:
                if game.find("weather"):
                    game.find("weather").is_interior(false)
                    return
            if game.find("weather"): game.find("weather").is_interior(true)
        else: if game.find("weather"): game.find("weather").is_interior(false)

func _physics_process(delta: float) -> void:
    _nearby_stuff(delta)
    super(delta)

func _suppress_impact() -> float:
    if not puppet_manager: return 0.0
    var nearest := INF
    for puppet in puppet_manager.puppets.values():
        if not puppet:
            continue
        var pup_body = puppet.get_node("nia")
        nearest = min(nearest, global_position.distance_to(pup_body.global_position))
    return clampf(inverse_lerp(6.0, 2.0, nearest), 0.0, 1.0)

func _suppress_vignette(impact: float, delta: float) -> void:
    if not is_sitting or is_paused: return
    if _vignette_tween: _vignette_tween.kill()
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
    _jump_height = height

func halo_toggle():
    shared_patcher.set_halo(not shared_patcher.halo_fol.visible)
    if shared_patcher.halo_fol.visible:
        player_sync.send_action("HALO")
    else:
        player_sync.send_action("UNHALO")

func surprised_toggle():
    surprised = not surprised
    shared_patcher.set_surprised(surprised)
    if surprised:
        player_sync.send_action("WOW")
    else:
        player_sync.send_action("UNWOW")

func eyes_toggle():
    eyes_closed = not eyes_closed
    shared_patcher.set_eyes_closed(eyes_closed)
    if eyes_closed:
        player_sync.send_action("YUMENIKKI")
    else:
        player_sync.send_action("UNYUMENIKKI")

func cheese_toggle():
    shared_patcher.cheese.visible = not shared_patcher.cheese.visible

func dizzy():
    player_sync.send_action("DIZZY")
    shared_patcher.dizzy()

func ragdoll():
    if not shared_patcher.can_ragdoll(): return
    player_sync.send_action("RAGDOLL")
    shared_patcher.ragdoll()

func umbrella_toggle():
    shared_patcher.umbrella.visible = not shared_patcher.umbrella.visible
