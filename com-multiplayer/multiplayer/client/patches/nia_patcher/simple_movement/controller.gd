class_name MovingObject
extends Node

@export var move_enabled: bool = false
@export var movement_patterns: Array = []
@export var time_offset: float = 0.0

var time: float = 0.0
var base_transform: Transform3D

func _ready() -> void:
    base_transform = self.transform

func _physics_process(delta):
    if not move_enabled:
        return
    
    time += delta
    self.transform = base_transform
    var total_offset = Vector3.ZERO
    var total_rotation = Vector3.ZERO
    for pattern in movement_patterns:
        if pattern and pattern.enabled:
            total_offset += pattern.get_offset(time)
            total_rotation += pattern.get_rotation(time)
    var pattern_transform = Transform3D(Basis.from_euler(total_rotation), total_offset)
    self.transform = base_transform * pattern_transform

func reset_time():
    time = 0.0

func set_base_transform(new_transform: Transform3D):
    base_transform = new_transform
