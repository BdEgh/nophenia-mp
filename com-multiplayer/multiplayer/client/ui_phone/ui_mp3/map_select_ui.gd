extends Control

@export var mp3: Node3D

@onready var options: MarginContainer = %Options
@onready var clock: RichTextLabel = %clock
@onready var button_list: VBoxContainer = %v_box_container
@onready var map_list_scroll_box: ScrollContainer = %map_list_scroll_box
@onready var maps_menu: PanelContainer = %Maps_menu
@onready var map_info_menu: PanelContainer = %Map_info_menu
@onready var info_pic: TextureRect = %info_pic
@onready var info_name: RichTextLabel = %info_name
@onready var info_author: RichTextLabel = %info_author
@onready var info_desc: RichTextLabel = %info_desc
@onready var search: LineEdit = %search

var maps := {}

var map_button_res := load(get_script().resource_path.get_base_dir() + "/map_select_button.tscn")
func add_map(map: Dictionary):
    var map_key = map.get("name", str(randi()))
    if maps.has(map_key):
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
    if last_selected:
        last_selected.grab_focus()
    else:
        for m in button_list.get_children():
            if m.visible:
                m.grab_focus()
                break

func show_map_info():
    add_ghosting()
    maps_menu.visible = false
    map_info_menu.visible = true

var last_selected: Button
func show_map(map: Button):
    last_selected = map
    if map.image:
        info_pic.texture = ImageTexture.create_from_image(map.image)
    info_name.text = map.name
    info_author.text = map.author
    info_desc.text = map.description
    show_map_info()

func queue_free_maps():
    for m in maps.values():
        m.queue_free()
    maps.clear()
    search.clear()
    last_selected = null

func _ready() -> void:
    map_list_scroll_box.get_v_scroll_bar().value_changed.connect(_upd_cat_scroll_status)
    map_list_scroll_box.get_h_scroll_bar().value_changed.connect(_upd_cat_scroll_status)

func _physics_process(_delta: float) -> void:
    var pause_menu = game.find("pause_menu")
    if pause_menu:
        var time = pause_menu.get_node("screen/screen_view/menu/home/info/margin_container/h_box_container/time_date_box/time_box/time")
        clock.text = time.text

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

func _on_back_button_pressed() -> void:
    mp3.back_to_phone()
