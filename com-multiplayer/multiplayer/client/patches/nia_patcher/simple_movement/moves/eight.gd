class_name FigureEightMovement
extends "res://mods-unpacked/com-multiplayer/multiplayer/client/patches/nia_patcher/simple_movement/moves/movement_pattern_base.gd"

@export var size: Vector2 = Vector2(2.0, 1.0)
@export var vertical: bool = false

func get_offset(time: float) -> Vector3:
    if not enabled:
        return Vector3.ZERO
    
    var t = time * speed
    var x = sin(t) * size.x * amplitude
    var y = sin(t * 2) * size.y * amplitude
    
    if vertical:
        return Vector3(x, y, 0)
    else:
        return Vector3(x, 0, y)
