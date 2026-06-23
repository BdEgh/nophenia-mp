extends interactable
class_name patched_interactable

func interact() -> bool:
    if !is_trigger:
        if game.active_stage.anomaly_occurring or uninteractable:
            get_tree().get_first_node_in_group("player").no()
            return false
        else:
            match _id:
                1:
                    create_tween().tween_property(get_tree().get_first_node_in_group("player").chara, "global_rotation_degrees:y", _offset_rot, 0.2)
                    create_tween().tween_property(get_tree().get_first_node_in_group("player"), "global_position", self.global_position + _offset, 0.2)
                    await get_tree().get_first_node_in_group("player").sit(true)
                    return false
                2:
                    audio.play_snd(_interact_sfx, -1.0, 0.2)
                    game.to_entrance = _to_entrance
                    if config.last_visited and config.last_visited != "stage_bedroom" and config.last_visited != "stage_fog":
                        change_stage(config.last_visited)
                    else:
                        change_stage(_to_stage)
                _:
                    audio.play_snd(_interact_sfx, -1.0, 0.2)
                    game.to_entrance = _to_entrance
                    change_stage(_to_stage)
    return true

func change_stage(_stage: String = ""):
    if !_stage:
        change_stage_rand()
        return
    game.change_stage(_stage)

func change_stage_rand():
    var mp = get_tree().get_first_node_in_group("mp")
    var rng_seed = mp.mp_cfg.rng_seed
    seed(rng_seed)
    var pool = game._traverse_random.duplicate()
    pool.shuffle()
    game.to_entrance = 0
    for _n in pool:
        var _dream = ResourceUID.get_id_path(ResourceUID.text_to_id(_n)).get_file().get_basename()
        if _dream not in config.visited:
            change_stage(_dream)
            return

    config.visited.clear()
    config.last_visited = "stage_end"
    game._dream_attempt = 0
    mp.mp_cfg.rng_seed = randi()

    change_stage("stage_title")
    get_window().request_attention()
