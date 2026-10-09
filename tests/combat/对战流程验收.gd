## 对战流程功能验收。
## 使用实际输入、模型动画和地面碰撞验证点按、蓄力、伤害及史莱姆死亡；需要窗口模式保存截图。

extends Node3D
## 运行 tests/combat/对战流程验收.tscn；使用实际模型、输入、动画与碰撞。
var failures: Array[String] = []
var checks := 0
var player
var combat
var slime
var animator: AnimationPlayer
var gui

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		print("FAIL: " + message + " phase=%s anim=%s t=%s health=%s pos=%s enemy=%s" % [combat.phase, player.player_model.get_combat_node(), player.player_model.get_motion_play_position(), slime.health if is_instance_valid(slime) else -1, player.global_position, slime.global_position if is_instance_valid(slime) else Vector3.ZERO])

func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func reset_enemy(offset: Vector3) -> void:
	slime.global_position = player.global_position + offset
	slime.health = slime.max_health
	slime._update_health_bar()

func screenshot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/combat-validation/" + filename)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/combat-validation")
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.10, 0.17, 0.23)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -25, 0)
	light.shadow_enabled = true
	add_child(light)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(40, 1, 40)
	floor_body.position.y = -0.5
	floor_body.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = BoxMesh.new()
	floor_mesh.mesh.size = Vector3(40, 1, 40)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.34, 0.40, 0.37)
	floor_mesh.material_override = material
	floor_body.add_child(floor_mesh)
	add_child(floor_body)
	player = load("res://scenes/player/玩家.tscn").instantiate()
	player.mouse_sensitivity = 0.0
	player.position.y = 2.0
	add_child(player)
	combat = player.combat
	animator = player.player_model.find_children("*", "AnimationPlayer", true, false)[0]
	slime = load("res://scenes/enemies/史莱姆.tscn").instantiate()
	slime.max_health = 140
	add_child(slime)
	slime.set_physics_process(false)
	gui = load("res://scenes/ui/GUI.tscn").instantiate()
	add_child(gui)
	gui.bind_player_health(combat)
	await wait(0.65)
	check(player.is_on_floor(), "玩家落地")
	check(combat.health == 100 and gui.health_bar.value == 100, "玩家初始血量与GUI")
	check(InputMap.has_action("玩家攻击"), "左键输入已绑定")
	# 短宽判定：位于正前方左右约45度也应命中。
	reset_enemy(Vector3(1.5, -1.10, -1.5))
	click(true)
	await wait(0.05)
	click(false)
	await wait(0.08)
	check(combat.phase == combat.Phase.SWINGING and not combat.indicator.visible, "点按直接挥剑且不显示扇形")
	check(slime.health == 140, "挥剑前摇期间不扣血")
	await wait(0.30)
	check(slime.health == 120, "点按在落剑关键帧按基础伤害扣血")
	await wait(0.45)
	check(slime.health == 120 and combat.phase == combat.Phase.IDLE, "一次攻击只结算一次并恢复待机")
	# 静止AI但保留实际渲染/受击/闪烁更新。
	slime.move_speed = 0.0
	slime.attack_range = 0.0
	slime.set_physics_process(true)
	# 蓄力：侧面敌人退出选择，长范围内选中，镜头平滑拉近。
	reset_enemy(Vector3(0, -1.10, -4.0))
	click(true)
	await wait(0.36)
	check(combat.phase == combat.Phase.CHARGING and combat.indicator.visible, "长按进入准备蓄力")
	check(slime.selected, "长窄区域内选中史莱姆")
	check(player.camera_arm.spring_length < 4.0 and player.camera.fov < 75.0, "蓄力拉近镜头")
	check(player.player_model.get_combat_node() in [&"Charge", &"Hold"], "蓄力使用准备动画")
	# 蓄力期间使用真实移动输入，腿部应迈步且保持减速和上半身战斗。
	Input.action_press("玩家前移")
	await wait(0.25)
	var skeleton: Skeleton3D = player.player_model.find_children("*", "Skeleton3D", true, false)[0]
	var leg := skeleton.find_bone(&"骨骼.016")
	var leg_pose := skeleton.get_bone_pose(leg)
	await wait(0.25)
	check(not skeleton.get_bone_pose(leg).is_equal_approx(leg_pose), "真实蓄力移动时腿部继续迈步")
	check(player.player_model.motion_state == player.player_model.State.WALK and player.player_model.current_state == player.player_model.State.CHARGE, "蓄力与行走状态同时运行")
	check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.move_speed * 0.35), "蓄力移动保留减速规则")
	Input.action_release("玩家前移")
	await wait(0.2)
	var pale: Color = combat.indicator.material_override.albedo_color
	await screenshot("charge-light.png")
	slime.global_position = player.global_position + Vector3(3, -1.10, -2)
	await wait(0.08)
	check(not slime.selected, "离开窄扇形取消选择")
	reset_enemy(Vector3(0, -1.10, -4.0))
	await wait(1.7)
	check(is_equal_approx(combat.charge_ratio, 1.0), "蓄力达到上限")
	var dark: Color = combat.indicator.material_override.albedo_color
	check(dark.g < pale.g and dark.a > pale.a, "蓄力越强颜色越深")
	await screenshot("charge-full.png")
	click(false)
	await wait(0.12)
	check(slime.health == 140 and not slime.selected and not combat.indicator.visible, "释放蓄力后等待落剑并关闭提示")
	await wait(0.24)
	check(slime.health == 70 and slime._body_material.albedo_color.r > 0.95, "最大蓄力伤害70且受击变红")
	await screenshot("hit.png")
	await wait(0.50)
	check(absf(player.camera_arm.spring_length - 4.0) < 0.1, "攻击后镜头恢复")
	slime.set_physics_process(false)
	slime.move_speed = 2.4
	slime.attack_range = 1.65
	# 释放时在范围内，但落剑前离开，不应扣血。
	reset_enemy(Vector3(0, -1.10, -3.0))
	click(true)
	await wait(0.4)
	click(false)
	slime.global_position = player.global_position + Vector3(0, -1.10, 4.0)
	await wait(0.85)
	check(slime.health == 140, "按落剑时位置判定，离开范围会落空")
	# 菜单阻塞、自由相机和收剑均取消准备。
	click(true)
	await wait(0.3)
	get_node("/root/Session").input_blocked = true
	await wait(0.08)
	check(combat.phase == combat.Phase.IDLE and not combat.indicator.visible, "输入阻塞取消蓄力")
	click(false)
	get_node("/root/Session").input_blocked = false
	player.toggle_free_camera()
	click(true)
	await wait(0.3)
	check(combat.phase == combat.Phase.IDLE, "自由相机不攻击")
	click(false)
	player.toggle_free_camera()
	click(true)
	await wait(0.3)
	player.toggle_sword()
	click(false)
	check(combat.phase == combat.Phase.IDLE and not player.sword_equipped, "收剑取消蓄力")
	click(true)
	await wait(0.3)
	gui.game_menu.open_menu()
	check(combat.phase == combat.Phase.IDLE and not combat.indicator.visible, "暂停菜单立即取消蓄力")
	click(false)
	gui.game_menu.close_menu()
	await wait(0.1)
	check(combat.phase == combat.Phase.IDLE, "退出菜单不补发攻击")
	# 史莱姆追击、距离外扑空，以及生命归零不死亡。
	reset_enemy(Vector3(0, -1.10, -5.0))
	slime.target = player
	slime.set_physics_process(true)
	var old_distance: float = slime.global_position.distance_to(player.global_position)
	await wait(0.5)
	check(slime.global_position.distance_to(player.global_position) < old_distance, "史莱姆会追踪玩家")
	reset_enemy(Vector3(0, -1.10, -1.5))
	var old_health: int = combat.health
	await wait(0.65)
	check(combat.health < old_health and gui.health_bar.value == combat.health, "史莱姆攻击扣血并同步GUI")
	slime.set_physics_process(false)
	player.take_damage(10000)
	check(combat.health == 0 and gui.health_bar.value == 0 and is_instance_valid(player), "玩家零血不死亡且血条归零")
	reset_enemy(Vector3(0, -1.10, -2.0))
	click(true)
	await wait(0.05)
	click(false)
	await wait(0.85)
	check(slime.health == 120, "玩家零血仍可攻击")
	# 超时蓄力仍封顶；致死后不再选择或攻击，留尸再淡出。
	slime.health = 70
	click(true)
	await wait(2.3)
	click(false)
	await wait(0.4)
	check(slime.dead and slime.health == 0 and slime.collision_layer == 0, "满蓄力封顶并触发死亡，关闭碰撞")
	check(not slime.health_bar.visible and not slime.selected, "死亡关闭头顶血条及选择")
	slime.set_physics_process(true)
	await wait(0.65)
	check(is_instance_valid(slime) and slime.body.transparency == 0.0, "尸体停留后才开始淡出")
	await wait(1.0)
	check(is_instance_valid(slime) and slime.body.transparency > 0.0 and slime.body.transparency < 1.0, "尸体逐渐淡出")
	await screenshot("corpse-fading.png")
	await wait(1.0)
	check(not is_instance_valid(slime), "淡出结束移除史莱姆")
	var result := {"checks": checks, "failures": failures}
	var file := FileAccess.open("res://.godot/combat-validation/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print("对战流程验收：%d 项检查，%d 项失败" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
