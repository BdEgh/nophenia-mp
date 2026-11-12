extends Node3D

@export var ui: Control

@export var pause_menu: CanvasLayer

@onready var mp_animation_player: AnimationPlayer = %mp_animation_player
@onready var light: OmniLight3D = %light
@onready var const_light: OmniLight3D = %const_light

var mp_popup_sound = load(get_script().resource_path.get_base_dir() + "/resources/audio/mp_popup.ogg")

var menu_cam: Camera3D
var shown := false
var http: HTTPRequest
var info_mode: bool = false
var force_close: bool = false

func _ready() -> void:
    menu_cam = pause_menu.get_node("menu_box/menu_view/menu_cam")
    http = HTTPRequest.new()
    http.use_threads = true
    add_child(http)
    
    button_mapping = { Buttons.Up: wheel_up, Buttons.Left: wheel_left, Buttons.Right: wheel_right, Buttons.Down: wheel_down, Buttons.Middle: middle }
    button_tweens = { wheel_up: null, wheel_left: null, wheel_down: null, wheel_right: null, middle: null }
    button_impact = {
        Buttons.Up: Vector3(deg_to_rad(3.), 0., 0.),
        Buttons.Left: Vector3(deg_to_rad(6.), deg_to_rad(-6.), 0.),
        Buttons.Right: Vector3(deg_to_rad(6.), deg_to_rad(6.), 0.),
        Buttons.Down: Vector3(deg_to_rad(9.), 0., 0.),
        Buttons.Middle: Vector3(deg_to_rad(6.), 0., 0.)
    }

func _input(event):
    if shown:
        if ui.map_info_menu.visible:
            if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
                if event.pressed:
                    impact(hover_on)
                else:
                    press(hover_on)
            if event is InputEventKey:
                var chat = get_tree().get_first_node_in_group("mp").chat.get_node("ChatUI")
                if chat.visible:
                    return
                if event.is_action_pressed("ui_accept"):
                    if hover_on != Buttons.None:
                        impact(hover_on)
                        hover_button(hover_on)
                    else:
                        impact(Buttons.Middle)
                        hover_button(Buttons.Middle)
                elif event.is_action_released("ui_accept"):
                    if hover_on != Buttons.None:
                        press(hover_on)
                    else:
                        unhover_button(Buttons.Middle)
                        press(Buttons.Middle)
                else:
                    var mapping = {"ui_up": Buttons.Up, "ui_down": Buttons.Down, "ui_left": Buttons.Left, "ui_right": Buttons.Right}
                    for action in mapping:
                        if event.is_action_pressed(action):
                            impact(mapping[action])
                            hover_button(mapping[action])
                        if event.is_action_released(action):
                            unhover_button(mapping[action])
                            press(mapping[action])

        if event is InputEventKey and event.is_action_pressed("menu"):
            if info_mode == false: # opened from the phone
                if ui.options.visible:
                    ui.options_button.button_pressed = false
                elif not ui.map_info_menu.visible:                  
                    back_to_phone()
                elif ui.map_info_menu.visible:
                    ui.show_map_list()
                    zoom_in()
            else: # opened from the chat
                if ui.options.visible:
                    ui.options_button.button_pressed = false
                elif not ui.map_info_menu.visible or force_close:
                    close()
                elif ui.map_info_menu.visible:
                    ui.show_map_list()
                    zoom_in()

func feedback():
    ui.add_ghosting()
    #_play_keychain_snd(true)
    await create_tween().tween_property(%music_player, "scale", Vector3.ONE, 0.2).from(Vector3(0.98, 1.02, 1.01)).set_trans(Tween.TRANS_SINE).finished

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
        printerr("request failed")
        return []
    var response = await http.request_completed
    var body : PackedByteArray = response[3]
    var huy = body.get_string_from_ascii()
    var data = JSON.parse_string(huy)
    
    if typeof(data) != TYPE_ARRAY:
        printerr("response content is weird")
        return []
    for map in data:
        if typeof(map) != TYPE_DICTIONARY:
            continue
        ui.add_map(map)

var thread: Thread
func add_offline_maps():
    var maps: Array
    var remote_loader = get_tree().get_first_node_in_group("mp").remote_loader
    for file in DirAccess.get_files_at(remote_loader.remote_stages_physical):
        var file_path: String = remote_loader.remote_stages_physical.path_join(file)
        var map := {"name": file.get_basename(), "local_md5": FileAccess.get_md5(file_path)}
        maps.append(map)
    call_deferred("_on_maps_loaded", maps)

func _on_maps_loaded(maps: Array) -> void:
    for map in maps:
        ui.add_map(map)
    ui.update_sort_pressed()

func _exit_tree() -> void:
    if thread and thread.is_started():
        thread.wait_to_finish()

func add_maps(_stage = null):
    thread = Thread.new()
    thread.start(add_offline_maps)
    await _make_request_and_add_buttons()
    thread.wait_to_finish()
    if _stage:
        ui.add_map_raw(_stage)

func popup():
    set_process_input(true)
    info_mode = false
    force_close = false
    
    self.visible = true
    ui.visible = true
    pause_menu.set_process_unhandled_input(false)
    
    ui.show_map_list()
    add_maps()
    
    var menu_box: SubViewportContainer = pause_menu.get_node("menu_box")
    menu_box.mouse_filter = Control.MOUSE_FILTER_PASS
    var menu_view: SubViewport = pause_menu.get_node("menu_box/menu_view")
    menu_view.physics_object_picking = true
    _phone_clam()
    set_physics_process(true)
    
    shown = true
    audio.play_snd(mp_popup_sound, -1.0, 0.2)
    mp_animation_player.play("popup", 0.2)
    
    #Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    #_set_player_input_enabled(false)
    
    var cam_arm = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm")
    var move_multiplier = (cam_arm.spring_length - 0.8) * 0.45
    var camera = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm/cam_arm_fix/view")
    _animate_camera(camera, move_multiplier)
    
    var phone_light = pause_menu.get_node("menu_box/menu_view/phone_light")
    create_tween().tween_property(phone_light, "light_energy", 0., 0.3).set_trans(Tween.TRANS_CIRC)
    create_tween().tween_property(light, "light_energy", 1., 0.3).set_trans(Tween.TRANS_CIRC)
    create_tween().tween_property(const_light, "light_energy", 1., 0.3).set_trans(Tween.TRANS_CIRC)

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
    set_process_input(false)
    var menu_box: SubViewportContainer = pause_menu.get_node("menu_box")
    menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var menu_view: SubViewport = pause_menu.get_node("menu_box/menu_view")
    menu_view.physics_object_picking = false
    _phone_open()
    
    shown = false
    audio.play_snd(mp_popup_sound, -1.0, 0.2)
    mp_animation_player.play("away_zoom_in" if ui.map_info_menu.visible else "away_zoom_out", 0.2)
    set_physics_process(false)
    
    var camera = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm/cam_arm_fix/view")
    _animate_camera(camera, 0.0)
    
    var phone_light = pause_menu.get_node("menu_box/menu_view/phone_light")
    create_tween().tween_property(phone_light, "light_energy", .1, 0.3).set_trans(Tween.TRANS_CIRC)
    create_tween().tween_property(light, "light_energy", 0., 0.3).set_trans(Tween.TRANS_CIRC)
    create_tween().tween_property(const_light, "light_energy", 0., 0.3).set_trans(Tween.TRANS_CIRC)
    
    pause_menu.set_process_unhandled_input(true)
    await mp_animation_player.animation_finished
    if shown == false:
        self.visible = false
        ui.visible = true

func popup_stage_info(_stage: String):
    set_process_input(true)
    info_mode = true
    force_close = true
    if self.visible: return
    print("INFO")
    
    pause_menu.visible = true
    pause_menu.get_node("menu_box/menu_view/phone_pos").visible = false
    pause_menu.set_process_unhandled_input(false)
    self.visible = true
    ui.visible = true
    add_maps(_stage)
    ui.show_map_info()
    
    var menu_box: SubViewportContainer = pause_menu.get_node("menu_box")
    menu_box.mouse_filter = Control.MOUSE_FILTER_PASS
    var menu_view: SubViewport = pause_menu.get_node("menu_box/menu_view")
    menu_view.physics_object_picking = true
    set_physics_process(true)
    
    var cam_arm = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm")
    var move_multiplier = (cam_arm.spring_length - 0.8) * 0.45
    var camera = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm/cam_arm_fix/view")
    _animate_camera(camera, move_multiplier)
    
    var nia = game.find("player")
    nia.vignette(true)
    nia.stop()
    nia.is_paused = true
    
    shown = true
    audio.play_snd(mp_popup_sound, -1.0, 0.2)
    mp_animation_player.play("popup_zoom_out", 0.2)
    
    var phone_light = pause_menu.get_node("menu_box/menu_view/phone_light")
    create_tween().tween_property(phone_light, "light_energy", 0., 0.3).set_trans(Tween.TRANS_CIRC)
    create_tween().tween_property(light, "light_energy", 1., 0.3).set_trans(Tween.TRANS_CIRC)
    create_tween().tween_property(const_light, "light_energy", 1., 0.3).set_trans(Tween.TRANS_CIRC)

func close():
    set_process_input(false)
    var menu_box: SubViewportContainer = pause_menu.get_node("menu_box")
    menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var menu_view: SubViewport = pause_menu.get_node("menu_box/menu_view")
    menu_view.physics_object_picking = false
    shown = false
    
    var camera = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm/cam_arm_fix/view")
    Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    _animate_camera(camera, 0.0)
    
    var phone_light = pause_menu.get_node("menu_box/menu_view/phone_light")
    create_tween().tween_property(phone_light, "light_energy", .1, 0.3).set_trans(Tween.TRANS_CIRC)
    create_tween().tween_property(light, "light_energy", 0., 0.3).set_trans(Tween.TRANS_CIRC)
    create_tween().tween_property(const_light, "light_energy", 0., 0.3).set_trans(Tween.TRANS_CIRC)
    _set_player_input_enabled(true)
    
    var nia = game.find("player")
    if nia:
        if !nia.is_sitting: nia.vignette(false)
        nia.stop(false)
        nia.is_paused = false
    mp_animation_player.play("away_zoom_in" if ui.map_info_menu.visible else "away_zoom_out", 0.2)
    await mp_animation_player.animation_finished
    await get_tree().process_frame
    set_physics_process(false)
    
    ui.queue_free_maps()
    pause_menu.get_node("menu_box/menu_view/phone_pos").visible = true
    pause_menu.visible = false
    pause_menu.set_process_unhandled_input(true)
    self.visible = false
    ui.visible = false

func zoom_in():
    audio.play_snd(mp_popup_sound, -1.0, 0.2)
    mp_animation_player.play_backwards("zoom_out", 0.2)
    force_close = false

func zoom_out():
    audio.play_snd(mp_popup_sound, -1.0, 0.2)
    mp_animation_player.play("zoom_out", 0.2)

func set_influence(influence: float, weight: float) -> void:
    for i: SpringBoneSimulator3D in [%sbs_ear1, %sbs_ear2, %sbs_player, %sbs_wires]:
        i.influence = lerp(i.influence, influence, weight)

func _physics_process(_delta: float) -> void :
    var weight = 1 - exp(-5 * _delta)
    if not mp_animation_player.is_playing():
        set_influence(1., weight)
    else:
        set_influence(0.2, 1.)
    
    if shown:
        var proj = menu_cam.project_position(game.mouse_position(), 10)
        light.position.x = -proj.x - 1.5
        light.position.y = proj.y
        
        var _sens: Vector2 = Vector2(0.01, 0.005) if ui.map_info_menu.visible else Vector2(0.02, 0.02)
        var _mouse: Vector2 = game.mouse_position()
        var _cam_project: Vector2 = menu_cam.unproject_position(%center.global_position)
        %music_player.rotation_degrees = lerp( %music_player.rotation_degrees,
            Vector3(
                (((_mouse.y) * _sens.y) - _cam_project.y * _sens.y),
                (((_mouse.x) * _sens.x) - _cam_project.x * _sens.x),
                0
            ), 0.2)
        %music_player.rotation_degrees.y = clamp( %music_player.rotation_degrees.y, -24.0, 24.0)

#region Buttons
@onready var wheel_up: MeshInstance3D = %wheel_up
@onready var wheel_left: MeshInstance3D = %wheel_left
@onready var wheel_down: MeshInstance3D = %wheel_down
@onready var wheel_right: MeshInstance3D = %wheel_right
@onready var middle: MeshInstance3D = %middle

enum Buttons { None, Middle, Up, Down, Left, Right }
var button_mapping: Dictionary
var button_tweens: Dictionary
var button_impact: Dictionary
var hover_on: Buttons

func press(type: Buttons) -> void:
    if type == Buttons.None:
        return
    ui.on_button_pressed()
    match type:
        Buttons.Up:
            ui.show_map_list()
            zoom_in()
        Buttons.Left:
            ui.prev_map_info()
        Buttons.Right:
            ui.next_map_info()
        Buttons.Down:
            ui.chat_share()
        Buttons.Middle:
            ui.select_map()

func impact(type: Buttons) -> void:
    if not button_impact.has(type):
        return
    
    var rot = button_impact[type]
    rot *= randf_range(1., 1.5)
    await create_tween().tween_property(%music_player, "rotation", rot, 0.1).set_trans(Tween.TRANS_CUBIC).finished
    create_tween().tween_property(%music_player, "rotation", Vector3.ZERO, 0.25).from(rot).set_trans(Tween.TRANS_CUBIC)

func hover_button(button: Buttons, alpha: float = 0.3):
    if not button_mapping.has(button):
        return
    
    var mesh: MeshInstance3D = button_mapping[button]
    if button_tweens[mesh]:
        button_tweens[mesh].kill()
    button_tweens[mesh] = create_tween()
    var t: Tween = button_tweens[mesh]
    var mat: StandardMaterial3D = mesh.get_active_material(0)    
    t.set_parallel(true)
    t.tween_property(mat, "albedo_color:a", alpha, 0.15)
    var icon: Node3D = mesh.get_child(0)
    t.tween_property(icon, "scale", Vector3(1.20, 1.20, 1.20), 0.15)
    t.set_trans(Tween.TRANS_CIRC)

func unhover_button(button: Buttons):
    if not button_mapping.has(button):
        return
    
    var mesh: MeshInstance3D = button_mapping[button]
    if button_tweens[mesh]:
        button_tweens[mesh].kill()
    button_tweens[mesh] = create_tween()
    var t: Tween = button_tweens[mesh]
    var mat: StandardMaterial3D = mesh.get_active_material(0)
    t.set_parallel(true)
    t.tween_property(mat, "albedo_color:a", 0.0, 0.15)
    var icon: Node3D = mesh.get_child(0)
    t.tween_property(icon, "scale", Vector3.ONE, 0.15)
    t.set_trans(Tween.TRANS_CIRC)

func show_hover(button: Buttons):
    if not ui.map_info_menu.visible:
        for i in button_mapping.keys(): unhover_button(i)
        return
    ui.on_button_focus_entered()
    hover_button(button)
    for i in button_mapping.keys():
        if button != i:
            unhover_button(i)

# mm spaghet
func _on_button_middle_mouse_entered() -> void:
    hover_on = Buttons.Middle
    show_hover(hover_on)

func _on_button_middle_mouse_exited() -> void:
    hover_on = Buttons.None
    show_hover(hover_on)

func _on_button_up_mouse_entered() -> void:
    hover_on = Buttons.Up
    show_hover(hover_on)

func _on_button_left_mouse_entered() -> void:
    hover_on = Buttons.Left
    show_hover(hover_on)

func _on_button_down_mouse_entered() -> void:
    hover_on = Buttons.Down
    show_hover(hover_on)

func _on_button_right_mouse_entered() -> void:
    hover_on = Buttons.Right
    show_hover(hover_on)

func wheel_hide() -> void:
    hover_on = Buttons.None
    show_hover(hover_on)
#endregion
