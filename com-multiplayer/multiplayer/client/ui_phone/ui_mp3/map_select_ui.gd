extends Control

@export var mp3: Node3D

@onready var options: MarginContainer = %Options
@onready var clock: RichTextLabel = %clock
@onready var clock2: RichTextLabel = %clock2
@onready var button_list: VBoxContainer = %v_box_container
@onready var map_list_scroll_box: ScrollContainer = %map_list_scroll_box
@onready var maps_menu: PanelContainer = %Maps_menu
@onready var map_info_menu: PanelContainer = %Map_info_menu
@onready var info_pic: TextureRect = %info_pic
@onready var info_name: RichTextLabel = %info_name
@onready var info_author: RichTextLabel = %info_author
@onready var info_desc: RichTextLabel = %info_desc
@onready var search: LineEdit = %search
@onready var load_bar: ProgressBar = %load_bar
@onready var map_index: RichTextLabel = %map_index

var maps := {}
var default_picture: Texture2D

func _ready() -> void:
    map_list_scroll_box.get_v_scroll_bar().value_changed.connect(_upd_cat_scroll_status)
    map_list_scroll_box.get_h_scroll_bar().value_changed.connect(_upd_cat_scroll_status)
    default_picture = info_pic.texture
    var remote_loader = get_tree().get_first_node_in_group("mp").remote_loader
    remote_loader.download_progress.connect(_update_load_progress)

func _update_load_progress(value: float):
    load_bar.visible = true
    load_bar.value = value

var map_button_res := load(get_script().resource_path.get_base_dir() + "/map_select_button.tscn")
func add_map(map: Dictionary):
    var map_key = map.get("name", str(randi()))
    if maps.has(map_key):
        maps[map_key].fill_data(map)
        return
    var button = map_button_res.instantiate()
    button.ui = self
    button.mp3 = mp3
    button_list.add_child(button)
    button.fill_data(map)
    maps[map_key] = button

func show_map_list():
    add_ghosting()
    maps_menu.visible = true
    map_info_menu.visible = false
    
    await get_tree().process_frame
    if last_selected:
        last_selected.grab_focus()
    else:
        for m in button_list.get_children():
            if m.visible:
                m.grab_focus()
                break

func show_map_info():
    mp3.feedback()
    maps_menu.visible = false
    map_info_menu.visible = true
    load_bar.visible = false

var last_selected: Button
func show_map(map_button: Button):
    last_selected = map_button
    if map_button.image:
        info_pic.texture = ImageTexture.create_from_image(map_button.image)
    else:
        info_pic.texture = default_picture
    info_name.text = map_button.name
    if map_button.data.has("md5") and map_button.data.has("local_md5") and map_button.data["md5"] != map_button.data["local_md5"]:
        info_name.text += " 🗘"
    elif map_button.data.has("local_md5"):
        info_name.text += " 💾"
    info_author.text = map_button.author
    info_desc.text = map_button.description
    
    var buttons: Array = maps.values()
    var index = buttons.find(last_selected)
    map_index.text = "%d/%d" % [index + 1, maps.size()]
    show_map_info()

func queue_free_maps():
    for m in maps.values():
        m.queue_free()
    maps.clear()
    search.clear()
    last_selected = null

func _physics_process(_delta: float) -> void:
    var pause_menu = game.find("pause_menu")
    if pause_menu:
        var time = pause_menu.get_node("screen/screen_view/menu/home/info/margin_container/h_box_container/time_date_box/time_box/time")
        clock.text = time.text
        clock2.text = time.text

var _afterimage_tween: Tween
var _cd_ghosting: bool = false
func add_ghosting():
    if _cd_ghosting: return
    await RenderingServer.frame_post_draw
    _cd_ghosting = true
    var _image = mp3.get_node("sub_viewport").get_texture().get_image()
    var _capture = ImageTexture.create_from_image(_image)
    %after_image.texture = _capture
    _afterimage_tween = game.tween(_afterimage_tween)
    #create_tween().tween_property( %bg.material, "shader_parameter/saturation", 0.3, 0.4).from(0.6)
    await _afterimage_tween.tween_property( %after_image, "modulate:a", 0.25, 0.3).from(1.0).set_trans(Tween.TRANS_CUBIC).finished
    _cd_ghosting = false
    _afterimage_tween = game.tween(_afterimage_tween)
    _afterimage_tween.tween_property( %after_image, "modulate:a", 0.0, randf_range(0.3, 1.0)).set_trans(Tween.TRANS_SINE)

func _upd_cat_scroll_status(_value: int = 0):
    add_ghosting()

func _on_options_button_toggled(toggled_on: bool) -> void:
    options.visible = toggled_on

func _on_search_text_changed(new_text: String) -> void:
    for m in maps.values():
        if new_text == "" or new_text in m.name or new_text in m.author:
            m.visible = true
        else:
            m.visible = false
    add_ghosting()
    audio.play_snd(game.loadres("menu_slider"), -1, 0.6, "snd")
    audio.play_snd(game.loadres("phone_keypad_short"), -1, 0.6, "snd")

func _on_back_button_pressed() -> void:
    mp3.back_to_phone()

func select_map() -> void:
    var remote_loader = get_tree().get_first_node_in_group("mp").remote_loader
    remote_loader.change_stage(last_selected.name)

func prev_map_info() -> void:
    var buttons: Array = maps.values()
    var index = buttons.find(last_selected)
    index -= 1
    if index < 0: index = buttons.size() - 1
    show_map(buttons[index])

func next_map_info() -> void:
    var buttons: Array = maps.values()
    var index = buttons.find(last_selected)
    index += 1
    index %= buttons.size()
    show_map(buttons[index])

func chat_share() -> void:
    var chat = get_tree().get_first_node_in_group("mp").chat.get_node("ChatUI")
    chat.toggle_chat(true)
    var mi: LineEdit = chat.message_input
    mi.text = "[url=s=%s]%s[/url]" % [last_selected.name, last_selected.name]
    mi.caret_column = mi.text.length()
