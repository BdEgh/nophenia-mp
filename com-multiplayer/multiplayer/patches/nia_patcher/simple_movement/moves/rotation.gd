class_name RotationMovement
extends MovementPattern

@export var rotation_axis: Vector3 = Vector3.UP
@export var degrees_per_second: float = 90.0

func get_rotation(time: float) -> Vector3:
    if not enabled:
        return Vector3.ZERO
    
    var total_rotation = time * degrees_per_second * speed
    return rotation_axis.normalized() * deg_to_rad(total_rotation)
