extends Button

@export var mp3: Node3D
@export var ui: Control

@onready var map_name: RichTextLabel = %Map_name
@onready var author_name: RichTextLabel = %Author_name
@onready var pic: TextureRect = %pic

var description: String
var image: Image
var author: String
var data: Dictionary

func fill_data(map: Dictionary):
    name = map.get("name", "unknown")
    map_name.text = name
    author = map.get("author", "unknown")
    author_name.text = author
    description = map.get("description", "unknown")
    data.merge(map, true)
    
    if map.has("picture"):
        image = Image.new()
        image.load_png_from_buffer(Marshalls.base64_to_raw(map["picture"]))
        pic.texture = ImageTexture.create_from_image(image)

# TODO
#var _display_title_tween: Tween
#func _title_size_check():
    #await RenderingServer.frame_post_draw
    #var _size = %display_title.get_theme_default_font().get_string_size(tr( %display_title.text), 0, -1, 17).x
    #
    #if _size >= 68 and get_viewport().gui_get_focus_owner() == self:
        #%display_title_box.clip_contents = true
        #_display_title_tween = game.tween(_display_title_tween).set_loops()
        #_display_title_tween.tween_property( %display_title, "position:x", - abs(_size - 52), 1.0).set_delay(0.5)
        #_display_title_tween.tween_property( %display_title, "position:x", 0.0, 1.0).set_delay(0.5)

func _grab_focus() -> void:
    grab_focus()
    if ui:
        ui.add_ghosting()

func _release_focus() -> void:
    release_focus()
    if ui:
        ui.add_ghosting()

func _on_pressed() -> void:
    mp3.zoom_out()
    ui.show_map(self)
    ui.add_ghosting()
