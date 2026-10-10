## 加载实际玩家模型，验收四向行走跟随相机朝向、斜向骨骼混合和步态相位。
## 同时检查方向键不触发转身、持剑切换、奔跑转向及远程模型朝向。

extends SceneTree

const LEG_BONES: Array[StringName] = [&"骨骼.012", &"骨骼.014", &"骨骼.016", &"骨骼.018", &"骨骼.020",
	&"骨骼.013", &"骨骼.015", &"骨骼.017", &"骨骼.019", &"骨骼.021"]
const ACTIONS := ["玩家左移", "玩家右移", "玩家前移", "玩家后移"]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func step(player: CharacterBody3D, count: int) -> void:
	for frame in count:
		await physics_frame
		player._physics_process(1.0 / 60.0)


func release_movement() -> void:
	for action in ACTIONS:
		Input.action_release(action)


func sample_legs(model: PlayerAnimationStateMachine, name: StringName, phase: float) -> Array[Transform3D]:
	var animation := model._animation_player.get_animation(name)
	model._animation_player.play(name)
	model._animation_player.seek(animation.length * phase, true)
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var result: Array[Transform3D] = []
	for bone in LEG_BONES:
		result.append(skeleton.get_bone_pose(skeleton.find_bone(bone)))
	return result


func check_pose(model: PlayerAnimationStateMachine, expected: Array[Transform3D], message: String) -> void:
	var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var matching := true
	for i in LEG_BONES.size():
		var actual := skeleton.get_bone_pose(skeleton.find_bone(LEG_BONES[i]))
		# 动画混合器以旋转累加方式混合，与 Transform3D 插值允许约 1 度差异。
		matching = matching and actual.origin.distance_to(expected[i].origin) < 0.0001
		matching = matching and actual.basis.get_scale().distance_to(expected[i].basis.get_scale()) < 0.0001
		matching = matching and actual.basis.get_rotation_quaternion().angle_to(expected[i].basis.get_rotation_quaternion()) < 0.02
	check(matching, message)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(200, 1, 200)
	floor_body.add_child(collision)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var scene := load("res://scenes/player/玩家.tscn") as PackedScene
	var player = scene.instantiate()
	player.position.y = 2.0
	world.add_child(player)
	player.set_physics_process(false)
	await step(player, 60)
	var model: PlayerAnimationStateMachine = player.player_model
	var directions: Array[Vector2] = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0),
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for equipped in [false, true]:
		player.sword_equipped = equipped
		model.set_sword_equipped(equipped)
		for heading in [0.0, PI / 2.0]:
			model.global_rotation.y = heading
			player.camera_yaw.global_rotation.y = heading
			for direction in directions:
				release_movement()
				if direction.x != 0:
					Input.action_press("玩家右移" if direction.x > 0 else "玩家左移")
				if direction.y != 0:
					Input.action_press("玩家后移" if direction.y > 0 else "玩家前移")
				await step(player, 40)
				check(model.motion_state == model.State.WALK, "输入 %s 进入行走" % direction)
				check(is_equal_approx(wrapf(model.global_rotation.y - heading, -PI, PI), 0.0), "行走不改变模型朝向")
				check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.move_speed), "各方向保持行走速度")
				for node in ["Unarmed", "Sword"]:
					var blend: Vector2 = model.animation_tree.get("parameters/Locomotion/Walk/%s/blend_position" % node)
					check(blend.is_equal_approx(direction.normalized()), "空手与持剑按模型朝向混合 %s" % direction)
	release_movement()
	await step(player, 40)
	model.global_rotation.y = 0.0
	player.camera_yaw.global_rotation.y = PI / 2.0
	Input.action_press("玩家前移")
	await step(player, 40)
	check(is_equal_approx(model.global_rotation.y, PI / 2.0), "转动相机后行走朝向立即跟随相机")
	check((model.animation_tree.get("parameters/Locomotion/Walk/Unarmed/blend_position") as Vector2).is_equal_approx(Vector2.UP), "相机向前输入继续使用前进动作")
	Input.action_release("玩家前移")
	Input.action_press("玩家右移")
	Input.action_press("玩家奔跑")
	await step(player, 50)
	check(model.motion_state == model.State.RUN and absf(wrapf(model.global_rotation.y, -PI, PI)) < 0.001, "奔跑保留原有朝移动方向转身，不锁定相机")
	Input.action_release("玩家奔跑")
	release_movement()
	Input.action_press("玩家后移")
	await step(player, 40)
	check(is_equal_approx(model.global_rotation.y, PI / 2.0), "奔跑结束后行走恢复相机朝向")
	check((model.animation_tree.get("parameters/Locomotion/Walk/Unarmed/blend_position") as Vector2).is_equal_approx(Vector2.DOWN), "后退键播放后退动作而不转身")
	release_movement()
	await step(player, 40)
	check(model.motion_state == model.State.IDLE, "停止移动恢复待机")
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(240, 0)
	player._unhandled_input(mouse)
	await step(player, 1)
	check(is_equal_approx(model.global_rotation.y, player.camera_yaw.global_rotation.y), "待机时鼠标转动相机，模型仍跟随水平朝向")
	player.camera_pitch.rotation.x = -0.9
	Input.action_press("玩家前移")
	model.forward_yaw_offset_degrees = 90.0
	await step(player, 40)
	check(absf(wrapf(model.global_rotation.y - player.camera_yaw.global_rotation.y + PI / 2.0, -PI, PI)) < 0.001, "相机俯仰不改变水平朝向，并保留模型正前方校正")
	check((model.animation_tree.get("parameters/Locomotion/Walk/Unarmed/blend_position") as Vector2).is_equal_approx(Vector2.UP), "模型朝向校正后四向混合仍正确")
	model.forward_yaw_offset_degrees = 180.0
	release_movement()
	await step(player, 40)
	Input.action_press("玩家后移")
	Input.action_press("玩家跳跃")
	await step(player, 1)
	Input.action_release("玩家跳跃")
	await step(player, 10)
	check(not player.is_on_floor() and is_equal_approx(model.global_rotation.y, player.camera_yaw.global_rotation.y), "非奔跑的空中移动也保持相机朝向")
	release_movement()
	await step(player, 90)

	# 直接比较实际骨骼，避免仅检查混合参数却没有真正播放或混合动作。
	var reference = scene.instantiate()
	reference.is_local = false
	world.add_child(reference)
	reference.set_physics_process(false)
	var reference_model: PlayerAnimationStateMachine = reference.player_model
	reference_model.set_physics_process(false)
	reference_model.animation_tree.active = false
	reference_model._animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	model.set_physics_process(false)
	model.animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	model.global_rotation.y = 0.0
	var cycle := model._animation_player.get_animation(&"walk").length
	var phase := 0.37
	for equipped in [false, true]:
		model.set_sword_equipped(equipped)
		model._physics_process(1.0)
		var suffix := "-with-sword" if equipped else ""
		var names: Array[StringName] = [StringName("walk" + suffix), StringName("walk-back" + suffix),
			StringName("walk-left" + suffix), StringName("walk-right" + suffix)]
		for i in 4:
			check(model._animation_player.get_animation(names[i]).loop_mode == Animation.LOOP_LINEAR, "%s 循环播放" % names[i])
			model.update_motion(Vector3(directions[i].x, 0.0, directions[i].y) * player.move_speed)
			model._motion_playback.start(&"Walk", true)
			model.animation_tree.advance(0.0)
			model.animation_tree.advance(cycle * phase)
			check_pose(model, sample_legs(reference_model, names[i], phase), "%s 实际腿部动作与源动画同相位" % names[i])
			model.animation_tree.advance(cycle * 2.0)
			check_pose(model, sample_legs(reference_model, names[i], phase), "%s 多周期后仍循环且相位一致" % names[i])
		for pair in [[0, 2], [0, 3], [1, 2], [1, 3]]:
			var direction := (directions[pair[0]] + directions[pair[1]]).normalized()
			model.update_motion(Vector3(direction.x, 0.0, direction.y) * player.move_speed)
			model._motion_playback.start(&"Walk", true)
			model.animation_tree.advance(0.0)
			model.animation_tree.advance(cycle * phase)
			var first := sample_legs(reference_model, names[pair[0]], phase)
			var second := sample_legs(reference_model, names[pair[1]], phase)
			var mixed: Array[Transform3D] = []
			for i in first.size():
				mixed.append(first[i].interpolate_with(second[i], 0.5))
			check_pose(model, mixed, "斜向 %s 的实际腿骨混合相邻两方向" % direction)
			var skeleton := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var differs_from_both := false
			for i in LEG_BONES.size():
				var actual := skeleton.get_bone_pose(skeleton.find_bone(LEG_BONES[i]))
				differs_from_both = differs_from_both or (not actual.is_equal_approx(first[i]) and not actual.is_equal_approx(second[i]))
			check(differs_from_both, "斜向混合产生区别于任一单方向的姿态")
	model.set_sword_equipped(false)
	model._physics_process(1.0)
	model.update_motion(Vector3(0, 0, -player.move_speed))
	model._motion_playback.start(&"Walk", true)
	model.animation_tree.advance(0.0)
	model.animation_tree.advance(cycle * phase)
	model.set_sword_equipped(true)
	model._physics_process(1.0)
	model.animation_tree.advance(0.0)
	check_pose(model, sample_legs(reference_model, &"walk-with-sword", phase), "行走中切换装备保留步态相位")
	model.update_motion(Vector3(0, 0, player.move_speed))
	model.animation_tree.advance(0.0)
	check_pose(model, sample_legs(reference_model, &"walk-back-with-sword", phase), "行走中切换方向保留步态相位")

	var remote = scene.instantiate()
	remote.is_local = false
	world.add_child(remote)
	remote.set_physics_process(false)
	remote.apply_network_state({"position": Vector3(20, 0, 0), "yaw": 0.0, "model_yaw": PI / 2.0})
	remote.apply_network_state({"position": Vector3(21, 0, 0), "yaw": 0.0, "model_yaw": PI / 2.0})
	await step(remote, 1)
	check(is_equal_approx(remote.player_model.global_rotation.y, PI / 2.0), "远程行走还原独立于相机的模型朝向")
	check((remote.player_model.animation_tree.get("parameters/Locomotion/Walk/Unarmed/blend_position") as Vector2).is_equal_approx(Vector2.DOWN), "远程移动按同步模型朝向选择后退动作")
	remote.apply_network_state({"position": Vector3(21, 0, 1), "yaw": 0.0, "model_yaw": NAN})
	await step(remote, 1)
	check(is_finite(remote.player_model.global_rotation.y), "忽略非法远程模型朝向")
	remote.apply_network_state({"position": Vector3(21, 0, 2), "yaw": 0.0})
	await step(remote, 1)
	check(remote.player_model.motion_state == model.State.WALK, "旧网络消息缺少模型朝向仍正常行走")
	DirAccess.make_dir_recursive_absolute("res://.godot/walk-validation")
	var report := FileAccess.open("res://.godot/walk-validation/report.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	print("玩家四向行走验收：%s（%d 项检查）" % ["通过" if failures.is_empty() else "%d 项失败" % failures.size(), checks])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
