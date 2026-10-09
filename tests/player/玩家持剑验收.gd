## 玩家持剑功能验收。
## 检查 Q 键去重、装备显隐、各动作持剑切换、输入阻塞及远程状态。

extends SceneTree
## 实际玩家场景验证 Q、持剑动作、剑显示、输入保护与远程状态。

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _step(player: CharacterBody3D, count: int) -> void:
	for frame in count:
		await physics_frame
		player._physics_process(1.0 / 60.0)


func _q(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_Q
	event.keycode = KEY_Q
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _toggle_q() -> void:
	_q(true)
	await process_frame
	_q(false)
	await process_frame


func _land(player: CharacterBody3D) -> void:
	for frame in 120:
		await _step(player, 1)
		if player.is_on_floor():
			return
	_check(false, "玩家没有在预期时间内落地")


func _run() -> void:
	var session := root.get_node("Session")
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100, 1, 100)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player = (load("res://scenes/player/玩家.tscn") as PackedScene).instantiate()
	player.position.y = 2.0
	world.add_child(player)
	player.set_physics_process(false)
	await _land(player)
	var model: PlayerAnimationStateMachine = player.player_model
	var animator := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var sword := model.get_node(model.sword_mesh_path) as GeometryInstance3D
	_check(not player.sword_equipped and not sword.visible and model.get_locomotion_animation() == "Idle", "初始状态不是空手待机")
	for animation_name: StringName in [&"Idle-with-sword", &"walk-with-sword", &"run-with-sword", &"falling-with-sword"]:
		_check(animator.has_animation(animation_name), "模型缺少 %s" % animation_name)
		_check(animator.get_animation(animation_name).loop_mode == Animation.LOOP_LINEAR, "%s 没有循环" % animation_name)
	_check(animator.get_animation(&"jump-with-sword").loop_mode == Animation.LOOP_NONE, "持剑跳跃应播放一次")
	_q(true)
	await process_frame
	_check(Input.is_action_pressed("玩家切换持剑"), "Q 没有绑定持剑切换动作")
	_check(player.sword_equipped and model.sword_equipped and sword.visible and model.get_locomotion_animation() == "Idle-with-sword", "Q 没有立即进入持剑待机")
	_q(true, true)
	await process_frame
	_check(player.sword_equipped, "长按 Q 的重复事件反复切换装备")
	_q(false)
	await process_frame
	_check(player.sword_equipped, "松开 Q 触发了装备切换")
	model.animation_tree.advance(4.5)
	_check(model.animation_tree.active and model._motion_playback.is_playing(), "持剑待机播放一轮后停止")
	var animation_position := model.get_motion_play_position()
	model.set_sword_equipped(true)
	_check(is_equal_approx(animation_position, model.get_motion_play_position()), "相同装备状态重置了动画进度")
	Input.action_press("玩家前移")
	await _step(player, 30)
	_check(model.get_locomotion_animation() == "walk-with-sword" and is_equal_approx(player.velocity.length(), player.move_speed), "持剑行走的动画或速度错误")
	await _toggle_q()
	_check(model.get_locomotion_animation() == "walk" and not sword.visible, "行走时收剑未立即恢复空手动画")
	await _toggle_q()
	_check(model.get_locomotion_animation() == "walk-with-sword" and sword.visible, "行走时持剑未立即切换动画")
	Input.action_press("玩家奔跑")
	await _step(player, 30)
	_check(model.get_locomotion_animation() == "run-with-sword" and is_equal_approx(player.velocity.length(), player.run_speed), "持剑奔跑的动画或速度错误")
	await _toggle_q()
	_check(model.get_locomotion_animation() == "run" and not sword.visible, "奔跑时收剑失败")
	await _toggle_q()
	Input.action_press("玩家跳跃")
	await _step(player, 1)
	Input.action_release("玩家跳跃")
	_check(not player.is_on_floor() and model.get_locomotion_animation() == "jump-with-sword", "持剑起跳没有播放对应动画")
	await _toggle_q()
	_check(model.get_locomotion_animation() == "jump" and not sword.visible, "跳跃中收剑失败")
	await _toggle_q()
	_check(model.get_locomotion_animation() == "jump-with-sword" and sword.visible, "跳跃中持剑失败")
	await _step(player, 35)
	_check(player.velocity.y < 0.0 and model.get_locomotion_animation() == "falling-with-sword", "持剑下降没有播放对应动画")
	await _toggle_q()
	model.animation_tree.advance(0.3)
	_check(model.get_locomotion_animation() == "falling" and not sword.visible, "空手下落仍显示了剑")
	await _toggle_q()
	model.animation_tree.advance(0.6)
	_check(model.get_locomotion_animation() == "falling-with-sword" and model.animation_tree.active and model._motion_playback.is_playing() and sword.visible and sword.scale.length() > 0.1, "持剑下落没有循环或剑未显示")
	await _land(player)
	_check(model.get_locomotion_animation() == "run-with-sword", "落地没有恢复持剑奔跑")
	Input.action_release("玩家前移")
	Input.action_release("玩家奔跑")
	await _step(player, 40)
	_check(model.get_locomotion_animation() == "Idle-with-sword", "停下后没有恢复持剑待机")
	session.input_blocked = true
	await _toggle_q()
	_check(player.sword_equipped, "聊天或菜单阻塞输入时仍可收剑")
	session.input_blocked = false
	paused = true
	await _toggle_q()
	player.toggle_sword()
	_check(player.sword_equipped, "暂停时仍可收剑")
	paused = false
	player.toggle_free_camera()
	await _toggle_q()
	await _step(player, 2)
	_check(player.free_camera_enabled and not player.sword_equipped and model.get_locomotion_animation() == "Idle", "自由相机中收剑没有保持静止")
	await _toggle_q()
	await _step(player, 2)
	_check(player.sword_equipped and model.get_locomotion_animation() == "Idle-with-sword", "自由相机中持剑没有保持静止")
	player.toggle_free_camera()
	var remote = (load("res://scenes/player/玩家.tscn") as PackedScene).instantiate()
	remote.is_local = false
	world.add_child(remote)
	remote.set_physics_process(false)
	var remote_animator := remote.player_model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var remote_sword := remote.player_model.get_node(remote.player_model.sword_mesh_path) as GeometryInstance3D
	remote.apply_network_state({"position": Vector3.ZERO, "yaw": 0.0, "sword_equipped": true})
	await _step(remote, 1)
	_check(remote.sword_equipped and remote.player_model.get_locomotion_animation() == "Idle-with-sword" and remote_sword.visible, "远程持剑待机未同步")
	remote.toggle_sword()
	_check(remote.sword_equipped, "本地切换函数改变了远程角色装备")
	remote.apply_network_state({"position": Vector3(1, 0, 0), "yaw": 0.0, "sword_equipped": true})
	await _step(remote, 1)
	_check(remote.player_model.get_locomotion_animation() == "walk-with-sword", "远程持剑行走未同步")
	remote.apply_network_state({"position": Vector3(2, 0, 0), "yaw": 0.0, "is_running": true, "sword_equipped": true})
	await _step(remote, 1)
	_check(remote.player_model.get_locomotion_animation() == "run-with-sword", "远程持剑奔跑未同步")
	remote.apply_network_state({"position": Vector3.ZERO, "yaw": 0.0, "on_floor": false, "vertical_speed": 5.0, "sword_equipped": true})
	await _step(remote, 1)
	_check(remote.player_model.get_locomotion_animation() == "jump-with-sword", "远程持剑跳跃未同步")
	remote.apply_network_state({"position": Vector3.ZERO, "yaw": 0.0, "on_floor": false, "vertical_speed": -2.0, "sword_equipped": true})
	await _step(remote, 1)
	_check(remote.player_model.get_locomotion_animation() == "falling-with-sword", "远程持剑下落未同步")
	remote.apply_network_state({"position": Vector3.ZERO, "yaw": 0.0, "on_floor": false, "vertical_speed": -2.0, "sword_equipped": false})
	await _step(remote, 1)
	_check(remote.player_model.get_locomotion_animation() == "falling" and not remote_sword.visible, "远程空手下落仍显示了剑")
	remote.apply_network_state({"position": Vector3.ZERO, "yaw": 0.0, "sword_equipped": true})
	await _step(remote, 1)
	remote.apply_network_state({"position": remote.position, "yaw": 0.0})
	await _step(remote, 1)
	_check(not remote.sword_equipped and remote.player_model.get_locomotion_animation() == "Idle" and not remote_sword.visible, "旧网络状态缺少持剑字段时未兼容空手")
	print("玩家 Q 持剑验收：%s" % ("通过" if _failures == 0 else "%d 项失败" % _failures))
	world.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)

