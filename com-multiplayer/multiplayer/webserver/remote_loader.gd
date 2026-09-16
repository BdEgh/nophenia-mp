#class_name StageLoader
extends Node

@export var addr := "http://127.0.0.1:8080"
@export var remote_stages_physical := "user://remote_stages"
@export var stages_mounted := "res://stages-unpacked"

var http: HTTPRequest

func _ready() -> void:
    http = HTTPRequest.new()
    http.download_chunk_size = 128 * 1024
    http.use_threads = true
    add_child(http)

func load_all_from_disk() -> void:
    for file in DirAccess.get_files_at(remote_stages_physical):
        var path = remote_stages_physical.path_join(file)
        load_from_disk(path)

func load_from_disk(path: String):
    if path.get_extension() != "zip" or not FileAccess.file_exists(path):
        ModLoaderLog.info("unable to load: " + path, self.name)
        return
    
    var is_loaded := ProjectSettings.load_resource_pack(path, false)
    if is_loaded:
        ModLoaderLog.info("loaded level: " + path, self.name)

func download_and_load(_stage: String):
    if not DirAccess.dir_exists_absolute(remote_stages_physical):
        DirAccess.make_dir_absolute(remote_stages_physical)
    var physical_path = remote_stages_physical.path_join("%s.zip" % _stage)
    if FileAccess.file_exists(physical_path):
        load_from_disk(physical_path)
        return
    
    http.cancel_request()
    http.download_file = remote_stages_physical.path_join("%s.zip" % _stage)
    var url := addr.path_join("/load_stage?stage=%s.zip" % _stage)
    var err := http.request(url)
    if err != OK:
        ModLoaderLog.error("%s request failed" % [_stage], self.name)
        return
    var response = await http.request_completed
    var res = response[0]
    var code = response[1]
    if res == HTTPRequest.RESULT_SUCCESS and code == 200:
        ModLoaderLog.info("%s downloaded" % _stage, self.name)
        load_from_disk(physical_path)
    else:
        ModLoaderLog.error("%s download failed. Code %d" % [_stage, code], self.name)

func fetch_mounted_stage(_stage: String):
    var mounted_stage = stages_mounted.path_join("%s/%s.tscn" % [_stage, _stage])
    if FileAccess.file_exists(mounted_stage):
        return mounted_stage
    return null

func fetch_stage(_stage: String):
    var original_stage = "res://stage/%s.tscn" % _stage
    if FileAccess.file_exists(original_stage):
        return original_stage
    var mounted_stage = fetch_mounted_stage(_stage)
    if not mounted_stage:
        await download_and_load(_stage)
        mounted_stage = fetch_mounted_stage(_stage)
    return mounted_stage

func change_stage(_stage):
    if game.transing:
        return
    _stage = await fetch_stage(_stage)
    if not _stage:
        return
    
    game.trans_id = randi_range(0, 7)
    await game.trans(true)
    await RenderingServer.frame_post_draw
    get_tree().unload_current_scene()
    var _error = get_tree().change_scene_to_file(_stage)
    if _error: change_stage("stage_title")
    await get_tree().tree_changed
    await get_tree().process_frame
    game.trans(false)
    game.show_location()
    if is_instance_valid(game.active_stage):
        if !game.active_stage.is_static:
            audio.play_snd(preload("res://audio/sfx/door_shut.ogg"), -1.0, 0.2)
