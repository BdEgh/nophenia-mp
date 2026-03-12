#class_name MultiplayerPuppetManager
extends Node

signal puppet_spawned(player_id: int)
signal puppet_removed(player_id: int)
signal puppets_cleared()

var Api = load((get_script().resource_path.get_base_dir() + "/../api/pb.gd").simplify_path())
var MultiplayerClientProto = load(get_script().resource_path.get_base_dir() + "/client_api.gd")

const NAMES = [
	"cheese", "milk", "tea",
	"coffee", "fish", "pumpkin",
	"melon", "apple", "banana",
	"grape", "honey", "sugar",
	"kiwi", "mango", "orange"
]

@export var client: Node
@export var puppet_scene: PackedScene
@export var spawn_parent: Node3D

var puppets: Dictionary = {}  # player_id -> MultiplayerPuppet instance

func _ready():
	if not client:
		ModLoaderLog.error("No network_client assigned!", self.name)
		return
	
	if not puppet_scene:
		ModLoaderLog.error("No puppet_scene assigned!", self.name)
		return
	
	if not spawn_parent:
		spawn_parent = get_parent()
	
	client.player_set.connect(_on_player_set)
	client.player_delete.connect(_on_player_delete)
	client.player_message.connect(_on_player_message)
	client.disconnected_from_server.connect(_on_disconnected)

func _on_player_set(player_id: int, state):
	if puppets.has(player_id) and puppets[player_id]:
		var puppet = puppets[player_id]
		puppet.apply_state(state)
	else:
		_spawn_puppet(player_id, state)

func _on_player_delete(player_id: int):
	if puppets.has(player_id):
		var puppet = puppets[player_id]
		puppet.queue_free()
		puppets.erase(player_id)
		ModLoaderLog.info("MultiplayerPuppetManager: Removed puppet for player %d" % player_id, self.name)
		puppet_removed.emit(player_id)

func _on_player_message(player_id: int, message: String):
	if message.begins_with("DO:"):
		var action = message.substr(3)
		if puppets.has(player_id):
			var puppet = puppets[player_id]
			_handle_puppet_action(puppet, action)

func _handle_puppet_action(puppet, action: String):
	match action:
		"HOWL":
			if puppet.nia_instance.has_method("howl"):
				puppet.nia_instance.howl()
		_:
			pass

func _on_disconnected():
	clear_all_puppets()

func _spawn_puppet(player_id: int, state):
	if state.get_world_hash() != game.active_stage.stage_name.hash():
		return
	
	var puppet = puppet_scene.instantiate()
	puppet.id = player_id
	puppet.name = NAMES[player_id % len(NAMES)]
	if state.has_position():
		var pos_data = state.get_position().get_vector()
		if pos_data.size() >= 3:
			var spawn_pos = Vector3(pos_data[0], pos_data[1], pos_data[2])
			puppet.teleport_to(spawn_pos)
	puppet.apply_state(state)
	
	spawn_parent.add_child(puppet)
	puppets[player_id] = puppet
	puppet_spawned.emit(player_id)
	ModLoaderLog.info("Spawned puppet for player %d" % player_id, self.name)

func clear_all_puppets():
	for player_id in puppets.keys():
		var puppet = puppets[player_id]
		if puppet:
			puppet.queue_free()
	puppets.clear()
	ModLoaderLog.info("Cleared all puppets", self.name)
	puppets_cleared.emit()

func get_puppet(player_id: int) -> Node:
	return puppets.get(player_id, null)

func get_all_puppets() -> Array[CharacterBody3D]:
	var result: Array[CharacterBody3D] = []
	for puppet in puppets.values():
		result.append(puppet.nia_instance)
	return result

func get_puppet_count() -> int:
	return puppets.size()
