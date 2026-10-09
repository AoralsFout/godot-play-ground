## 驱动玩家移动、跳跃、持剑切换及第三人称和自由相机。
## 本地角色处理输入与物理运动，远程角色插值同步状态；向动画树和战斗组件提供运动信息。

extends CharacterBody3D

signal free_camera_changed(enabled: bool)

## 常规移动速度（米/秒）；提高后走动或追击更快，应为非负值。
@export var move_speed: float = 6.0
## 奔跑目标速度（米/秒）；按住奔跑键时生效，应不小于行走速度。
@export var run_speed: float = 12.0
## 水平速度变化率（米/秒²）；越大起步和停止越快，0 会使水平速度无法主动改变。
@export var acceleration: float = 24.0
## 起跳竖直速度（米/秒）；越大跳得越高，实际高度还受项目重力影响。
@export var jump_speed: float = 5.0
## 鼠标转向灵敏度（弧度/像素）；同时影响第三人称和自由相机，越大转向越快。
@export var mouse_sensitivity: float = 0.0025
## 自由相机基础飞行速度（米/秒）；影响前后、侧向及升降，不改变玩家位置。
@export var free_camera_speed: float = 100.0
## 自由相机按住 Shift 时的速度倍率；1 表示不加速，建议大于等于 1。
@export var free_camera_boost: float = 4.0

var free_camera_enabled := false
var free_camera: Camera3D

var peer_id := 1
var is_local := true
var is_running := false
var sword_equipped := false
var player_nickname := "玩家"
var _sync_elapsed := 0.0
var _remote_position := Vector3.ZERO
var _remote_yaw := 0.0
var _has_remote_state := false
var _remote_is_running := false
var _remote_on_floor := true
var _remote_vertical_speed := 0.0

@onready var camera_yaw: Marker3D = $"第三人称摄像机枢轴"
@onready var camera_pitch: Marker3D = $"第三人称摄像机枢轴/摄像机俯仰"
@onready var camera_arm: SpringArm3D = $"第三人称摄像机枢轴/摄像机俯仰/摄像机伸缩臂"
@onready var camera: Camera3D = $"第三人称摄像机枢轴/摄像机俯仰/摄像机伸缩臂/第三人称摄像机"
@onready var map_camera_pivot: Marker3D = $"顶视图摄像机枢轴"
@onready var map_indicator: Node3D = $"地图指示器"
@onready var combat = $战斗
@onready var player_model: PlayerAnimationStateMachine = $model

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))


func _ready() -> void:
	combat.initialize()
	# 伸缩臂从角色内部探测，必须忽略角色自身的碰撞体。
	camera_arm.add_excluded_object(get_rid())
	camera.current = is_local
	_update_map_heading()
	if is_local:
		free_camera = Camera3D.new()
		free_camera.name = "自由摄像机"
		add_child(free_camera)
		free_camera.top_level = true
		free_camera.cull_mask = camera.cull_mask
		free_camera.near = camera.near
		free_camera.far = camera.far
		free_camera.fov = camera.fov
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		collision_layer = 0
		collision_mask = 0
		var nameplate := Label3D.new()
		nameplate.text = player_nickname
		nameplate.position.y = 2.3
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.font = UIStyle.theme().default_font
		nameplate.font_size = 40
		nameplate.pixel_size = 0.008
		add_child(nameplate)


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or Session.input_blocked:
		return
	if event.is_action_pressed("玩家攻击"):
		combat.press_attack()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("玩家攻击"):
		combat.release_attack()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("玩家切换持剑"):
		toggle_sword()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if free_camera_enabled:
			free_camera.rotation.y -= event.relative.x * mouse_sensitivity
			free_camera.rotation.x = clampf(free_camera.rotation.x - event.relative.y * mouse_sensitivity,
				deg_to_rad(-89.0), deg_to_rad(89.0))
			return
		camera_yaw.rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch.rotation.x = clampf(
			camera_pitch.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-65.0),
			deg_to_rad(45.0)
		)
		_update_map_heading()


func toggle_sword() -> void:
	if not is_local or Session.input_blocked or get_tree().paused:
		return
	combat.cancel_attack()
	sword_equipped = not sword_equipped
	player_model.set_sword_equipped(sword_equipped)


func toggle_free_camera() -> void:
	if not is_local or Session.input_blocked or get_tree().paused:
		return
	combat.cancel_attack()
	free_camera_enabled = not free_camera_enabled
	if free_camera_enabled:
		# 每次进入从当前第三人称视角出发，角色与原摄像机朝向保留。
		free_camera.global_transform = camera.global_transform
		free_camera.make_current()
		velocity = Vector3.ZERO
		is_running = false
		player_model.update_motion(Vector3.ZERO)
	else:
		camera.make_current()
	free_camera_changed.emit(free_camera_enabled)


func _process(delta: float) -> void:
	if not free_camera_enabled or Session.input_blocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var input_direction := Input.get_vector("玩家左移", "玩家右移", "玩家前移", "玩家后移")
	var direction := free_camera.global_basis * Vector3(input_direction.x, 0.0, input_direction.y)
	direction.y += float(Input.is_action_pressed("玩家跳跃")) - float(Input.is_physical_key_pressed(KEY_CTRL))
	var speed := free_camera_speed * (free_camera_boost if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0)
	free_camera.global_position += direction.limit_length() * speed * delta

func _update_map_heading() -> void:
	var heading := camera_yaw.global_rotation.y
	map_camera_pivot.global_rotation = Vector3(-PI / 2.0, heading, 0.0)
	map_indicator.global_rotation = Vector3(0.0, heading, 0.0)


func _physics_process(delta: float) -> void:
	if not is_local:
		var previous_position := global_position
		if _has_remote_state:
			global_position = global_position.lerp(_remote_position, minf(delta * 16.0, 1.0))
			camera_yaw.rotation.y = lerp_angle(camera_yaw.rotation.y, _remote_yaw, minf(delta * 16.0, 1.0))
			_update_map_heading()
		is_running = _remote_is_running
		var remote_motion := (global_position - previous_position) / maxf(delta, 0.000001)
		# 远程角色没有地面碰撞，使用同步的接地状态和竖直速度判断空中阶段。
		remote_motion.y = _remote_vertical_speed
		player_model.update_motion(remote_motion, delta, is_running, _remote_on_floor)
		return
	if free_camera_enabled:
		is_running = false
		player_model.update_motion(Vector3.ZERO)
		_sync_local_state(delta)
		return
	if is_on_floor():
		if not Session.input_blocked and combat.phase == combat.Phase.IDLE and Input.is_action_just_pressed("玩家跳跃"):
			velocity.y = jump_speed
	else:
		velocity.y -= gravity * delta

	var input_direction := Vector2.ZERO
	if not Session.input_blocked:
		input_direction = Input.get_vector("玩家左移", "玩家右移", "玩家前移", "玩家后移")
	var move_direction := camera_yaw.global_basis * Vector3(input_direction.x, 0.0, input_direction.y)
	move_direction.y = 0.0
	move_direction = move_direction.normalized()

	is_running = not Session.input_blocked and not input_direction.is_zero_approx() and combat.movement_multiplier() == 1.0 and Input.is_action_pressed("玩家奔跑")
	var speed: float = (run_speed if is_running else move_speed) * combat.movement_multiplier()
	velocity.x = move_toward(velocity.x, move_direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * speed, acceleration * delta)
	move_and_slide()
	var motion_velocity := get_real_velocity()
	motion_velocity.y = velocity.y
	player_model.update_motion(motion_velocity, delta, is_running, is_on_floor())
	_sync_local_state(delta)


func _sync_local_state(delta: float) -> void:
	_sync_elapsed += delta
	if _sync_elapsed >= 0.05:
		_sync_elapsed = 0.0
		Session.publish_local_state({
			"position": global_position,
			"yaw": camera_yaw.rotation.y,
			"is_running": is_running,
			"sword_equipped": sword_equipped,
			# 自由相机冻结角色，远程模型也应保持静止动画。
			"on_floor": is_on_floor() or free_camera_enabled,
			"vertical_speed": velocity.y,
		})


func apply_network_state(state: Dictionary) -> void:
	if is_local or not state.get("position") is Vector3 or not state.get("yaw") is float:
		return
	var target: Vector3 = state["position"]
	if not target.is_finite() or not is_finite(state["yaw"]):
		return
	_remote_position = target
	_remote_yaw = state["yaw"]
	_remote_is_running = state.get("is_running", false) == true
	sword_equipped = state.get("sword_equipped", false) == true
	player_model.set_sword_equipped(sword_equipped)
	_remote_on_floor = state.get("on_floor", true) == true
	var vertical_speed = state.get("vertical_speed", 0.0)
	_remote_vertical_speed = 0.0
	if (vertical_speed is float or vertical_speed is int) and is_finite(float(vertical_speed)):
		_remote_vertical_speed = float(vertical_speed)
	if not _has_remote_state or global_position.distance_to(target) > 10.0:
		global_position = target
	_has_remote_state = true


func take_damage(amount: int) -> void:
	combat.take_damage(amount)
