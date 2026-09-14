## Class inheriting HttpRouter for handling file serving requests
##
## NOTE: This class mainly handles behind the scenes stuff.
#class_name HttpFileRouter
#extends HttpRouter
extends 'http_router.gd'

var localpath: String

var weekdays: Array[String] = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
var monthnames: Array[String] = ['___', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

## Creates an HttpFileRouter intance
func _init(
    _path: String,
    _localpath: String
) -> void:
    self.path = _path
    self.localpath = _localpath

## Handle a GET request
## [br]
## [br][param request] - The request from the client
## [br][param response] - The response to send to the clinet
func handle_get(request, response):
    var file_name: String = str(request.query.get("stage"))
    var file_path = localpath
    if file_name:
        file_name = file_name.uri_decode()
        file_path = localpath.path_join(file_name).simplify_path()
        file_path = ProjectSettings.globalize_path(file_path)
    
    var global_path := ProjectSettings.globalize_path(localpath)
    if not file_path.begins_with(global_path):
        response.send(403)
        return
    
    var file_exists: bool = _file_exists(file_path)
    if file_exists:
        var modifiedtime = FileAccess.get_modified_time(file_path)
        var time = Time.get_datetime_dict_from_unix_time(modifiedtime)
        var weekday = weekdays[time.weekday]
        var monthname = monthnames[time.month]
        var timestamp = '%s, %02d %s %04d %02d:%02d:%02d GMT' % [weekday, time.day, monthname, time.year, time.hour, time.minute, time.second]
        
        if request.headers.get('If-Modified-Since') == timestamp:
            response.send(304, "", _get_mime(file_path.get_extension()))
            return
        else:
            if request.headers.has('Range'):
                var rdata: PackedStringArray = request.headers['Range'].split('=')
                var brequest: PackedStringArray = rdata[1].split('-')
                if brequest[0].is_valid_int():
                    var start: int = brequest[0].to_int()
                    var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
                    var size = file.get_length()
                    file.close()
                    response.send_raw(
                        206,
                        _serve_file(file_path, start),
                        _get_mime(file_path.get_extension()),
                        "Content-Disposition: attachment; filename=\"%s\"\r\nCache-Control: no-cache\r\nLast-Modified: %s\r\nContent-Range: bytes %s-%s/%s\r\n" % [file_name, timestamp, start, size-1, size]
                    )
            else:
                response.send_raw(
                    200,
                    _serve_file(file_path),
                    _get_mime(file_path.get_extension()),
                    "Content-Disposition: attachment; filename=\"%s\"\r\nCache-Control: no-cache\r\nLast-Modified: %s\r\n" % [file_name, timestamp]
                )
            return
    else:
        response.send(404)

# Reads a file as text
#
# #### Parameters
# - file_path: Full path to the file
func _serve_file(file_path: String, seek: int = -1) -> PackedByteArray:
    var content: PackedByteArray = []
    var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
    var error = FileAccess.get_open_error()
    if error:
        content = ("Couldn't serve file, ERROR = %s" % error).to_ascii_buffer()
    else:
        if seek != -1 and seek < file.get_length():
            file.seek(seek)
        content = file.get_buffer(file.get_length())
    file.close()
    return content

# Check if a file exists
#
# #### Parameters
# - file_path: Full path to the file
func _file_exists(file_path: String) -> bool:
    return FileAccess.file_exists(file_path)

# Get the full MIME type of a file from its extension
#
# #### Parameters
# - file_extension: Extension of the file to be served
func _get_mime(file_extension: String) -> String:
    var type: String = "application"
    var subtype : String = "octet-stream"
    match file_extension:
        # Web files
        "css","html","csv","js","mjs":
            type = "text"
            subtype = "javascript" if file_extension in ["js","mjs"] else file_extension
        "php":
            subtype = "x-httpd-php"
        "ttf","woff","woff2":
            type = "font"
            subtype = file_extension
        # Image
        "png","bmp","gif","png","webp":
            type = "image"
            subtype = file_extension
        "jpeg","jpg":
            type = "image"
            subtype = "jpg"
        "tiff", "tif":
            type = "image"
            subtype = "jpg"
        "svg":
            type = "image"
            subtype = "svg+xml"
        "ico":
            type = "image"
            subtype = "vnd.microsoft.icon"
        # Documents
        "doc":
            subtype = "msword"
        "docx":
            subtype = "vnd.openxmlformats-officedocument.wordprocessingml.document"
        "7z":
            subtype = "x-7x-compressed"
        "gz":
            subtype = "gzip"
        "tar":
            subtype = "application/x-tar"
        "json","pdf","zip":
            subtype = file_extension
        "txt":
            type = "text"
            subtype = "plain"
        "ppt":
            subtype = "vnd.ms-powerpoint"
        # Audio
        "midi","mp3","wav":
            type = "audio"
            subtype = file_extension
        "mp4","mpeg","webm":
            type = "audio"
            subtype = file_extension
        "oga","ogg":
            type = "audio"
            subtype = "ogg"
        "mpkg":
            subtype = "vnd.apple.installer+xml"
        # Video
        "ogv":
            type = "video"
            subtype = "ogg"
        "avi":
            type = "video"
            subtype = "x-msvideo"
        "ogx":
            subtype = "ogg"
    return type + "/" + subtype
