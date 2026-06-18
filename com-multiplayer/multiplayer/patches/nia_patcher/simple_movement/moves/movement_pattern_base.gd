class_name MovementPattern
extends Resource

@export var enabled: bool = true
@export var speed: float = 1.0
@export var amplitude: float = 1.0

func get_offset(_time: float) -> Vector3:
    return Vector3.ZERO

func get_rotation(_time: float) -> Vector3:
    return Vector3.ZERO
