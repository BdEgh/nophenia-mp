
#class_name GetStagesRouter extends HttpRouter
extends 'http_router.gd'

const localpath := "res://remote_stages"

func handle_get(_request, response):
    var global_path := ProjectSettings.globalize_path(localpath)
    var files = DirAccess.get_files_at(global_path)
    var names = Array(files).filter(func(file: String): return file.get_extension() == "zip").map(func(file: String): return file.get_basename())
    var resp: Array
    for name in names:
        var map = global_path.path_join("%s.zip" % name)
        var info = global_path.path_join("%s.txt" % name)
        var picture = global_path.path_join("%s.png" % name)
        
        var info_data: Dictionary
        var picture_data: Dictionary
        if FileAccess.file_exists(info):
            var file = FileAccess.open(info, FileAccess.READ)
            var json = JSON.new()
            var error = json.parse(file.get_as_text())
            if error == OK and typeof(json.data) == TYPE_DICTIONARY:
                info_data = {"author": json.data.author, "description": json.data.description}
            file.close()
        if FileAccess.file_exists(picture):
            var file = FileAccess.open(picture, FileAccess.READ)
            var buffer: PackedByteArray = file.get_buffer(file.get_length())
            var b64: String = Marshalls.raw_to_base64(buffer)
            picture_data = {"picture": b64}
            file.close()
        
        var timestamp = FileAccess.get_modified_time(map)
        var md5 = FileAccess.get_md5(map)
        resp.append({
            "name": name,
            "md5": md5,
            "timestamp": timestamp
        }.merged(info_data).merged(picture_data))
    response.send(200, str(resp))
