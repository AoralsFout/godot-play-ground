class_name PlayerAnimationStateMachine
extends Node3D

signal state_changed(previous_state: State, current_state: State)

enum State { IDLE, WALK }

@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"walk"
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
	if not _animation_player.has_animation(idle_animation) or not _animation_player.has_animation(walk_animation):
		push_error("玩家模型缺少 Idle 或 walk 动画，请检查动画名称。")
		_animation_player = null
		return
	_play_state()


func update_motion(motion_velocity: Vector3, delta: float = 0.0) -> void:
	var horizontal_speed := Vector2(motion_velocity.x, motion_velocity.z).length()
	if horizontal_speed > walk_stop_speed and delta > 0.0:
		var target_yaw := atan2(motion_velocity.x, motion_velocity.z) + deg_to_rad(forward_yaw_offset_degrees)
		# 只转动模型，摄像机枢轴保持独立；静止时保留最后朝向。
		global_rotation.y = lerp_angle(global_rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	# 使用不同的进入、退出阈值，避免低速时反复切换。
	match current_state:
		State.IDLE:
			if horizontal_speed > walk_start_speed:
				_transition_to(State.WALK)
		State.WALK:
			if horizontal_speed <= walk_stop_speed:
				_transition_to(State.IDLE)


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
	var animation_name := idle_animation if current_state == State.IDLE else walk_animation
	# 仅在进入状态时播放，保持循环动画的进度。
	_animation_player.play(animation_name, blend_time)
