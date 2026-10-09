## 自由相机功能验收。
## 检查相机切换与输入阻塞；加 -- --render 验证鼠标、飞行和界面截图。

extends SceneTree
## 无界面模式验证切换/输入阻塞；-- --render 验证鼠标捕获、飞行和 GUI 截图。

var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _tab() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_TAB
	event.keycode = KEY_TAB
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.physical_keycode = KEY_TAB
	event.keycode = KEY_TAB
	Input.parse_input_event(event)
	await _frames(2)

func _run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	var session := root.get_node("Session")
	var game := (load("res://scenes/core/根节点.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.get_node("世界场景/世界环境").sun_auto_rotate = false
	var player: Node3D = game.avatars[session.local_id()]
	var gui := game.get_node("GUI")
	# 让角色先落地，测试进入自由模式后保持位置。
	await create_timer(0.3).timeout
	_check(gui.debug_info.text.begins_with("FPS: "), "GUI 没有 FPS 调试信息")
	_check(player.camera.is_current(), "默认没有使用第三人称相机")
	var original_view: Transform3D = player.camera.global_transform
	await _tab()
	_check(player.free_camera_enabled and player.free_camera.is_current(), "Tab 没有切换到自由相机")
	_check(player.free_camera.global_transform.is_equal_approx(original_view), "自由相机没有复制当前视角")
	_check(gui.debug_info.text.contains("自由相机"), "GUI 没有更新相机模式")
	var body_position: Vector3 = player.global_position
	var camera_position: Vector3 = player.free_camera.global_position
	Input.action_press("玩家前移")
	await create_timer(0.1).timeout
	Input.action_release("玩家前移")
	if render:
		_check(player.free_camera.global_position.distance_to(camera_position) > 0.1, "W 没有移动自由相机")
	_check(player.global_position.is_equal_approx(body_position), "自由相机移动时角色也移动了")
	var height: float = player.free_camera.global_position.y
	Input.action_press("玩家跳跃")
	await create_timer(0.1).timeout
	Input.action_release("玩家跳跃")
	if render:
		_check(player.free_camera.global_position.y > height, "Space 没有上升")
	var before_rotation: Vector3 = player.free_camera.rotation
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(40, -20)
	player._unhandled_input(motion)
	if render:
		_check(not player.free_camera.rotation.is_equal_approx(before_rotation), "鼠标没有旋转自由相机")
	gui.chat.open_chat()
	camera_position = player.free_camera.global_position
	before_rotation = player.free_camera.rotation
	await _tab()
	Input.action_press("玩家前移")
	await create_timer(0.1).timeout
	Input.action_release("玩家前移")
	player._unhandled_input(motion)
	_check(player.free_camera_enabled, "聊天中 Tab 切换了相机")
	_check(player.free_camera.global_position.is_equal_approx(camera_position), "聊天中自由相机仍在移动")
	_check(player.free_camera.rotation.is_equal_approx(before_rotation), "聊天中鼠标仍在转动相机")
	gui.chat.close_chat()
	gui.game_menu.open_menu()
	await _tab()
	_check(player.free_camera_enabled, "菜单中 Tab 切换了相机")
	gui.game_menu.close_menu()
	await _tab()
	_check(not player.free_camera_enabled and player.camera.is_current(), "Tab 没有恢复第三人称")
	_check(gui.debug_info.text.contains("第三人称"), "GUI 没有恢复第三人称提示")
	var remote := (load("res://scenes/player/玩家.tscn") as PackedScene).instantiate()
	remote.is_local = false
	game.add_child(remote)
	remote.toggle_free_camera()
	_check(remote.free_camera == null and not remote.free_camera_enabled, "远程角色启用了自由相机")
	if render:
		await _tab()
		var deadline := Time.get_ticks_msec() + 30000
		var clouds := game.get_node("世界场景/体积云")
		while clouds.cloud_material.get_shader_parameter("noise_ready") != true and Time.get_ticks_msec() < deadline:
			await process_frame
		player.free_camera.look_at(player.free_camera.global_position + Vector3(-0.37, 0.2, 0.93))
		await _frames(12)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.godot/camera-validation")
		root.get_texture().get_image().save_png("res://.godot/camera-validation/free_camera.png")
	print("自由相机与 FPS 验收：%s" % ("通过" if _failures == 0 else "%d 项失败" % _failures))
	game.queue_free()
	await _frames(3)
	quit(0 if _failures == 0 else 1)
