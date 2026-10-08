class_name PlayerAnimationStateMachine
extends Node3D

signal state_changed(previous_state: State, current_state: State)
signal attack_impact
signal attack_finished

enum State { IDLE, WALK, RUN, JUMP, FALLING, CHARGE, ATTACK }

@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"walk"
@export var run_animation: StringName = &"run"
@export var jump_animation: StringName = &"jump"
@export var falling_animation: StringName = &"falling"
@export_group("持剑动画")
@export var sword_idle_animation: StringName = &"Idle-with-sword"
@export var sword_walk_animation: StringName = &"walk-with-sword"
@export var sword_run_animation: StringName = &"run-with-sword"
@export var sword_jump_animation: StringName = &"jump-with-sword"
@export var sword_falling_animation: StringName = &"falling-with-sword"
@export_node_path("GeometryInstance3D") var sword_mesh_path: NodePath = ^"骨架/Skeleton3D/骨骼_023/立方体_001"
@export_group("战斗动画")
@export var charge_animation: StringName = &"attack-ready"
@export var attack_animation: StringName = &"attack-1"
@export_range(0.01, 0.7, 0.01) var attack_impact_seconds: float = 0.30
@export_group("动画切换")
@export_range(0.0, 1.0, 0.01) var blend_time: float = 0.2
@export var walk_start_speed: float = 0.1
@export var walk_stop_speed: float = 0.05
@export_range(0.0, 30.0, 0.1) var turn_speed: float = 12.0
# 默认模型正面为 +Z；若模型正面为 -Z，将偏移设为 180 度。
@export_range(-180.0, 180.0, 1.0) var forward_yaw_offset_degrees: float = 180

var current_state: State = State.IDLE
var sword_equipped := false
var combat_active := false
var _animation_player: AnimationPlayer
@onready var _sword_mesh: GeometryInstance3D = get_node_or_null(sword_mesh_path) as GeometryInstance3D


func _ready() -> void:
	var animation_players := find_children("*", "AnimationPlayer", true, false)
	if animation_players.is_empty():
		push_error("玩家模型缺少 AnimationPlayer，无法初始化动画状态机。")
		return
	_animation_player = animation_players[0] as AnimationPlayer
	if _sword_mesh == null:
		push_error("玩家模型缺少剑网格，请检查 Sword Mesh Path。")
	# 装备状态控制可见性，避免空手下落动画中残留的剑缩放轨道显示武器。
	_update_sword_visibility()
	for animation_name: StringName in [idle_animation, walk_animation, run_animation, jump_animation, falling_animation,
			sword_idle_animation, sword_walk_animation, sword_run_animation, sword_jump_animation, sword_falling_animation]:
		if not _animation_player.has_animation(animation_name):
			push_error("玩家模型缺少 %s 动画，请检查动画名称。" % animation_name)
			_animation_player = null
			return
	_setup_combat_animation()
	_animation_player.animation_finished.connect(_on_animation_finished)
	_play_state()


func set_sword_equipped(equipped: bool) -> void:
	if sword_equipped == equipped:
		return
	sword_equipped = equipped
	_update_sword_visibility()
	# 即使移动状态没变，装备切换也立即切换到当前动作的对应动画。
	_play_state()


func _update_sword_visibility() -> void:
	if _sword_mesh != null:
		_sword_mesh.visible = sword_equipped


func update_motion(motion_velocity: Vector3, delta: float = 0.0, is_running: bool = false, on_floor: bool = true) -> void:
	if combat_active:
		return
	var horizontal_speed := Vector2(motion_velocity.x, motion_velocity.z).length()
	if horizontal_speed > walk_stop_speed and delta > 0.0:
		var target_yaw := atan2(motion_velocity.x, motion_velocity.z) + deg_to_rad(forward_yaw_offset_degrees)
		# 只转动模型，摄像机枢轴保持独立；静止时保留最后朝向。
		global_rotation.y = lerp_angle(global_rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	# 空中状态优先于行走和奔跑；离开平台时也会自然进入下落动画。
	if not on_floor:
		_transition_to(State.JUMP if motion_velocity.y > 0.0 else State.FALLING)
		return
	# 使用不同的进入、退出阈值，避免低速时反复切换。
	var moving := horizontal_speed > (walk_start_speed if current_state == State.IDLE else walk_stop_speed)
	if not moving:
		_transition_to(State.IDLE)
	else:
		_transition_to(State.RUN if is_running else State.WALK)


func _transition_to(next_state: State) -> void:
	if next_state == current_state:
		return
	var previous_state := current_state
	current_state = next_state
	_play_state()
	state_changed.emit(previous_state, current_state)


func _play_state() -> void:
	if combat_active:
		return
	if _animation_player == null:
		return
	var animation_name := sword_idle_animation if sword_equipped else idle_animation
	match current_state:
		State.WALK:
			animation_name = sword_walk_animation if sword_equipped else walk_animation
		State.RUN:
			animation_name = sword_run_animation if sword_equipped else run_animation
		State.JUMP:
			animation_name = sword_jump_animation if sword_equipped else jump_animation
		State.FALLING:
			animation_name = sword_falling_animation if sword_equipped else falling_animation
	# 仅在进入状态时播放，避免每帧重置动画进度。
	_animation_player.play(animation_name, blend_time)


func _setup_combat_animation() -> void:
	if not _animation_player.has_animation(charge_animation) or not _animation_player.has_animation(attack_animation):
		push_error("模型缺少 attack-ready / attack-1 战斗动画")
		return
	# 使用每个模型独立的副本，避免改动 GLB 的共享动画资源。
	var strike := _animation_player.get_animation(attack_animation).duplicate() as Animation
	strike.loop_mode = Animation.LOOP_NONE
	var track := strike.add_track(Animation.TYPE_METHOD)
	var animation_root := _animation_player.get_node(_animation_player.root_node)
	strike.track_set_path(track, animation_root.get_path_to(self))
	strike.track_insert_key(track, clampf(attack_impact_seconds, 0.01, strike.length - 0.01), {"method": &"_emit_attack_impact", "args": []})
	var library := AnimationLibrary.new()
	library.add_animation(&"strike", strike)
	_animation_player.add_animation_library(&"combat", library)

func face_combat_direction(forward: Vector3) -> void:
	global_rotation.y = atan2(forward.x, forward.z) + deg_to_rad(forward_yaw_offset_degrees)

func begin_charge() -> void:
	combat_active = true
	_transition_to(State.CHARGE)
	_animation_player.play(charge_animation, 0.08)

func play_attack() -> void:
	combat_active = true
	_transition_to(State.ATTACK)
	_animation_player.play(&"combat/strike", 0.04)

func _emit_attack_impact() -> void:
	if combat_active and current_state == State.ATTACK:
		attack_impact.emit()

func _on_animation_finished(animation_name: StringName) -> void:
	if not combat_active:
		return
	if animation_name == charge_animation and current_state == State.CHARGE:
		# 准备动作抬剑后保留最后一帧，长按时不会反复抬剑。
		_animation_player.pause()
	elif animation_name == &"combat/strike" and current_state == State.ATTACK:
		cancel_combat()
		attack_finished.emit()

func cancel_combat() -> void:
	if not combat_active:
		return
	combat_active = false
	current_state = State.IDLE
	_play_state()
