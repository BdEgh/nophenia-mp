class_name CircularMovement
extends "res://mods-unpacked/com-multiplayer/multiplayer/client/patches/nia_patcher/simple_movement/moves/movement_pattern_base.gd"

@export var radius: float = 2.0
@export var axis_plane: Vector3 = Vector3(1, 0, 1)
@export var clockwise: bool = true

func get_offset(time: float) -> Vector3:
    if not enabled:
        return Vector3.ZERO
    
    var angle = time * speed * (1 if clockwise else -1)
    var offset = Vector3(
        cos(angle) * radius * amplitude * axis_plane.x,
        cos(angle) * radius * amplitude * axis_plane.y,
        sin(angle) * radius * amplitude * axis_plane.z
    )
    return offset
