extends CharacterBody3D

@export var move_speed: float = 6.0
@export var acceleration: float = 24.0
@export var jump_speed: float = 5.0
@export var mouse_sensitivity: float = 0.0025

var peer_id := 1
var is_local := true
var player_nickname := "玩家"
var _sync_elapsed := 0.0
var _remote_position := Vector3.ZERO
var _remote_yaw := 0.0
var _has_remote_state := false

@onready var camera_yaw: Marker3D = $"第三人称摄像机枢轴"
@onready var camera_pitch: Marker3D = $"第三人称摄像机枢轴/摄像机俯仰"
@onready var camera_arm: SpringArm3D = $"第三人称摄像机枢轴/摄像机俯仰/摄像机伸缩臂"
@onready var camera: Camera3D = $"第三人称摄像机枢轴/摄像机俯仰/摄像机伸缩臂/第三人称摄像机"
@onready var map_camera_pivot: Marker3D = $"顶视图摄像机枢轴"
@onready var map_indicator: Node3D = $"地图指示器"

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))


func _ready() -> void:
	# 伸缩臂从角色内部探测，必须忽略角色自身的碰撞体。
	camera_arm.add_excluded_object(get_rid())
	camera.current = is_local
	_update_map_heading()
	if is_local:
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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw.rotate_y(-event.relative.x * mouse_sensitivity)
		camera_pitch.rotation.x = clampf(
			camera_pitch.rotation.x - event.relative.y * mouse_sensitivity,
			deg_to_rad(-65.0),
			deg_to_rad(45.0)
		)
		_update_map_heading()


func _update_map_heading() -> void:
	var heading := camera_yaw.global_rotation.y
	map_camera_pivot.global_rotation = Vector3(-PI / 2.0, heading, 0.0)
	map_indicator.global_rotation = Vector3(0.0, heading, 0.0)


func _physics_process(delta: float) -> void:
	if not is_local:
		if _has_remote_state:
			global_position = global_position.lerp(_remote_position, minf(delta * 16.0, 1.0))
			camera_yaw.rotation.y = lerp_angle(camera_yaw.rotation.y, _remote_yaw, minf(delta * 16.0, 1.0))
			_update_map_heading()
		return
	if is_on_floor():
		if not Session.input_blocked and Input.is_action_just_pressed("玩家跳跃"):
			velocity.y = jump_speed
	else:
		velocity.y -= gravity * delta

	var input_direction := Vector2.ZERO
	if not Session.input_blocked:
		input_direction = Input.get_vector("玩家左移", "玩家右移", "玩家前移", "玩家后移")
	var move_direction := camera_yaw.global_basis * Vector3(input_direction.x, 0.0, input_direction.y)
	move_direction.y = 0.0
	move_direction = move_direction.normalized()

	velocity.x = move_toward(velocity.x, move_direction.x * move_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, move_direction.z * move_speed, acceleration * delta)
	move_and_slide()
	_sync_elapsed += delta
	if _sync_elapsed >= 0.05:
		_sync_elapsed = 0.0
		Session.publish_local_state({"position": global_position, "yaw": camera_yaw.rotation.y})


func apply_network_state(state: Dictionary) -> void:
	if is_local or not state.get("position") is Vector3 or not state.get("yaw") is float:
		return
	var target: Vector3 = state["position"]
	if not target.is_finite() or not is_finite(state["yaw"]):
		return
	_remote_position = target
	_remote_yaw = state["yaw"]
	if not _has_remote_state or global_position.distance_to(target) > 10.0:
		global_position = target
	_has_remote_state = true
