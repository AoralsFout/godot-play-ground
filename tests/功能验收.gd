extends Node
## 运行命令：Godot --headless res://tests/功能验收.tscn -- --suite=single|host|client

var failures := 0
var suite := "single"
var port := 17170


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--suite="):
			suite = arg.trim_prefix("--suite=")
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
	_run.call_deferred()


func _run() -> void:
	# 测试实际场景切换时，保持验收运行器存活。
	get_tree().current_scene = null
	match suite:
		"single": await _single()
		"host": await _host()
		"client": await _client()
		"disconnect_host": await _disconnect_host()
		"disconnect_client": await _disconnect_client()
		"connection_failure": await _connection_failure()
		"visual": await _visual()
	print("RESULT %s: %s" % [suite, "PASS" if failures == 0 else "%d FAILED" % failures])
	Session.cancel_connection()
	get_tree().quit(0 if failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS ", description)
	else:
		failures += 1
		push_error("FAIL " + description)


func _frames(count: int = 3) -> void:
	for _index in count:
		await get_tree().process_frame


func _wait_until(condition: Callable, seconds: float = 10.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return condition.call()


func _buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	for child in node.get_children():
		if child is Button:
			result.append(child)
		result.append_array(_buttons(child))
	return result


func _press(text: String) -> void:
	for button in _buttons(get_tree().current_scene):
		if button.text == text and button.is_visible_in_tree():
			button.pressed.emit()
			await _frames()
			return
	_check(false, "找到按钮 " + text)


func _tap(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _gui() -> CanvasLayer:
	return get_tree().current_scene.get_node("GUI")


func _game_ready() -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.has_node("GUI")


func _has_message(message: String) -> bool:
	for entry in Session.chat_history:
		if entry["message"] == message:
			return true
	return false


func _single() -> void:
	get_tree().change_scene_to_file(Session.MAIN_MENU)
	await _frames()
	_check(_buttons(get_tree().current_scene).size() == 4, "主菜单四个入口")
	await _press("设置")
	_check(get_tree().current_scene.page == "settings", "设置占位页面")
	await _press("返回")
	await _press("多人模式")
	_check(_buttons(get_tree().current_scene).size() == 3, "多人模式三个入口")
	await _press("创建房间")
	var menu := get_tree().current_scene
	_check(menu.ip_input.text == "0.0.0.0" and menu.port_input.text == "7000", "默认监听地址和端口")
	menu.nickname_input.text = "测试中文昵称"
	menu.port_input.text = "0"
	await _press("创建并进入")
	_check(not menu.status_label.text.is_empty() and not Session.is_multiplayer, "非法端口阻止建房")
	await _press("返回")
	await _press("加入房间")
	_check(get_tree().current_scene.nickname_input.text == "测试中文昵称", "房间表单保留昵称")
	await _press("返回")
	await _press("返回")
	await _press("单人模式")
	_check(_game_ready() and not Session.is_multiplayer, "单人直接进入主场景")
	var gui := _gui()
	_check(gui.get_node_or_null(gui.target_camera_path) is Camera3D, "小地图绑定本地玩家")
	await _tap(KEY_ESCAPE)
	_check(gui.game_menu.is_open and get_tree().paused, "Esc 单人暂停")
	var found_players := false
	for button in _buttons(gui):
		found_players = found_players or button.text == "玩家列表"
	_check(not found_players, "单人隐藏玩家列表")
	var avatar: CharacterBody3D = get_tree().current_scene.avatars[1]
	var position_before := avatar.position
	var paused_time: float = get_tree().current_scene.game_time
	await get_tree().create_timer(0.2, true).timeout
	_check(avatar.position == position_before, "暂停期间物理时间停止")
	_check(get_tree().current_scene.game_time == paused_time, "暂停期间水面时间停止")
	await _press("继续游戏")
	_check(not get_tree().paused and not Session.input_blocked, "继续恢复游戏")
	await _tap(KEY_T)
	_check(gui.chat.is_open and Session.input_blocked and not get_tree().paused, "T 打开历史和输入框")
	gui.chat.input.text = "你好，世界！UTF-8 café 🎮"
	await _tap(KEY_ENTER)
	_check(_has_message("你好，世界！UTF-8 café 🎮"), "Enter 发送 UTF-8 聊天")
	_check(not gui.chat.is_open and not Session.input_blocked, "发送后恢复角色操作")
	_check(gui.chat.recent.get_child_count() == 1, "新消息插入左下角列表")
	await get_tree().create_timer(8.2, true).timeout
	_check(gui.chat.recent.get_child_count() == 0 and Session.chat_history.size() == 1, "消息八秒消失并保留历史")
	await _tap(KEY_T)
	_check(gui.chat.history_list.get_child_count() == 1, "T 再次显示历史")
	await _tap(KEY_ESCAPE)
	_check(not gui.chat.is_open and not gui.game_menu.is_open, "Esc 优先收起聊天")
	await _tap(KEY_ESCAPE)
	await _press("返回到主菜单")
	_check(get_tree().current_scene.name == "主菜单" and not get_tree().paused, "返回主菜单解除暂停")
	await _press("多人模式")
	await _press("加入房间")
	menu = get_tree().current_scene
	menu.port_input.text = str(port)
	await _press("加入并进入")
	_check(Session.connecting and menu.submit_button.disabled, "连接期间禁用重复加入")
	await _press("返回")
	_check(not Session.connecting and Session.peer == null, "返回取消待连接房间")
	_check(Session.validate_room("昵称", "0.0.0.0", "7000", false) != "", "加入禁止监听地址")
	_check(Session.validate_room("昵称", "invalid", "7000", true) != "", "非法 IP 校验")


func _host() -> void:
	_check(Session.host_room("房主中文", "127.0.0.1", port) == OK, "房主创建 ENet 房间")
	await _frames()
	print("HOST_READY")
	_check(await _wait_until(func() -> bool: return Session.players.size() == 2), "房主收到客户端注册")
	if Session.players.size() != 2:
		return
	var client_id: int = Session.players.keys().filter(func(id: int) -> bool: return id != 1)[0]
	_check(Session.players[client_id]["nickname"] == "访客中文", "中文昵称同步")
	var duplicate_peer := ENetMultiplayerPeer.new()
	duplicate_peer.set_bind_ip("127.0.0.1")
	_check(duplicate_peer.create_server(port) != OK, "占用端口阻止重复创建房间")
	duplicate_peer.close()
	await _tap(KEY_ESCAPE)
	_check(_gui().game_menu.is_open and not get_tree().paused, "房主 Esc 不暂停")
	var live_time: float = get_tree().current_scene.game_time
	await get_tree().create_timer(0.2).timeout
	_check(get_tree().current_scene.game_time > live_time, "多人菜单期间世界时间继续")
	await _press("玩家列表")
	_check(_gui().game_menu.player_rows.get_child_count() == 2, "房主显示完整列表")
	var has_kick := false
	for button in _buttons(_gui().game_menu):
		has_kick = has_kick or button.text == "踢出房间"
	_check(has_kick, "房主具有踢人按钮")
	_check(await _wait_until(func() -> bool: return _has_message("访客消息：你好 🎮")), "收到客户端 UTF-8 消息")
	Session.send_chat("房主消息：欢迎 café")
	_check(await _wait_until(func() -> bool: return _has_message("准备好被踢出")), "客户端已完成验证")
	_check(Session.player_states.has(client_id), "客户端移动状态传输到房主")
	Session.kick_player(client_id)
	_check(await _wait_until(func() -> bool: return Session.players.size() == 1), "踢人后移除玩家")
	await get_tree().create_timer(1.0).timeout


func _client() -> void:
	_check(Session.join_room("访客中文", "127.0.0.1", port) == OK, "客户端连接 ENet 房间")
	_check(await _wait_until(_game_ready), "加入成功进入主场景")
	if not _game_ready():
		return
	_check(Session.players.size() == 2, "客户端收到完整玩家列表")
	_check(get_tree().current_scene.avatars.size() == 2, "双方角色生成")
	_check(get_tree().current_scene.avatars[Session.local_id()].camera.current, "客户端使用本地角色摄像机")
	await _tap(KEY_ESCAPE)
	_check(_gui().game_menu.is_open and not get_tree().paused, "客户端 Esc 不暂停")
	await _press("玩家列表")
	var has_kick := false
	for button in _buttons(_gui().game_menu):
		has_kick = has_kick or button.text == "踢出房间"
	_check(not has_kick, "客户端没有踢人操作")
	await _tap(KEY_ESCAPE)
	await _press("继续游戏")
	Session.send_chat("访客消息：你好 🎮")
	_check(await _wait_until(func() -> bool: return _has_message("房主消息：欢迎 café")), "收到房主广播的 UTF-8 消息")
	_check(await _wait_until(func() -> bool: return Session.players[Session.local_id()]["ping"] >= 0), "客户端收到实际延迟")
	_check(Session.player_states.has(1), "房主角色状态同步")
	await get_tree().create_timer(0.35).timeout
	Session.send_chat("准备好被踢出")
	_check(await _wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "主菜单"), "被踢后返回主菜单")
	_check(not Session.is_multiplayer and Session.peer == null and not get_tree().paused, "被踢后清理连接和暂停")
	_check(get_tree().current_scene.status_label.text.contains("踢出"), "显示踢人原因")


func _disconnect_host() -> void:
	_check(Session.host_room("房主", "127.0.0.1", port) == OK, "创建断线测试房间")
	await _frames()
	print("HOST_READY")
	_check(await _wait_until(func() -> bool: return _has_message("等待房主离开")), "客户端已进入")
	Session.return_to_menu()
	await _frames()
	await get_tree().create_timer(1.0).timeout


func _disconnect_client() -> void:
	Session.join_room("访客", "127.0.0.1", port)
	_check(await _wait_until(_game_ready), "进入断线测试房间")
	Session.send_chat("等待房主离开")
	_check(await _wait_until(func() -> bool: return get_tree().current_scene != null and get_tree().current_scene.name == "主菜单"), "房主离开后客户端返回菜单")
	_check(get_tree().current_scene.status_label.text.contains("断开"), "显示房主断线原因")


func _connection_failure() -> void:
	get_tree().change_scene_to_file(Session.MAIN_MENU)
	await _frames()
	await _press("多人模式")
	await _press("加入房间")
	var menu := get_tree().current_scene
	menu.port_input.text = str(port)
	await _press("加入并进入")
	_check(await _wait_until(func() -> bool: return not Session.connecting, 12.0), "连接无效房间会超时")
	_check(not menu.submit_button.disabled and menu.ip_input.editable, "失败后恢复表单编辑")
	_check(not menu.status_label.text.is_empty() and menu.status_label.visible, "显示连接失败原因")
	_check(Session.peer == null and not Session.is_multiplayer, "失败后清理连接")


func _capture(filename: String) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/" + filename + ".png")


func _visual() -> void:
	get_tree().change_scene_to_file(Session.MAIN_MENU)
	await _capture("main_menu")
	await _press("多人模式")
	await _press("创建房间")
	await _capture("room_form")
	await _press("返回")
	await _press("返回")
	await _press("单人模式")
	await _tap(KEY_ESCAPE)
	await _capture("pause_menu")
	await _press("继续游戏")
	Session.send_chat("你好！欢迎来到游乐场。 🎮")
	await _tap(KEY_T)
	await _capture("chat")
