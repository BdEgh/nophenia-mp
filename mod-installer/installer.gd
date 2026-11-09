extends Control

@onready var orig_game_line: LineEdit = %OrigGameLine
@onready var orig_button: Button = %OrigButton
@onready var orig_fd: FileDialog = %OrigFD
@onready var patched_game_line: LineEdit = %PatchedGameLine
@onready var patched_button: Button = %PatchedButton
@onready var patched_fd: FileDialog = %PatchedFD
@onready var desktop_shortcut_button: CheckBox = %DesktopShortcutButton
@onready var experimental_button: CheckBox = %ExperimentalButton
@onready var install_button: Button = %InstallButton
@onready var star_0: RichTextLabel = %Star0
@onready var star_1: RichTextLabel = %Star1
@onready var star_2: RichTextLabel = %Star2

var counter := 0
var valid_orig := false:
	set(value):
		valid_orig = value
		if valid_orig and valid_patched:
			install_button.disabled = false
		else:
			install_button.disabled = true
var valid_patched := false:
	set(value):
		valid_patched = value
		if valid_orig and valid_patched:
			install_button.disabled = false
		else:
			install_button.disabled = true

func _ready() -> void:
	var game_path := find_steam_game_path()
	orig_game_line.text = game_path
	patched_game_line.text = game_path
	_on_orig_game_line_text_changed(game_path)
	_on_patched_game_line_text_changed(game_path)

func find_steam_game_path() -> String:
	var steam_path := ""
	if OS.get_name() == "Windows":
		var pf = OS.get_environment("ProgramFiles(x86)")
		steam_path = pf.path_join("Steam")
	elif OS.get_name() == "Linux":
		steam_path = OS.get_environment("HOME").path_join(".steam/steam")
	if steam_path.is_empty():
		return ""
	
	var library_file = steam_path.path_join("steamapps/libraryfolders.vdf")
	if not FileAccess.file_exists(library_file):
		return ""
	var steamapps: Array[String] = [steam_path.path_join("steamapps")]
	var file := FileAccess.open(library_file, FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if line.strip_edges().begins_with("\"path\""):
			var path := line.split("\"")[3]
			var apps = path.path_join("steamapps")
			steamapps.append(apps)
	file.close()
	
	for apps in steamapps:
		var game_path = apps.path_join("common").path_join("nophenia").replace("\\", "/").simplify_path()
		if DirAccess.dir_exists_absolute(game_path):
			return game_path
	for apps in steamapps:
		var game_path = apps.path_join("common").path_join("nophenia Demo").replace("\\", "/").simplify_path()
		if DirAccess.dir_exists_absolute(game_path):
			return game_path
	return ""

func _on_orig_fd_dir_selected(dir: String) -> void:
	orig_game_line.text = dir
	_on_orig_game_line_text_changed(dir)

func _on_orig_button_pressed() -> void:
	orig_fd.popup_centered_ratio()

func _on_patched_fd_dir_selected(dir: String) -> void:
	patched_game_line.text = dir
	_on_patched_game_line_text_changed(dir)

func _on_patched_button_pressed() -> void:
	patched_fd.popup_centered_ratio()

func _replace_color(text: String, color: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[color=[^\\]]+\\]")
	var replacement = "[color=%s]" % color
	return regex.sub(text, replacement)

func _fetch_exec(path: String) -> String:
	if FileAccess.file_exists(path.path_join("nophenia.exe")):
		return path.path_join("nophenia.exe")
	elif FileAccess.file_exists(path.path_join("nophenia.x86_64")):
		return path.path_join("nophenia.x86_64")
	return ""

func _on_orig_game_line_text_changed(new_text: String) -> void:
	if _fetch_exec(new_text) != "":
		star_0.text = _replace_color(star_0.text, "white")
		valid_orig = true
	else:
		star_0.text = _replace_color(star_0.text, "#818589")
		valid_orig = false

func _on_patched_game_line_text_changed(new_text: String) -> void:
	if DirAccess.dir_exists_absolute(new_text):
		star_1.text = _replace_color(star_0.text, "white")
		valid_patched = true
	else:
		star_1.text = _replace_color(star_0.text, "#818589")
		valid_patched = false

func _copy_files(from: String, to: String) -> void:
	for file in DirAccess.get_files_at(from):
		DirAccess.copy_absolute(from.path_join(file), to.path_join(file))

func _copy_recursive(from: String, to: String) -> void:
	if not DirAccess.dir_exists_absolute(to):
		DirAccess.make_dir_recursive_absolute(to)
	for file in DirAccess.get_files_at(from):
		DirAccess.copy_absolute(from.path_join(file), to.path_join(file))
	for folder in DirAccess.get_directories_at(from):
		_copy_recursive(from.path_join(folder), to.path_join(folder))

func _change_icon() -> void:
	if OS.get_name() == "Windows":
		var args = [patched_game_line.text.path_join("nophenia.exe"), "--set-icon", ProjectSettings.globalize_path("res://assets/game-icon.ico")]
		OS.execute(ProjectSettings.globalize_path("res://rcedit-x64.exe"), args)

func _create_desktop_shortcut() -> void:
	if OS.get_name() == "Windows":
		var exec_path = _fetch_exec(patched_game_line.text)
		var lnk = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).path_join("nophenia-mp.lnk").replace("/", "\\")
		var ps_cmd = "$s=(New-Object -ComObject WScript.Shell).CreateShortcut('%s');$s.TargetPath='%s';$s.Save()" % [lnk, exec_path]
		OS.execute("powershell", ["-Command", ps_cmd])
	elif OS.get_name() == "Linux":
		var icon_file := patched_game_line.text.path_join("icon.png")
		DirAccess.copy_absolute(ProjectSettings.globalize_path("res://assets/game-icon.png"), icon_file)
		var desk = OS.get_environment("HOME").path_join("Desktop")
		var lnk = desk.path_join("nophenia-mp.desktop")
		var exec_path = _fetch_exec(patched_game_line.text)
		OS.execute("chmod", ["+x", exec_path])
		var content = "[Desktop Entry]\nType=Application\nName=nophenia-mp\nExec=%s\nPath=%s\nIcon=%s\n" % [exec_path, patched_game_line.text, icon_file]
		var file = FileAccess.open(lnk, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()
			OS.execute("chmod", ["+x", lnk])

func _add_experimental_stuff() -> void:
	pass # TODO

func _on_install_button_pressed() -> void:
	install_button.disabled = true
	
	_copy_files(orig_game_line.text, patched_game_line.text)
	_copy_recursive(ProjectSettings.globalize_path("res://mod_loader_artifacts"), patched_game_line.text)
	_change_icon()
	if desktop_shortcut_button.button_pressed:
		_create_desktop_shortcut()
	if experimental_button.button_pressed:
		_add_experimental_stuff()
	OS.alert("Success!", "Patch status")
	OS.shell_open(patched_game_line.text)
	
	install_button.disabled = false
	star_2.text = "[wave amp=60.0 freq=1 connected=1]✦"

func _extra_check():
	if randi_range(0, 99 - min(counter, 90)) == 0:
		experimental_button.visible = true

func _on_desktop_shortcut_button_pressed() -> void:
	counter += 1
	_extra_check()
