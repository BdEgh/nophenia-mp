class_name SineWaveMovement
extends MovementPattern

@export var axis: Vector3 = Vector3.UP
@export var frequency: float = 1.0
@export var phase: float = 0.0

func get_offset(time: float) -> Vector3:
    if not enabled:
        return Vector3.ZERO
    return axis.normalized() * sin((time * frequency * speed) + phase) * amplitude
