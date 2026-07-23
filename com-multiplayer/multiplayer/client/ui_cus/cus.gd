extends Control

var item_scene = load(get_script().resource_path.get_base_dir() + "/item.tscn")

@onready var items_container: VBoxContainer = %ItemsContainer

enum Type { All, Accessories, Body, Head, Paws }
const item_types: Dictionary = {
    "Dog collar": Type.Accessories,
    "Glasses red": Type.Accessories,
    "Glasses round": Type.Accessories,
    "Punk collar": Type.Accessories,
    "Bell": Type.Accessories,
    "Tie": Type.Accessories,
    "Skirt": Type.Accessories,
    "Arm sleeves": Type.Accessories,
    "Blue Bell": Type.Accessories,
    "umbrella": Type.Accessories,
    
    "Thigh highs": Type.Paws,
    "Paws": Type.Paws,
    "Boots": Type.Paws,
    "rain_boots": Type.Paws,
    
    "Striped T-shirt": Type.Body,
    "Dress black": Type.Body,
    "Dress red": Type.Body,
    "Sweater beige": Type.Body,
    
    "Hat": Type.Head,
    #"Short hair head": Type.Head,
    #"head for hats": Type.Head
}

var current_type: Type = Type.All
var toggling := false
var item_dict: Dictionary
var opened := false

func _ready() -> void:
    var nia: player = get_tree().get_first_node_in_group("player")
    var item_meshes: Array = nia.shared_patcher.item_meshes
    item_meshes.map(func(item): item_dict[item.name] = item)
    for iname in item_dict:
        var item = item_dict[iname]
        var preview_item = item_dict.get(iname + " preview", null)
        if not iname in item_types:
            ModLoaderLog.error("item type is undefined for item: %s" % iname, self.name)
            continue
        var item_button = item_scene.instantiate()
        item_button.cus = self
        item_button.item = item
        item_button.preview = preview_item
        item_button.iname = iname
        item_button.itype = item_types[iname]
        items_container.add_child(item_button)
    load_state()
    _patch_categories()

func _patch_categories() -> void:
    var category_buttons = find_children("*", "Button")
    for button: Button in category_buttons:
        button.pivot_offset = Vector2(0.5, 0.5)
        button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
        button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
        button.focus_entered.connect(_on_category_button_focus_entered.bind(button))
        button.focus_exited.connect(_on_category_button_focus_exited.bind(button))        

func _on_button_mouse_entered(button: Button) -> void:
    button.grab_focus()

func _on_button_mouse_exited(button: Button) -> void:
    button.release_focus()

var tween: Tween

func _on_category_button_focus_entered(button: Button) -> void:
    create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).tween_property(button, "scale", Vector2(1.1, 1.1), 0.1)

func _on_category_button_focus_exited(button: Button) -> void:
    create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).tween_property(button, "scale", Vector2.ONE, 0.1)

func save_state() -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    for item_button in items_container.get_children():
        var item_name: String = item_button.iname
        mp.mp_cfg.items_visible[item_name] = item_button.item.visible
    mp.save_config()

func load_state() -> void:
    var mp = get_tree().get_first_node_in_group("mp")
    var state: Dictionary = mp.mp_cfg.items_visible
    for item_button in items_container.get_children():
        var item_visible: bool = state.get(item_button.iname, false)
        var button: Button = item_button.button
        button.set_pressed(item_visible)
        item_button.do_save = true

func _on_close_button_pressed() -> void:
    toggle()

func _input(event):
    if event is InputEventKey and event.pressed and !event.echo:
        if event.keycode == KEY_5 and \
        (not get_tree().get_first_node_in_group("player").is_paused or opened):
            toggle()
        elif visible and event.keycode == KEY_ESCAPE:
            toggle()
            get_viewport().set_input_as_handled()

func toggle():
    if toggling:
        return
    
    toggling = true
    var camera = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm/cam_arm_fix/view")
    
    if !visible:
        opened = true
        game.find("pause_menu")._open_cooldown = true
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        visible = true
        _set_player_input_enabled(false)
        var cam_arm = get_tree().get_first_node_in_group("player").get_node("cam_box/cam_arm")
        var move_multiplier = (cam_arm.spring_length - 0.8) * 0.45
        _animate_camera(camera, move_multiplier)
        await create_tween().tween_property(self, "modulate:a", 1.0, 0.2).from(0.0).set_trans(Tween.TRANS_CIRC).finished
    else:
        opened = false
        game.find("pause_menu")._open_cooldown = false
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        _animate_camera(camera, 0.0)
        await create_tween().tween_property(self, "modulate:a", 0.0, 0.2).from(1.0).set_trans(Tween.TRANS_CIRC).finished
        visible = false
        _set_player_input_enabled(true)
    
    toggling = false

func _animate_camera(camera: Node3D, target_x: float):
    create_tween().tween_property(camera, "position:x", target_x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _set_player_input_enabled(enabled: bool) -> void:
    get_tree().get_first_node_in_group("player").set_process_unhandled_input(enabled)
    get_tree().get_first_node_in_group("player").is_paused = not enabled
    if !enabled:
        get_tree().get_first_node_in_group("player").velocity = Vector3.ZERO
        var anim_tree = get_tree().get_first_node_in_group("player").get_node_or_null("anim_tree")
        if anim_tree:
            anim_tree.set("parameters/idle_walk_run/blend_position", Vector2.ZERO)

func auto_disable(disable_type: Type, exclude: String) -> void:
    if disable_type in [Type.Accessories, Type.Head, Type.Paws]:
        return
    
    for item_button in items_container.get_children():
        if disable_type == item_button.itype and exclude != item_button.iname:
            var button: Button = item_button.button
            button.set_pressed(false)

@onready var all_button: Button = %AllButton
@onready var head_button: Button = %HeadButton
@onready var body_button: Button = %BodyButton
#@onready var limbs_button: Button = %LimbsButton
@onready var paws_button: Button = %PawsButton
@onready var accessories_button: Button = %AccessoriesButton

@onready var buttons: Array[Button] = [
    all_button,
    head_button,
    body_button,
    #limbs_button,
    paws_button,
    accessories_button
]

func _cat_toggle(active_button: Button, toggled_on: bool) -> void:
    if not toggled_on:
        return
    for button in buttons:
        if button != active_button:
            button.set_pressed_no_signal(false)
    _change_items_visiblity()

func _change_items_visiblity() -> void:
    if current_type == Type.All:
        for i in items_container.get_children():
            i.visible = true
        return
    
    for i in items_container.get_children():
        if i.itype == current_type:
            i.visible = true
        else:
            i.visible = false

func _on_all_button_toggled(toggled_on: bool) -> void:
    if not toggled_on:
        all_button.set_pressed_no_signal(true)
        return
    current_type = Type.All
    _cat_toggle(all_button, toggled_on)

func _on_head_button_toggled(toggled_on: bool) -> void:
    if not toggled_on:
        head_button.set_pressed_no_signal(true)
        return
    current_type = Type.Head
    _cat_toggle(head_button, toggled_on)

func _on_body_button_toggled(toggled_on: bool) -> void:
    if not toggled_on:
        body_button.set_pressed_no_signal(true)
        return
    current_type = Type.Body
    _cat_toggle(body_button, toggled_on)

#func _on_limbs_button_toggled(toggled_on: bool) -> void:
    #if not toggled_on:
        #limbs_button.set_pressed_no_signal(true)
        #return
    #current_type = Type.Limbs
    #_cat_toggle(limbs_button, toggled_on)

func _on_paws_button_toggled(toggled_on: bool) -> void:
    if not toggled_on:
        paws_button.set_pressed_no_signal(true)
        return
    current_type = Type.Paws
    _cat_toggle(paws_button, toggled_on)

func _on_accessories_button_toggled(toggled_on: bool) -> void:
    if not toggled_on:
        accessories_button.set_pressed_no_signal(true)
        return
    current_type = Type.Accessories
    _cat_toggle(accessories_button, toggled_on)
