extends SceneTree
## 使用实际模型和地面碰撞验证空中动画、落地恢复及远程同步。

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


func _jump(player: CharacterBody3D) -> void:
	await physics_frame
	Input.action_press("玩家跳跃")
	await _step(player, 1)
	Input.action_release("玩家跳跃")


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
	floor_shape.size = Vector3(8, 1, 100)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player = (load("res://scenes/player/玩家.tscn") as PackedScene).instantiate()
	player.position.y = 2.0
	world.add_child(player)
	player.set_physics_process(false)
	await _land(player)
	var animation_player := player.player_model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_check(animation_player.has_animation(&"jump") and animation_player.has_animation(&"falling"), "模型缺少 jump 或 falling")
	_check(animation_player.get_animation(&"jump").loop_mode == Animation.LOOP_NONE, "jump 动画应只播放一次")
	_check(animation_player.get_animation(&"falling").loop_mode == Animation.LOOP_LINEAR, "falling 动画应循环播放")
	await _jump(player)
	_check(not player.is_on_floor() and player.velocity.y > 0.0 and animation_player.current_animation == "jump", "原地起跳没有播放 jump")
	await _step(player, 35)
	_check(not player.is_on_floor() and player.velocity.y < 0.0 and animation_player.current_animation == "falling", "跳跃下降阶段没有播放 falling")
	await _land(player)
	_check(animation_player.current_animation == "Idle", "原地跳跃落地后没有恢复 Idle")
	Input.action_press("玩家前移")
	await _step(player, 30)
	await _jump(player)
	_check(animation_player.current_animation == "jump", "行走起跳没有优先播放 jump")
	await _land(player)
	_check(animation_player.current_animation == "walk", "行走跳跃落地后没有恢复 walk")
	Input.action_press("玩家奔跑")
	await _step(player, 30)
	await _jump(player)
	_check(player.is_running and animation_player.current_animation == "jump", "奔跑起跳没有优先播放 jump")
	await _step(player, 35)
	_check(animation_player.current_animation == "falling", "奔跑下降时没有播放 falling")
	await _land(player)
	_check(animation_player.current_animation == "run", "奔跑跳跃落地后没有恢复 run")
	Input.action_release("玩家奔跑")
	Input.action_release("玩家前移")
	await _step(player, 30)
	session.input_blocked = true
	await _jump(player)
	_check(player.is_on_floor() and animation_player.current_animation == "Idle", "输入阻塞时仍然起跳")
	session.input_blocked = false
	Input.action_press("玩家右移")
	await _step(player, 70)
	Input.action_release("玩家右移")
	_check(not player.is_on_floor() and animation_player.current_animation == "falling", "走出平台没有播放 falling")
	player.toggle_free_camera()
	await _step(player, 2)
	_check(animation_player.current_animation == "Idle", "自由相机中仍在播放空中动画")
	player.toggle_free_camera()
	await _step(player, 2)
	_check(animation_player.current_animation == "falling", "退出自由相机后没有恢复下落动画")
	var remote = (load("res://scenes/player/玩家.tscn") as PackedScene).instantiate()
	remote.is_local = false
	world.add_child(remote)
	remote.set_physics_process(false)
	var remote_animation := remote.player_model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	remote.apply_network_state({"position": Vector3.ZERO, "yaw": 0.0, "is_running": true, "on_floor": false, "vertical_speed": 5.0})
	await _step(remote, 1)
	_check(remote_animation.current_animation == "jump", "远程角色没有同步 jump")
	remote.apply_network_state({"position": Vector3.ZERO, "yaw": 0.0, "on_floor": false, "vertical_speed": -2.0})
	await _step(remote, 1)
	_check(remote_animation.current_animation == "falling", "远程角色没有同步 falling")
	remote.apply_network_state({"position": Vector3.ZERO, "yaw": 0.0, "on_floor": false, "vertical_speed": 0.0})
	await _step(remote, 1)
	_check(remote_animation.current_animation == "falling", "空中最高点没有使用 falling")
	remote.apply_network_state({"position": Vector3.ZERO, "yaw": 0.0, "on_floor": true, "vertical_speed": 0.0})
	await _step(remote, 1)
	_check(remote_animation.current_animation == "Idle", "远程角色落地后没有恢复 Idle")
	remote.apply_network_state({"position": Vector3.ZERO, "yaw": 0.0})
	await _step(remote, 1)
	_check(remote_animation.current_animation == "Idle", "旧网络状态没有兼容地面动画")
	print("玩家跳跃与下落验收：%s" % ("通过" if _failures == 0 else "%d 项失败" % _failures))
	world.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)
