class_name PlayerAnimationStateMachine
extends Node3D

signal state_changed(previous_state: State, current_state: State)

enum State { IDLE, WALK, RUN, JUMP, FALLING }

@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"walk"
@export var run_animation: StringName = &"run"
@export var jump_animation: StringName = &"jump"
@export var falling_animation: StringName = &"falling"
@export_range(0.0, 1.0, 0.01) var blend_time: float = 0.2
@export var walk_start_speed: float = 0.1
@export var walk_stop_speed: float = 0.05
@export_range(0.0, 30.0, 0.1) var turn_speed: float = 12.0
# 默认模型正面为 +Z；若模型正面为 -Z，将偏移设为 180 度。
@export_range(-180.0, 180.0, 1.0) var forward_yaw_offset_degrees: float = 180

var current_state: State = State.IDLE
var _animation_player: AnimationPlayer


func _ready() -> void:
	var animation_players := find_children("*", "AnimationPlayer", true, false)
	if animation_players.is_empty():
		push_error("玩家模型缺少 AnimationPlayer，无法初始化动画状态机。")
		return
	_animation_player = animation_players[0] as AnimationPlayer
	for animation_name: StringName in [idle_animation, walk_animation, run_animation, jump_animation, falling_animation]:
		if not _animation_player.has_animation(animation_name):
			push_error("玩家模型缺少 %s 动画，请检查动画名称。" % animation_name)
			_animation_player = null
			return
	_play_state()


func update_motion(motion_velocity: Vector3, delta: float = 0.0, is_running: bool = false, on_floor: bool = true) -> void:
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
	if _animation_player == null:
		return
	var animation_name := idle_animation
	match current_state:
		State.WALK:
			animation_name = walk_animation
		State.RUN:
			animation_name = run_animation
		State.JUMP:
			animation_name = jump_animation
		State.FALLING:
			animation_name = falling_animation
	# 仅在进入状态时播放，避免每帧重置动画进度。
	_animation_player.play(animation_name, blend_time)
