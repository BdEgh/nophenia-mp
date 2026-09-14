#class_name GetStagesRouter extends HttpRouter
extends 'http_router.gd'

const localpath := "res://remote_stages"

func handle_get(_request, response):
    var global_path := ProjectSettings.globalize_path(localpath)
    response.send(200, str(DirAccess.get_files_at(global_path)))
