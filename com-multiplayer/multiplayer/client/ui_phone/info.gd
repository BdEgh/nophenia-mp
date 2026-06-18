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
    
    var nia = game.find("player")
    if nia:
        var pause_menu = nia.get_node("pause_menu")
        if pause_menu:
            meta_clicked.connect(pause_menu._on_credit_names_meta_clicked)
            meta_hover_started.connect(pause_menu._on_credit_names_meta_hover_started)
    
    if client:
        client.self_id.connect(_on_self_id)
        client.connected_to_server.connect(_update_info)
        client.disconnected_from_server.connect(_update_info)
        client.connection_failed.connect(_update_info)
    
    if puppet_manager:
        puppet_manager.puppet_spawned.connect(_on_player_changed)
        puppet_manager.puppet_removed.connect(_on_player_changed)
        puppet_manager.puppets_cleared.connect(_update_info)
    
    _update_info()

func _on_self_id(id: int) -> void:
    self_id = id

func _on_player_changed(_player_id: int) -> void:
    _update_info()

func _update_info() -> void:
    if not client:
        text = "[color=red][center]No client connected[/center][/color]"
        return
    
    var info_text = "[center]"
    if client.socket and client.socket.connected():
        info_text += "[color=green]●[/color] [color=000000b0]Connected[/color]\n\n"
    else:
        info_text += "[color=red]●[/color] [color=000000b0]Disconnected[/color]\n\n"
    info_text += "[/center]"
    
    info_text += "[color=000000b0]Server[/color]: %s\n\n" % client.url
    
    if puppet_manager:
        info_text += "[color=000000b0]Online:[/color] %d\n" % (puppet_manager.all_players.size() + 1)
        
        info_text += "[color=000000b0]On stage:[/color]\n"
        info_text += "- %s%s\n" % [puppet_manager.NAMES[self_id % len(puppet_manager.NAMES)], "(you)"]
        var player_ids = puppet_manager.puppets.keys()
        player_ids.sort()
        for player_id in player_ids:
            info_text += "- %s\n" % puppet_manager.NAMES[player_id % len(puppet_manager.NAMES)]
    
    text = info_text + default_text
