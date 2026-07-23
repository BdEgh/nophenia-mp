extends MeshInstance3D

@export var chara: CharacterBody3D

@onready var jiggle_sfx: AudioStreamPlayer3D = $jiggle

func _physics_process(_delta: float) -> void:
    if not jiggle_sfx.playing:
        jiggle_sfx.play()
    if not visible:
        jiggle_sfx.volume_db = -40
    else:
        jiggle_sfx.volume_db = min(-5, remap(chara.velocity.length(), 0.0, 3.5, -40.0, 0.0))
