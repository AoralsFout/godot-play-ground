extends Control

signal opened
signal closed

var is_open := false
var showing_players := false
var overlay: ColorRect
var panel: PanelContainer
var content: VBoxContainer
var player_rows: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UIStyle.theme()
	UIStyle.fill(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.065, 0.10, 0.76)
	add_child(overlay)
	UIStyle.fill(overlay)
	var center := CenterContainer.new()
	overlay.add_child(center)
	UIStyle.fill(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	content = VBoxContainer.new()
	panel.add_child(content)
	Session.players_changed.connect(_update_players)
	resized.connect(_resize_panel)
	overlay.hide()


func open_menu() -> void:
	is_open = true
	opened.emit()
	Session.input_blocked = true
	get_tree().paused = not Session.is_multiplayer
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.show()
	_show_actions()


func close_menu() -> void:
	is_open = false
	showing_players = false
	overlay.hide()
	get_tree().paused = false
	Session.input_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func back() -> void:
	if showing_players:
		_show_actions()
	else:
		close_menu()


func _clear() -> void:
	player_rows = null
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()


func _resize_panel() -> void:
	panel.custom_minimum_size.x = minf(640 if showing_players else 380, maxf(280, size.x - 32))


func _show_actions() -> void:
	showing_players = false
	_clear()
	_resize_panel()
	content.add_child(UIStyle.label("游戏菜单", 30))
	content.add_child(UIStyle.label("房间继续运行" if Session.is_multiplayer else "游戏已暂停", 15, UIStyle.MUTED))
	var resume := UIStyle.button("继续游戏", close_menu)
	content.add_child(resume)
	if Session.is_multiplayer:
		content.add_child(UIStyle.button("玩家列表", _show_players))
	content.add_child(UIStyle.button("返回到主菜单", Session.return_to_menu))
	content.add_child(UIStyle.button("退出游戏", func() -> void: get_tree().quit()))
	resume.grab_focus.call_deferred()


func _show_players() -> void:
	showing_players = true
	_clear()
	_resize_panel()
	content.add_child(UIStyle.label("玩家列表", 30))
	content.add_child(UIStyle.label("延迟为各玩家与房主之间的往返时间", 14, UIStyle.MUTED))
	var header := HBoxContainer.new()
	content.add_child(header)
	var name_header := UIStyle.label("昵称", 15, UIStyle.MUTED)
	name_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_header)
	var ping_header := UIStyle.label("延迟", 15, UIStyle.MUTED)
	ping_header.custom_minimum_size.x = 88
	header.add_child(ping_header)
	if Session.is_host():
		var actions_header := UIStyle.label("操作", 15, UIStyle.MUTED)
		actions_header.custom_minimum_size.x = 112
		header.add_child(actions_header)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = minf(240, maxf(100, size.y - 310))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	player_rows = VBoxContainer.new()
	player_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(player_rows)
	_update_players()
	var back_button := UIStyle.button("返回", _show_actions)
	content.add_child(back_button)
	back_button.grab_focus.call_deferred()


func _update_players() -> void:
	if not is_open or not showing_players or player_rows == null:
		return
	for row in player_rows.get_children():
		if not Session.players.has(int(row.name)):
			player_rows.remove_child(row)
			row.queue_free()
	for id: int in Session.players:
		var row := player_rows.get_node_or_null(str(id)) as HBoxContainer
		if row == null:
			row = HBoxContainer.new()
			row.name = str(id)
			player_rows.add_child(row)
			var name_label := UIStyle.label("")
			name_label.name = "Nickname"
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			row.add_child(name_label)
			var ping_label := UIStyle.label("", 16, UIStyle.ACCENT)
			ping_label.name = "Ping"
			ping_label.custom_minimum_size.x = 88
			row.add_child(ping_label)
			if Session.is_host():
				if id == 1:
					var own := UIStyle.label("房主", 16, UIStyle.MUTED)
					own.custom_minimum_size.x = 112
					row.add_child(own)
				else:
					var kick := UIStyle.button("踢出房间", Session.kick_player.bind(id))
					kick.custom_minimum_size.x = 112
					row.add_child(kick)
		var suffix := "（房主）" if id == 1 else ""
		if id == Session.local_id():
			suffix += "（你）"
		row.get_node("Nickname").text = str(Session.players[id]["nickname"]) + suffix
		var ping: int = Session.players[id]["ping"]
		row.get_node("Ping").text = "测量中…" if ping < 0 else "%d ms" % ping
