@tool
extends Node3D

@export var item: MeshInstance3D:
    set(item):
        preview_item(item)

@onready var item_container: Node3D = $item_container
@onready var camera_3d: Camera3D = $camera_3d

var base_rotation: Vector3

# parallax sucks, we need to rotate the item or camera around the item instead
func _physics_process(_delta: float) -> void:
    const rot_str: float = 0.03
    const max_rot: float = .15
    var center = get_viewport().get_size() / 2.0
    var mouse_pos = get_viewport().get_mouse_position()
    var offset = (mouse_pos - center) / center
    offset.x = clamp(offset.x, -1.0, 1.0)
    offset.y = clamp(offset.y, -1.0, 1.0)
    var target_rotation_x = base_rotation.x + offset.y * max_rot
    var target_rotation_y = base_rotation.y + offset.x * max_rot
    var current_rot = camera_3d.rotation
    camera_3d.rotation.x = lerp_angle(current_rot.x, target_rotation_x, rot_str)
    camera_3d.rotation.y = lerp_angle(current_rot.y, target_rotation_y, rot_str)
    camera_3d.rotation.z = base_rotation.z

var white_mat: Material = null
func preview_item(mesh_instance: MeshInstance3D) -> void:
    for child in item_container.get_children():
        child.queue_free()
    
    var duplicated_mesh = mesh_instance.duplicate(0) as MeshInstance3D
    for child in duplicated_mesh.get_children(): child.queue_free()
    duplicated_mesh.visible = true
    duplicated_mesh.material_overlay = null
    if duplicated_mesh.get_active_material(0).next_pass:
        if not white_mat:
            white_mat = duplicated_mesh.get_active_material(0).duplicate(true)
            white_mat.next_pass.albedo_color = Color.WHITE
        duplicated_mesh.set_surface_override_material(0, white_mat)
    
    duplicated_mesh.lod_bias = 10.0
    var custom_box = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
    duplicated_mesh.custom_aabb = custom_box
    item_container.add_child(duplicated_mesh)
    var aabb: AABB = duplicated_mesh.get_aabb()
    duplicated_mesh.position = -aabb.get_center()
    adjust_camera_to_fit(aabb)

func adjust_camera_to_fit(aabb: AABB) -> void:
    var object_size: float = aabb.size.length()
    var fov_rad: float = deg_to_rad(camera_3d.fov)
    var target_distance: float = (object_size / 2.0) / sin(fov_rad / 2.0) / 0.7
    var tilt_angle_x: float = deg_to_rad(-20.0)
    var turn_angle_y: float = deg_to_rad(45.0)
    var camera_direction = Vector3(0, 0, 1)
    camera_direction = camera_direction.rotated(Vector3(1, 0, 0), tilt_angle_x)
    camera_direction = camera_direction.rotated(Vector3(0, 1, 0), turn_angle_y)
    camera_3d.position = camera_direction.normalized() * target_distance
    camera_3d.look_at(Vector3.ZERO, Vector3.UP)
    base_rotation = camera_3d.rotation
