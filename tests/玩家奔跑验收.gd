extends SceneTree
## 使用实际玩家场景验证 Shift、速度、动画与远程状态。

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


func _shift(pressed: bool, location: int = KEY_LOCATION_LEFT) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_SHIFT
	event.keycode = KEY_SHIFT
	event.location = location
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


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
	await _step(player, 60)
	var model: PlayerAnimationStateMachine = player.player_model
	var animation_player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_check(player.is_on_floor(), "测试玩家没有落地")
	_check(animation_player.has_animation(&"run"), "实际导入模型没有 run 动画")
	_check(animation_player.get_animation(&"run").loop_mode == Animation.LOOP_LINEAR, "run 动画没有循环")
	_shift(true)
	_check(Input.is_action_pressed("玩家奔跑"), "左 Shift 没有绑定奔跑动作")
	await _step(player, 2)
	_check(not player.is_running and model.current_state == PlayerAnimationStateMachine.State.IDLE, "原地按 Shift 进入了奔跑")
	_shift(false)
	_shift(true, KEY_LOCATION_RIGHT)
	_check(Input.is_action_pressed("玩家奔跑"), "右 Shift 没有绑定奔跑动作")
	_shift(false, KEY_LOCATION_RIGHT)
	Input.action_press("玩家前移")
	await _step(player, 30)
	_check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.move_speed), "行走速度错误")
	_check(model.current_state == PlayerAnimationStateMachine.State.WALK and model.get_locomotion_animation() == "walk", "移动时没有播放 walk")
	_shift(true)
	await _step(player, 30)
	_check(player.is_running and is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.run_speed), "Shift 没有达到奔跑速度")
	_check(model.current_state == PlayerAnimationStateMachine.State.RUN and model.get_locomotion_animation() == "run", "奔跑时没有播放 run")
	_shift(false)
	await _step(player, 30)
	_check(not player.is_running and is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.move_speed), "松开 Shift 后没有恢复行走速度")
	_check(model.get_locomotion_animation() == "walk", "松开 Shift 后没有恢复 walk")
	_shift(true)
	Input.action_press("玩家右移")
	await _step(player, 30)
	_check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.run_speed), "斜向奔跑速度错误")
	session.input_blocked = true
	await _step(player, 45)
	_check(not player.is_running and Vector2(player.velocity.x, player.velocity.z).is_zero_approx(), "输入阻塞时仍然奔跑")
	_check(model.get_locomotion_animation() == "Idle", "输入阻塞停下后没有恢复 Idle")
	session.input_blocked = false
	await _step(player, 45)
	player.toggle_free_camera()
	await _step(player, 2)
	_check(not player.is_running and model.get_locomotion_animation() == "Idle", "进入自由相机后玩家仍在奔跑")
	player.toggle_free_camera()
	Input.action_release("玩家前移")
	Input.action_release("玩家右移")
	await _step(player, 45)
	_check(not player.is_running and model.get_locomotion_animation() == "Idle", "按住 Shift 停止移动后没有回到 Idle")
	_shift(false)
	var remote = (load("res://scenes/player/玩家.tscn") as PackedScene).instantiate()
	remote.is_local = false
	remote.position = Vector3(20, 2, 0)
	world.add_child(remote)
	remote.set_physics_process(false)
	remote.apply_network_state({"position": remote.position, "yaw": 0.0, "is_running": true})
	remote.apply_network_state({"position": remote.position + Vector3(1, 0, 0), "yaw": 0.0, "is_running": true})
	await _step(remote, 1)
	_check(remote.player_model.current_state == PlayerAnimationStateMachine.State.RUN, "远程角色没有同步 run")
	remote.apply_network_state({"position": remote.position + Vector3(1, 0, 0), "yaw": 0.0, "is_running": false})
	await _step(remote, 1)
	_check(remote.player_model.current_state == PlayerAnimationStateMachine.State.WALK, "远程角色没有恢复 walk")
	remote.apply_network_state({"position": remote.position + Vector3(1, 0, 0), "yaw": 0.0})
	await _step(remote, 1)
	_check(not remote.is_running, "旧网络状态缺少奔跑字段时没有默认行走")
	print("玩家 Shift 奔跑验收：%s" % ("通过" if _failures == 0 else "%d 项失败" % _failures))
	world.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)
