extends Node3D

@export var target_node: Node3D
@export var speed: float = 10.0

func _physics_process(delta: float) -> void:
    if target_node:
        global_transform = global_transform.interpolate_with(
            target_node.global_transform, 
            speed * delta
        )
