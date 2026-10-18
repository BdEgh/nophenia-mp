extends Node3D

@export var ui: Control

@export var pause_menu: CanvasLayer

@onready var mp_animation_player: AnimationPlayer = %mp_animation_player

var menu_cam: Camera3D
var shown := false
var zoomed := true
var http: HTTPRequest

func _ready() -> void:
    menu_cam = pause_menu.get_node("menu_box/menu_view/menu_cam")
    http = HTTPRequest.new()
    http.use_threads = true
    add_child(http)

func phone_feedback():
    #add_ghosting()
    #_play_keychain_snd(true)
    await create_tween().tween_property( %phone, "scale", Vector3.ONE, 0.1).from(Vector3(0.96, 1.02, 1.01)).set_trans(Tween.TRANS_SINE).finished

#func _adjust_brightness():
    #%screen_texture.material_override.emission_energy_multiplier = config.phone_screen_brightness
    #_cam_screen.material_override.emission_energy_multiplier = config.phone_screen_brightness
    #%phone_light.light_energy = 0.02 + (config.phone_screen_brightness / 2.0)

func _set_player_input_enabled(enabled: bool) -> void:
    get_tree().get_first_node_in_group("player").set_process_unhandled_input(enabled)
    get_tree().get_first_node_in_group("player").is_paused = not enabled
    if !enabled:
        get_tree().get_first_node_in_group("player").velocity = Vector3.ZERO
        var anim_tree = get_tree().get_first_node_in_group("player").get_node_or_null("anim_tree")
        if anim_tree:
            anim_tree.set("parameters/idle_walk_run/blend_position", Vector2.ZERO)

func _animate_camera(camera: Node3D, target_x: float):
    create_tween().tween_property(camera, "position:x", target_x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _phone_clam():
    var screen = pause_menu.get_node("screen")
    var screen_view = pause_menu.get_node("screen/screen_view")
    var phone_anim = pause_menu.get_node("menu_box/menu_view/phone_anim")
    screen_view.gui_release_focus()
    phone_anim.play_backwards("clam")
    audio.play_snd(game.loadres("phone_off"), 1.0, 0.7)
    await phone_anim.animation_finished
    screen.process_mode = Node.PROCESS_MODE_DISABLED
    screen.hide()

func _make_request_and_add_buttons():
    http.cancel_request()
    var remote_loader = get_tree().get_first_node_in_group("mp").remote_loader
    var url = remote_loader.addr.path_join("/get_stages")
    var err := http.request(url)
    if err != OK:
        ModLoaderLog.error("request failed", self.name)
        return
    var response = await http.request_completed
    var body : PackedByteArray = response[3]
    var huy = body.get_string_from_ascii()
    var json = JSON.new()
    var error = json.parse(huy)
    
    if typeof(json.data) != TYPE_ARRAY:
        ModLoaderLog.error("request failed", self.name)
        return
    for map in json.data:
        ui.add_map(map)

func _add_offline_buttons():
    var remote_loader = get_tree().get_first_node_in_group("mp").remote_loader
    for file in DirAccess.get_files_at(remote_loader.remote_stages_physical):
        var map := {"name": file.get_basename()}
        ui.add_map(map)

func popup():
    self.visible = true
    pause_menu.set_process_unhandled_input(false)
    _make_request_and_add_buttons()
    _add_offline_buttons()
    ui.show_map_list()
    
    var menu_box: SubViewportContainer = pause_menu.get_node("menu_box")
    menu_box.mouse_filter = Control.MOUSE_FILTER_PASS
    var menu_view: SubViewport = pause_menu.get_node("menu_box/menu_view")
    menu_view.physics_object_picking = true
    _phone_clam()
    set_physics_process(true)
    
    shown = true
    mp_animation_player.play("popup", 0.2)
    
    #Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    #_set_player_input_enabled(false)
    
    var cam_arm = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm")
    var move_multiplier = (cam_arm.spring_length - 0.8) * 0.45
    var camera = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm/cam_arm_fix/view")
    _animate_camera(camera, move_multiplier)
    
    var light = pause_menu.get_node("menu_box/menu_view/phone_light")
    create_tween().tween_property(light, "position", Vector3(-0.102, 2.311, -3.805), 0.3).set_trans(Tween.TRANS_CIRC)

func _phone_open():
    var screen = pause_menu.get_node("screen")
    var phone_anim = pause_menu.get_node("menu_box/menu_view/phone_anim")
    screen.show()
    phone_anim.play("clam")
    var maps_button = pause_menu.find_child("option_user_maps", true, false)
    maps_button.grab_focus()
    await phone_anim.animation_finished
    screen.process_mode = Node.PROCESS_MODE_INHERIT

func back_to_phone():
    var menu_box: SubViewportContainer = pause_menu.get_node("menu_box")
    menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var menu_view: SubViewport = pause_menu.get_node("menu_box/menu_view")
    menu_view.physics_object_picking = false
    _phone_open()
    
    shown = false
    mp_animation_player.play("away_zoom_in" if zoomed else "away_zoom_out", 0.2)
    zoomed = true
    set_physics_process(false)
    
    var camera = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm/cam_arm_fix/view")
    _animate_camera(camera, 0.0)
    
    var light = pause_menu.get_node("menu_box/menu_view/phone_light")
    create_tween().tween_property(light, "position", Vector3(-0.912, 2.311, -0.425), 0.3).set_trans(Tween.TRANS_CIRC)

    pause_menu.set_process_unhandled_input(true)
    await mp_animation_player.animation_finished
    if shown == false:
        self.visible = false

func close():
    var menu_box: SubViewportContainer = pause_menu.get_node("menu_box")
    menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var menu_view: SubViewport = pause_menu.get_node("menu_box/menu_view")
    menu_view.physics_object_picking = false
    
    shown = false
    mp_animation_player.play("away_zoom_in" if zoomed else "away_zoom_out", 0.2)
    zoomed = true
    
    var camera = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm/cam_arm_fix/view")
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _animate_camera(camera, 0.0)
    
    var light = pause_menu.get_node("menu_box/menu_view/phone_light")
    create_tween().tween_property(light, "position", Vector3(-0.912, 2.311, -0.425), 0.3).set_trans(Tween.TRANS_CIRC)
    _set_player_input_enabled(true)
    
    if game.nia:
        if !game.nia.is_sitting: game.nia.vignette(false)
        game.nia.stop(false)
    await get_tree().process_frame
    game.nia.is_paused = false
    set_physics_process(false)
    
    pause_menu.set_process_unhandled_input(true)
    pause_menu._is_open = false
    
    OS.low_processor_usage_mode = false
    ui.queue_free_maps()

func zoom_in():
    zoomed = true
    mp_animation_player.play_backwards("zoom_out", 0.2)

func zoom_out():
    zoomed = false
    mp_animation_player.play("zoom_out", 0.2)

func set_influence(influence: float, weight: float) -> void:
    for i: SpringBoneSimulator3D in [%sbs_ear1, %sbs_ear2, %sbs_player, %sbs_wires]:
        i.influence = lerp(i.influence, influence, weight)

func _input(event):
    #if shown and event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
    if shown and event is InputEventKey and event.is_action_pressed("menu"):
        if ui.map_info_menu.visible:
            ui.show_map_list()
            zoom_in()
        else:
            back_to_phone()
            #close()
    if shown and event is InputEventKey and ui.map_info_menu.visible and event.is_action_pressed("ui_accept"):
        var remote_loader = get_tree().get_first_node_in_group("mp").remote_loader
        remote_loader.change_stage(ui.last_selected.name)
    
    #if event is InputEventKey and event.pressed and event.keycode == KEY_X:
        #if not shown:
            #popup()
        #else:
            #close()
    #if event is InputEventKey and event.pressed and event.keycode == KEY_C:
        #if zoomed:
            #zoom_out()
        #else:
            #zoom_in()

func _physics_process(_delta: float) -> void :
    var weight = 1 - exp(-5 * _delta)
    if not mp_animation_player.is_playing():
        set_influence(1., weight)
    else:
        set_influence(0.2, 1.)
    
    if shown:
        var _sens: Vector2 = Vector2(0.01, 0.005) if zoomed else Vector2(0.02, 0.02)
        var _mouse: Vector2 = game.mouse_position()
        var _cam_project: Vector2 = menu_cam.unproject_position(%center.global_position)
        %music_player.rotation_degrees = lerp( %music_player.rotation_degrees,
            Vector3(
                (((_mouse.y) * _sens.y) - _cam_project.y * _sens.y),
                (((_mouse.x) * _sens.x) - _cam_project.x * _sens.x),
                0
            ), 0.2)
        %music_player.rotation_degrees.y = clamp( %music_player.rotation_degrees.y, -24.0, 24.0)
