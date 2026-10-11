extends Button

@onready var map_name: RichTextLabel = %Map_name

@onready var author_name: RichTextLabel = %Author_name

@onready var pic: TextureRect = %pic

func fill_data(map: Dictionary):
    map_name.text = map["name"]
    author_name.text = map["author"]
    
    var img = Image.new()
    img.load_png_from_buffer(Marshalls.base64_to_raw(map["picture"]))
    pic.texture = ImageTexture.create_from_image(img)
    
    
    
    
var _display_title_tween: Tween
func _title_size_check():
    await RenderingServer.frame_post_draw
    var _size = %display_title.get_theme_default_font().get_string_size(tr( %display_title.text), 0, -1, 17).x

    if _size >= 68 and get_viewport().gui_get_focus_owner() == self:
        %display_title_box.clip_contents = true
        _display_title_tween = game.tween(_display_title_tween).set_loops()
        _display_title_tween.tween_property( %display_title, "position:x", - abs(_size - 52), 1.0).set_delay(0.5)
        _display_title_tween.tween_property( %display_title, "position:x", 0.0, 1.0).set_delay(0.5)
    
    
