extends Node

var patched_interactable_res := load(get_script().resource_path.get_base_dir() + "/patched_interactable.gd")

func _ready() -> void:
    _patch_beach()
    _find_interactable(get_tree().root)

# :emiwaHmph:
func _patch_beach():
    if game.active_stage.stage_name == "world_beach":
        var flies = game.active_stage.get_node("particle_flies")
        if flies:
            flies.visible = false
        var bucket = game.active_stage.get_node("beach/bucket")
        if bucket != null:
            var hidden = StandardMaterial3D.new()
            hidden.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            hidden.albedo_color = Color(0, 0, 0, 0)
            for i in bucket.get_surface_override_material_count():
                if bucket.get_active_material(i).resource_name == "flesh":
                    bucket.set_surface_override_material(i, hidden)

func _find_interactable(node: Node) -> void:
    _try_patch_interactable(node)
    for child in node.get_children():
        _find_interactable(child)

func _try_patch_interactable(node: Node) -> bool:
    if node is interactable:
        node.set_script(patched_interactable_res)
        return true
    return false
