## 动画树分层功能验收。
## 加载实际玩家和史莱姆，检查腿部动作、装备混合、实例隔离及战斗事件；窗口模式额外保存截图。

extends Node3D
## 两个实际玩家模型按相同时间推进，验证战斗过滤不会冻结或污染腿部。
var failures: Array[String] = []
var checks := 0
var impact_count := 0
var finish_count := 0
var player
var reference
var model: PlayerAnimationStateMachine
var reference_model: PlayerAnimationStateMachine
var skeleton: Skeleton3D
var reference_skeleton: Skeleton3D

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func step(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.00001:
		var delta := minf(remaining, 1.0 / 60.0)
		model._physics_process(delta)
		reference_model._physics_process(delta)
		model.animation_tree.advance(delta)
		reference_model.animation_tree.advance(delta)
		remaining -= delta
		await get_tree().process_frame

func create_player(offset: Vector3):
	var instance = load("res://scenes/player/玩家.tscn").instantiate()
	instance.is_local = false
	instance.player_nickname = "蓄力 + 奔跑" if offset.x < 0.0 else "普通持剑奔跑"
	instance.position = offset
	add_child(instance)
	instance.set_physics_process(false)
	instance.combat.set_physics_process(false)
	instance.player_model.set_physics_process(false)
	instance.player_model.animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	instance.player_model.set_sword_equipped(true)
	return instance

func pose(bone: StringName) -> Transform3D:
	return skeleton.get_bone_pose(skeleton.find_bone(bone))

func check_legs(message: String) -> void:
	var matching := true
	for name: StringName in [&"骨骼.012", &"骨骼.014", &"骨骼.016", &"骨骼.018", &"骨骼.020", &"骨骼.013", &"骨骼.015", &"骨骼.017", &"骨骼.019", &"骨骼.021"]:
		matching = matching and pose(name).is_equal_approx(reference_skeleton.get_bone_pose(reference_skeleton.find_bone(name)))
	check(matching, message)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/tree-validation")
	player = create_player(Vector3(-1.4, 1.1, 0))
	reference = create_player(Vector3(1.4, 1.1, 0))
	model = player.player_model
	reference_model = reference.player_model
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	reference_skeleton = reference_model.find_children("*", "Skeleton3D", true, false)[0]
	model.attack_impact.connect(func(): impact_count += 1)
	model.attack_finished.connect(func(): finish_count += 1)
	check(model.animation_tree.active and not model._animation_player.is_playing(), "玩家由 AnimationTree 播放")
	check(model.animation_tree.tree_root != reference_model.animation_tree.tree_root, "玩家动画树资源实例隔离")
	var graph := model.animation_tree.tree_root as AnimationNodeBlendTree
	var overlay := graph.get_node(&"UpperBody") as AnimationNodeBlend2
	check(overlay.is_path_filtered(^"骨架/Skeleton3D:骨骼.023") and not overlay.is_path_filtered(^"骨架/Skeleton3D:骨骼.016"), "过滤包含手臂并排除双腿")
	model.update_motion(Vector3(0, 0, -2.1))
	reference_model.update_motion(Vector3(0, 0, -2.1))
	await step(0.25)
	check(is_equal_approx(model.animation_tree.get("parameters/Locomotion/Walk/Speed/scale"), 0.35), "蓄力减速时步频按实际速度缩放")
	model.begin_charge()
	await step(0.2)
	check_legs("准备动作期间双腿保持移动基础层")
	await step(0.4)
	check(model.get_combat_node() == &"Hold", "准备动作结束自动进入蓄力保持")
	var leg_before := pose(&"骨骼.016")
	var arm_before := pose(&"骨骼.010")
	await step(0.25)
	check(not pose(&"骨骼.016").is_equal_approx(leg_before), "蓄力保持时腿部持续迈步")
	check(pose(&"骨骼.010").is_equal_approx(arm_before), "腿部迈步时上半身保持蓄力姿势")
	check_legs("长按蓄力不污染腿部姿态")
	check(not pose(&"骨骼.010").is_equal_approx(reference_skeleton.get_bone_pose(reference_skeleton.find_bone(&"骨骼.010"))), "蓄力上半身区别于持剑行走")
	# 两实例同时运行相同下半身，但参考实例没有进入战斗。
	check(not reference_model.combat_active, "蓄力不会影响另一玩家实例")
	model.update_motion(Vector3(0, 0, -12), 0.0, true)
	reference_model.update_motion(Vector3(0, 0, -12), 0.0, true)
	await step(0.25)
	check(model.motion_state == model.State.RUN and model.current_state == model.State.CHARGE, "战斗与奔跑状态独立")
	check_legs("奔跑可以与上半身蓄力同时播放")
	model.play_attack()
	await step(0.15)
	check(impact_count == 0, "挥砍前摇不提前命中")
	check_legs("挥砍时双腿继续奔跑")
	await step(0.20)
	check(impact_count == 1, "落剑方法轨道结算一次")
	await step(0.20)
	check(finish_count == 1 and not model.combat_active and model.current_state == model.State.RUN, "挥砍结束恢复当前移动状态")
	await step(0.25)
	check(impact_count == 1 and finish_count == 1, "攻击结束后不会重复触发事件")
	model.play_attack()
	await step(0.1)
	model.cancel_combat()
	await step(0.5)
	check(impact_count == 1 and finish_count == 1, "取消挥砍不结算伤害或完成事件")
	model.play_attack()
	await step(0.35)
	await step(0.20)
	check(impact_count == 2 and finish_count == 2, "取消后新攻击能重新播放并只结算一次")
	model.update_motion(Vector3(0, 5, 0), 0.0, false, false)
	reference_model.update_motion(Vector3(0, 5, 0), 0.0, false, false)
	model.begin_charge()
	await step(0.15)
	check(model.motion_state == model.State.JUMP, "上半身战斗保留跳跃基础层")
	model.update_motion(Vector3(0, -2, 0), 0.0, false, false)
	reference_model.update_motion(Vector3(0, -2, 0), 0.0, false, false)
	await step(0.25)
	check(model.motion_state == model.State.FALLING, "上半身战斗保留下落基础层")
	check_legs("空中战斗不覆盖下落腿部")
	model.cancel_combat()
	model.set_sword_equipped(false)
	await step(0.1)
	check(not model._sword_mesh.visible and reference_model._sword_mesh.visible, "武器显隐由装备控制且实例隔离")
	check(model._sword_mesh.scale.is_equal_approx(reference_model._sword_mesh.scale), "装备切换不改变武器基础缩放")
	var slime = load("res://scenes/enemies/史莱姆.tscn").instantiate()
	slime.position = Vector3(0, 0, 4)
	add_child(slime)
	slime.set_physics_process(false)
	slime.animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	slime.animation_tree.advance(0.1)
	check(slime.animation_tree.active and not slime._animator.is_playing(), "史莱姆由 AnimationTree 播放")
	slime._play_animation(&"attack", 0.5)
	slime.animation_tree.advance(0.1)
	check(slime._animation_playback.get_current_node() == &"attack" and is_equal_approx(slime.animation_tree.get("parameters/Speed/scale"), 0.5), "史莱姆攻击状态与速度参数生效")
	slime.take_damage(slime.max_health)
	slime.animation_tree.advance(0.1)
	check(slime._animation_playback.get_current_node() == &"died" and slime.dead, "史莱姆死亡进入终止状态")
	slime.queue_free()
	# 最终画面对比普通持剑奔跑与上半身蓄力、下半身奔跑。
	model.set_sword_equipped(true)
	model.update_motion(Vector3(0, 0, -12), 0.0, true)
	reference_model.update_motion(Vector3(0, 0, -12), 0.0, true)
	model.begin_charge()
	await step(0.6)
	if DisplayServer.get_name() != "headless":
		await capture()
	var result := {"checks": checks, "failures": failures}
	FileAccess.open("res://.godot/tree-validation/layers.json", FileAccess.WRITE).store_string(JSON.stringify(result, "  "))
	print("AnimationTree 分层验收：%d 项检查，%d 项失败" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func capture() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.17, 0.22)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -25, 0)
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 2.8, -6)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.2
	camera.look_at(Vector3(0, 1.2, 0))
	camera.current = true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/tree-validation/charge-running.png")
