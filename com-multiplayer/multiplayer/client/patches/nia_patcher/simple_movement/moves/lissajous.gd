class_name LissajousMovement
extends MovementPattern

@export var frequency_x: float = 2.0
@export var frequency_y: float = 3.0
@export var frequency_z: float = 0.0
@export var phase_x: float = 0.0
@export var phase_y: float = 0.0
@export var phase_z: float = 0.0
@export var size: Vector3 = Vector3(1, 1, 1)

func get_offset(time: float) -> Vector3:
    if not enabled:
        return Vector3.ZERO
    
    var t = time * speed
    return Vector3(
        sin(t * frequency_x + phase_x) * size.x,
        sin(t * frequency_y + phase_y) * size.y,
        sin(t * frequency_z + phase_z) * size.z
    ) * amplitude
