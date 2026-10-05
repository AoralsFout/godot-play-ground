extends Control

var content: VBoxContainer
var panel: PanelContainer
var status_label: Label
var nickname_input: LineEdit
var ip_input: LineEdit
var port_input: LineEdit
var submit_button: Button
var page := "main"
var room_draft := {"nickname": "玩家", "host_ip": "0.0.0.0", "join_ip": "127.0.0.1", "port": "7000"}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = UIStyle.theme()
	var background := ColorRect.new()
	background.color = Color("315d78")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	UIStyle.fill(background)
	var band := ColorRect.new()
	band.color = Color("24485f")
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	band.offset_top = -170
	var center := CenterContainer.new()
	add_child(center)
	UIStyle.fill(center)
	var scroll := ScrollContainer.new()
	center.add_child(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = 420
	scroll.add_child(panel)
	content = VBoxContainer.new()
	panel.add_child(content)
	content.minimum_size_changed.connect(_resize_panel.bind(scroll))
	var footer := UIStyle.label("WASD 移动  ·  空格跳跃  ·  Esc 菜单  ·  T 聊天", 14, UIStyle.MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(footer)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -38
	Session.connection_status_changed.connect(_connection_status)
	resized.connect(_resize_panel.bind(scroll))
	_resize_panel(scroll)
	_show_main()


func _resize_panel(scroll: ScrollContainer) -> void:
	panel.custom_minimum_size.x = minf(420, maxf(280, size.x - 32))
	scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y + 52, maxf(200, size.y - 80))
	scroll.custom_minimum_size.x = panel.custom_minimum_size.x


func _clear(title: String, subtitle: String) -> void:
	content.add_theme_constant_override("separation", 12)
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	status_label = null
	var brand := UIStyle.label("PLAYGROUND", 14, UIStyle.ACCENT)
	content.add_child(brand)
	content.add_child(UIStyle.label(title, 34))
	var description := UIStyle.label(subtitle, 15, UIStyle.MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	content.add_child(HSeparator.new())


func _add_button(text: String, action: Callable, first: bool = false) -> Button:
	var control := UIStyle.button(text, action)
	content.add_child(control)
	if first:
		control.grab_focus.call_deferred()
	return control


func _add_status(message: String = "") -> void:
	status_label = UIStyle.label(message, 15, UIStyle.ACCENT)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)
	status_label.visible = not message.is_empty()


func _set_status(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()


func _show_main() -> void:
	page = "main"
	_clear("游乐场", "独自探索，或和朋友一起出发。")
	_add_button("单人模式", Session.start_single_player, true)
	_add_button("多人模式", _show_multiplayer)
	_add_button("设置", _show_settings)
	_add_button("退出游戏", func() -> void: get_tree().quit())
	_add_status(Session.menu_notice)
	Session.menu_notice = ""


func _show_multiplayer() -> void:
	page = "multiplayer"
	_clear("多人模式", "创建房间，或通过 IP 加入朋友的房间。")
	_add_button("创建房间", _show_room.bind(true), true)
	_add_button("加入房间", _show_room.bind(false))
	_add_button("返回", _show_main)


func _field(title: String, value: String, placeholder: String, limit: int) -> LineEdit:
	content.add_child(UIStyle.label(title, 16, UIStyle.MUTED))
	var field := LineEdit.new()
	field.text = value
	field.placeholder_text = placeholder
	field.max_length = limit
	field.custom_minimum_size.y = 44
	content.add_child(field)
	return field


func _show_room(hosting: bool) -> void:
	page = "host" if hosting else "join"
	_clear("创建房间" if hosting else "加入房间",
		"监听 IP 可填 0.0.0.0；朋友使用这台电脑的局域网 IP 加入。" if hosting else "填写房主的 IP 地址和端口。")
	content.add_theme_constant_override("separation", 8)
	nickname_input = _field("昵称", room_draft["nickname"], "请输入昵称", 24)
	ip_input = _field("监听 IP" if hosting else "房主 IP", room_draft["host_ip" if hosting else "join_ip"], "192.168.1.10", 45)
	port_input = _field("端口", room_draft["port"], "7000", 5)
	submit_button = _add_button("创建并进入" if hosting else "加入并进入", _submit_room.bind(hosting))
	_add_button("返回", _back_from_room)
	_add_status()
	nickname_input.grab_focus.call_deferred()
	port_input.text_submitted.connect(func(_value: String) -> void: _submit_room(hosting))


func _save_draft() -> void:
	room_draft["nickname"] = nickname_input.text
	room_draft["host_ip" if page == "host" else "join_ip"] = ip_input.text
	room_draft["port"] = port_input.text


func _submit_room(hosting: bool) -> void:
	if Session.connecting:
		return
	_save_draft()
	var address := ip_input.text.strip_edges()
	var port_text := port_input.text.strip_edges()
	var validation := Session.validate_room(nickname_input.text, address, port_text, hosting)
	if not validation.is_empty():
		_set_status(validation)
		return
	var error: Error
	if hosting:
		error = Session.host_room(nickname_input.text, address, int(port_text))
	else:
		error = Session.join_room(nickname_input.text, address, int(port_text))
	if error != OK:
		_set_status("无法创建房间：IP 不属于本机，或端口已被占用。" if hosting else "无法发起连接，请检查 IP 和端口。")
	elif not hosting:
		_set_connecting(true)


func _set_connecting(value: bool) -> void:
	submit_button.disabled = value
	nickname_input.editable = not value
	ip_input.editable = not value
	port_input.editable = not value
	submit_button.text = "连接中…" if value else "加入并进入"


func _connection_status(message: String) -> void:
	if page != "join" or status_label == null:
		return
	_set_status(message)
	_set_connecting(Session.connecting)


func _back_from_room() -> void:
	_save_draft()
	Session.cancel_connection()
	_show_multiplayer()


func _show_settings() -> void:
	page = "settings"
	_clear("设置", "以下为占位设置，暂不改变游戏配置。")
	for title: String in ["主音量", "音乐音量", "鼠标灵敏度"]:
		content.add_child(UIStyle.label(title, 16, UIStyle.MUTED))
		var slider := HSlider.new()
		slider.value = 60
		slider.editable = false
		content.add_child(slider)
	var check := CheckButton.new()
	check.text = "全屏显示（占位）"
	check.disabled = true
	content.add_child(check)
	var quality := OptionButton.new()
	quality.add_item("画质：标准（占位）")
	quality.disabled = true
	content.add_child(quality)
	_add_button("返回", _show_main, true)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		match page:
			"host", "join": _back_from_room()
			"multiplayer", "settings": _show_main()
		get_viewport().set_input_as_handled()
