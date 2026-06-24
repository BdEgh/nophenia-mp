#class_name MultiplayerPuppetManager
extends Node

signal puppet_spawned(player_id: int)
signal puppet_removed(player_id: int)
signal puppets_cleared()

var MultiplayerClientProto = load(get_script().resource_path.get_base_dir() + "/client_api.gd")

@export var client: Node:
    set(value):
        if value == client:
            return
        _disconnect_client()
        client = value
        if client == null:
            clear_all_puppets()
        _connect_client()
@export var puppet_scene: PackedScene

var stage_node: stage

var all_players: Dictionary = {}  # player_id -> world_hash
var puppets: Dictionary = {}  # player_id -> MultiplayerPuppet instance

func _ready():
    stage_node = game.active_stage

func _connect_client() -> void:
    if client == null or client.player_set.is_connected(_on_player_set):
        return
    client.player_set.connect(_on_player_set)
    client.player_delete.connect(_on_player_delete)
    client.player_message.connect(_on_player_message)
    client.disconnected_from_server.connect(_on_disconnected)

func _disconnect_client() -> void:
    if client == null or not client.player_set.is_connected(_on_player_set):
        return
    client.player_set.disconnect(_on_player_set)
    client.player_delete.disconnect(_on_player_delete)
    client.player_message.disconnect(_on_player_message)
    client.disconnected_from_server.disconnect(_on_disconnected)

func _on_player_set(player_id: int, state, player_name: String):
    if state.get_world_hash():
        all_players[player_id] = state.get_world_hash()
    if puppets.has(player_id) and puppets[player_id]:
        if state.get_world_hash() and state.get_world_hash() != game.active_stage.stage_name.hash():
            _on_player_delete(player_id)
            return
        var puppet = puppets[player_id]
        puppet.set_player_name(_resolve_name(player_id, player_name))
        puppet.apply_state(state)
    elif state.get_world_hash():
        _spawn_puppet(player_id, state, player_name)

func _on_player_delete(player_id: int):
    if puppets.has(player_id):
        var puppet = puppets[player_id]
        puppet.queue_free()
        puppets.erase(player_id)
        all_players.erase(player_id)
        ModLoaderLog.info("MultiplayerPuppetManager: Removed puppet for player %d" % player_id, self.name)
        puppet_removed.emit(player_id)

func _on_player_message(player_id: int, message: String, _player_name: String):
    if message.begins_with("DO:"):
        var action = message.substr(3)
        if puppets.has(player_id):
            var puppet = puppets[player_id]
            _handle_puppet_action(puppet, action)

func _handle_puppet_action(puppet, action: String):
    var nia = puppet.nia_instance
    var sp = nia.shared_patcher
    match action:
        "HOWL":
            if nia.has_method("howl"):
                nia.howl()
        "DAMAGE":
            sp.damage(true)
        "WOW":
            sp.set_surprised(true)
        "UNWOW":
            sp.set_surprised(false)
        "HALO":
            sp.set_halo(true)
        "UNHALO":
            sp.set_halo(false)
        "YUMENIKKI":
            sp.set_eyes_closed(true)
        "UNYUMENIKKI":
            sp.set_eyes_closed(false)
        "DIZZY":
            sp.dizzy()
        "RAGDOLL":
            sp.ragdoll()
        _:
            pass

func _on_disconnected():
    clear_all_puppets()

func _resolve_name(player_id: int, player_name: String) -> String:
    if player_name != "":
        return player_name
    return str(player_id)

func _spawn_puppet(player_id: int, state, player_name: String):
    if state.get_world_hash() != game.active_stage.stage_name.hash():
        return
    
    var puppet = puppet_scene.instantiate()
    puppet.id = player_id
    puppet.name = str(player_id)
    stage_node.add_child(puppet)
    puppet.set_player_name(_resolve_name(player_id, player_name))
    if state.has_position():
        var pos_data = state.get_position().get_vector()
        if pos_data.size() >= 3:
            var spawn_pos = Vector3(pos_data[0], pos_data[1], pos_data[2])
            puppet.teleport_to(spawn_pos)
    puppet.apply_state(state)

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
