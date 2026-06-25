extends RefCounted

static var _shared

var paths := {}
var regex := RegEx.new()

func _init(emoji_dir: String) -> void:
    regex.compile(":([a-z_]+):")
    var dir := DirAccess.open(emoji_dir)
    if not dir:
        return
    for file in dir.get_files():
        if file.get_extension() != "png":
            continue
        var key := file.get_basename()
        if key.begins_with("emiwa_"):
            key = key.trim_prefix("emiwa_")
        paths[key] = emoji_dir + "/" + file

static func get_shared(emoji_dir: String):
    if _shared == null:
        _shared = load(emoji_dir.get_base_dir() + "/chat_emoji.gd").new(emoji_dir)
    return _shared

func unwrap(text: String) -> String:
    var result := ""
    var pos := 0
    for m in regex.search_all(text):
        result += text.substr(pos, m.get_start() - pos)
        var path = paths.get(m.get_string(1))
        if path:
            result += "[img height=32]%s[/img]" % path
        else:
            result += m.get_string(0)
        pos = m.get_end()
    result += text.substr(pos)
    return result
