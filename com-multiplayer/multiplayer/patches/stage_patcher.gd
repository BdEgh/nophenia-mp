extends Node

func _ready() -> void:
   patch_beach()

# :emiwaHmph:
func patch_beach():
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
