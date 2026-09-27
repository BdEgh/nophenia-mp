class_name ProjectPatcher
extends Node

@export_enum("gl_compatibility", "forward_plus") var rendering_method := "gl_compatibility"
@export var embed_subwindows := true

func _ready() -> void:
    add_to_group("proj_patcher")
    var mp = get_tree().get_first_node_in_group("mp")
    #var rd = "vulkan" if "forward_plus" else "opengl3"
    mp.patch_properties([
        ["display", "window/subwindows/embed_subwindows", embed_subwindows],
        ["rendering", "renderer/rendering_method", rendering_method],
        #["rendering", "renderer/rendering_driver", rd],
    ])
