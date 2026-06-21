extends RichTextLabel

var client: Node
var puppet_manager: Node
var default_text: String

var self_id: int

func _ready() -> void:
    default_text = \
"


[center][color=000000b0]𖡼.𖤣𖥧𖡼.𖤣𖥧
[url=https://www.youtube.com/watch?v=bdXPhRj10jQ]Believing in
a lie
That we'll
leave behind[/url]
𖡼.𖤣𖥧𖡼.𖤣𖥧[/color][/center]

"
    
    var pause_menu = game.nia.get_node("pause_menu")
    if pause_menu:
        meta_clicked.connect(pause_menu._on_credit_names_meta_clicked)
        meta_hover_started.connect(pause_menu._on_credit_names_meta_hover_started)
    
    if puppet_manager:
        puppet_manager.puppet_spawned.connect(_on_player_changed)
        puppet_manager.puppet_removed.connect(_on_player_changed)
        puppet_manager.puppets_cleared.connect(_update_info)
    
    _update_info()
    _connect_client(client)

func set_client(new_client: Node) -> void:
    if new_client == client:
        return
    client = new_client
    if is_inside_tree():
        _connect_client(client)
        _update_info()

func _connect_client(c: Node) -> void:
    if not c:
        return
    c.self_id.connect(_on_self_id)
    c.connected_to_server.connect(_update_info)
    c.disconnected_from_server.connect(_update_info)
    c.connection_failed.connect(_update_info)
    c.ping_received.connect(_update_info)

func _on_self_id(id: int) -> void:
    self_id = id

func _on_player_changed(_player_id: int) -> void:
    _update_info()

func _self_name() -> String:
    var mp = get_tree().get_first_node_in_group("mp")
    if mp and mp.mp_cfg.player_name != "":
        return mp.mp_cfg.player_name
    if mp:
        return mp.default_name
    return "unk"

func _puppet_name(player_id: int) -> String:
    var puppet = puppet_manager.puppets.get(player_id)
    if puppet and puppet.player_name != "":
        return puppet.player_name
    return "unk"

func _update_info() -> void:
    if not client:
        text = "[center][color=red]◊[/color] [color=000000b0]No client connected[/color][/center]\n\n\n" + default_text
        return
    
    var info_text = "[center]"
    if client.socket and client.socket.connected():
        info_text += "[color=green]◊[/color] [color=000000b0]Connected[/color]\n\n"
    else:
        info_text += "[color=red]◊[/color] [color=000000b0]Disconnected[/color]\n\n"
    info_text += "[/center]"
    
    info_text += "[color=000000b0]Server[/color]: %s\n\n" % client.url
    
    if puppet_manager:
        if client.total_online >= 0 and client.socket.connected():
            info_text += "[color=000000b0]Total Online:[/color] %d\n" % client.total_online
        
        info_text += "[color=000000b0]On stage:[/color] %d\n" % (puppet_manager.puppets.size() + 1)
        info_text += "- %s%s\n" % [_self_name(), "(you)"]
        var player_ids = puppet_manager.puppets.keys()
        player_ids.sort()
        for player_id in player_ids:
            info_text += "- %s\n" % _puppet_name(player_id)
    
    text = info_text + default_text
