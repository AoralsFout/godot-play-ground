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
# 该骨架的躯干与双腿是独立分支；从第一节脊柱覆盖，保留移动的根部起伏。
@export var upper_body_root_bone: StringName = &"骨骼.001"
@export_range(0.0, 1.0, 0.01) var combat_blend_time: float = 0.08
@export_group("动画切换")
@export_range(0.0, 1.0, 0.01) var blend_time: float = 0.2
@export var walk_start_speed: float = 0.1
@export var walk_stop_speed: float = 0.05
@export_range(0.0, 30.0, 0.1) var turn_speed: float = 12.0
@export_range(-180.0, 180.0, 1.0) var forward_yaw_offset_degrees: float = 180

const MOTION_NODES: Array[StringName] = [&"Idle", &"Walk", &"Run", &"Jump", &"Falling"]
var current_state: State = State.IDLE
var motion_state: State = State.IDLE
var sword_equipped := false
var combat_active := false
var _combat_weight := 0.0
var _equipment_weight := 0.0
var _impact_emitted := false
var _animation_player: AnimationPlayer
var _motion_playback: AnimationNodeStateMachinePlayback
var _combat_playback: AnimationNodeStateMachinePlayback
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var _sword_mesh: GeometryInstance3D = get_node_or_null(sword_mesh_path) as GeometryInstance3D


func _ready() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("玩家模型缺少 AnimationPlayer。")
		return
	_animation_player = players[0] as AnimationPlayer
	if _sword_mesh == null:
		push_error("玩家模型缺少剑节点，请检查 Sword Mesh Path。")
		return
	animation_tree.active = false
	var animation_root := _animation_player.get_node(_animation_player.root_node)
	animation_tree.anim_player = animation_tree.get_path_to(_animation_player)
	animation_tree.root_node = animation_tree.get_path_to(animation_root)
	# 每个实例独立配置资源，装备和战斗参数不会影响其他玩家。
	animation_tree.tree_root = animation_tree.tree_root.duplicate(true)
	if not _setup_animation_library() or not _setup_upper_body_filter():
		return
	_configure_motion_nodes()
	_motion_playback = animation_tree.get("parameters/Locomotion/playback")
	_combat_playback = animation_tree.get("parameters/Combat/playback")
	_motion_playback.start(&"Idle")
	_combat_playback.start(&"Hold")
	animation_tree.set("parameters/UpperBody/blend_amount", 0.0)
	animation_tree.active = true
	_update_sword_visibility()


func _setup_animation_library() -> bool:
	for name: StringName in [idle_animation, walk_animation, run_animation, jump_animation, falling_animation,
			sword_idle_animation, sword_walk_animation, sword_run_animation, sword_jump_animation,
			sword_falling_animation, charge_animation, attack_animation]:
		if not _animation_player.has_animation(name):
			push_error("玩家模型缺少 %s 动画。" % name)
			return false
	var library := AnimationLibrary.new()
	var ready_animation := _animation_player.get_animation(charge_animation)
	var hold := Animation.new()
	hold.length = 0.1
	hold.loop_mode = Animation.LOOP_LINEAR
	# 从准备动作末帧提取姿势，不暂停移动层，也不反复抬剑。
	for i in ready_animation.get_track_count():
		var type := ready_animation.track_get_type(i)
		if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var track := hold.add_track(type)
		hold.track_set_path(track, ready_animation.track_get_path(i))
		var value: Variant
		match type:
			Animation.TYPE_POSITION_3D:
				value = ready_animation.position_track_interpolate(i, ready_animation.length)
			Animation.TYPE_ROTATION_3D:
				value = ready_animation.rotation_track_interpolate(i, ready_animation.length)
			Animation.TYPE_SCALE_3D:
				value = ready_animation.scale_track_interpolate(i, ready_animation.length)
		hold.track_insert_key(track, 0.0, value)
	library.add_animation(&"hold", hold)
	var strike := _animation_player.get_animation(attack_animation).duplicate() as Animation
	strike.loop_mode = Animation.LOOP_NONE
	var method_track := strike.add_track(Animation.TYPE_METHOD)
	var animation_root := _animation_player.get_node(_animation_player.root_node)
	strike.track_set_path(method_track, animation_root.get_path_to(self))
	strike.track_insert_key(method_track, clampf(attack_impact_seconds, 0.01, strike.length - 0.01), {"method": &"_emit_attack_impact", "args": []})
	strike.track_insert_key(method_track, strike.length - 0.001, {"method": &"_emit_attack_finished", "args": []})
	library.add_animation(&"strike", strike)
	_animation_player.add_animation_library(&"combat", library)
	return true


func _setup_upper_body_filter() -> bool:
	var skeletons := find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		push_error("玩家模型缺少 Skeleton3D。")
		return false
	var skeleton := skeletons[0] as Skeleton3D
	var root_bone := skeleton.find_bone(upper_body_root_bone)
	if root_bone < 0:
		push_error("找不到上半身根骨骼 %s。" % upper_body_root_bone)
		return false
	var graph := animation_tree.tree_root as AnimationNodeBlendTree
	var overlay := graph.get_node(&"UpperBody") as AnimationNodeBlend2
	var animation_root := _animation_player.get_node(_animation_player.root_node)
	var skeleton_path := str(animation_root.get_path_to(skeleton))
	for bone in skeleton.get_bone_count():
		var ancestor := bone
		while ancestor >= 0 and ancestor != root_bone:
			ancestor = skeleton.get_bone_parent(ancestor)
		if ancestor == root_bone:
			overlay.set_filter_path(NodePath(skeleton_path + ":" + skeleton.get_bone_name(bone)), true)
	# 方法轨道也必须通过过滤，否则上半身攻击不会结算伤害。
	overlay.set_filter_path(animation_root.get_path_to(self), true)
	return true


func _configure_motion_nodes() -> void:
	var graph := animation_tree.tree_root as AnimationNodeBlendTree
	var machine := graph.get_node(&"Locomotion") as AnimationNodeStateMachine
	var unarmed: Array[StringName] = [idle_animation, walk_animation, run_animation, jump_animation, falling_animation]
	var armed: Array[StringName] = [sword_idle_animation, sword_walk_animation, sword_run_animation, sword_jump_animation, sword_falling_animation]
	for i in MOTION_NODES.size():
		var state := machine.get_node(MOTION_NODES[i]) as AnimationNodeBlendTree
		(state.get_node(&"Unarmed") as AnimationNodeAnimation).animation = unarmed[i]
		(state.get_node(&"Sword") as AnimationNodeAnimation).animation = armed[i]
	for i in machine.get_transition_count():
		var transition := machine.get_transition(i)
		transition.xfade_time = minf(blend_time, 0.06) if machine.get_transition_to(i) == &"Jump" else blend_time
	var combat := graph.get_node(&"Combat") as AnimationNodeStateMachine
	(combat.get_node(&"Charge") as AnimationNodeAnimation).animation = charge_animation


func _physics_process(delta: float) -> void:
	if _motion_playback == null:
		return
	_equipment_weight = move_toward(_equipment_weight, 1.0 if sword_equipped else 0.0, delta / maxf(blend_time, 0.001))
	for node in MOTION_NODES:
		animation_tree.set("parameters/Locomotion/%s/Equipment/blend_amount" % node, _equipment_weight)
	var target := 1.0 if combat_active else 0.0
	_combat_weight = move_toward(_combat_weight, target, delta / maxf(combat_blend_time, 0.001))
	animation_tree.set("parameters/UpperBody/blend_amount", _combat_weight)


func set_sword_equipped(equipped: bool) -> void:
	if sword_equipped == equipped:
		return
	sword_equipped = equipped
	_update_sword_visibility()


func _update_sword_visibility() -> void:
	if _sword_mesh != null:
		_sword_mesh.visible = sword_equipped


func update_motion(motion_velocity: Vector3, delta: float = 0.0, is_running: bool = false, on_floor: bool = true) -> void:
	if _motion_playback == null:
		return
	var speed := Vector2(motion_velocity.x, motion_velocity.z).length()
	# 战斗锁定瞄准朝向，但移动动画仍然持续更新。
	if not combat_active and speed > walk_stop_speed and delta > 0.0:
		var target_yaw := atan2(motion_velocity.x, motion_velocity.z) + deg_to_rad(forward_yaw_offset_degrees)
		global_rotation.y = lerp_angle(global_rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
	var next := State.IDLE
	if not on_floor:
		next = State.JUMP if motion_velocity.y > 0.0 else State.FALLING
	elif speed > (walk_start_speed if motion_state == State.IDLE else walk_stop_speed):
		next = State.RUN if is_running else State.WALK
	var player := get_parent()
	var walk_speed: float = player.move_speed
	var run_speed: float = player.run_speed
	animation_tree.set("parameters/Locomotion/Walk/Speed/scale", clampf(speed / maxf(walk_speed, 0.01), 0.05, 2.0))
	animation_tree.set("parameters/Locomotion/Run/Speed/scale", clampf(speed / maxf(run_speed, 0.01), 0.05, 2.0))
	if next != motion_state:
		motion_state = next
		_motion_playback.travel(MOTION_NODES[motion_state])
	if not combat_active:
		_set_state(motion_state)


func _set_state(next: State) -> void:
	if current_state == next:
		return
	var previous := current_state
	current_state = next
	state_changed.emit(previous, current_state)


func get_locomotion_animation() -> StringName:
	var unarmed: Array[StringName] = [idle_animation, walk_animation, run_animation, jump_animation, falling_animation]
	var armed: Array[StringName] = [sword_idle_animation, sword_walk_animation, sword_run_animation, sword_jump_animation, sword_falling_animation]
	return armed[motion_state] if sword_equipped else unarmed[motion_state]


func get_motion_play_position() -> float:
	return _motion_playback.get_current_play_position() if _motion_playback != null else 0.0


func get_combat_node() -> StringName:
	return _combat_playback.get_current_node() if _combat_playback != null else &""


func face_combat_direction(forward: Vector3) -> void:
	global_rotation.y = atan2(forward.x, forward.z) + deg_to_rad(forward_yaw_offset_degrees)


func begin_charge() -> void:
	if _combat_playback == null:
		return
	combat_active = true
	_set_state(State.CHARGE)
	_combat_playback.start(&"Charge")


func play_attack() -> void:
	if _combat_playback == null:
		return
	var from_charge := combat_active and current_state == State.CHARGE
	combat_active = true
	_impact_emitted = false
	_set_state(State.ATTACK)
	if from_charge:
		_combat_playback.travel(&"Attack")
	else:
		_combat_playback.start(&"Attack")


func _emit_attack_impact() -> void:
	if combat_active and current_state == State.ATTACK and not _impact_emitted:
		_impact_emitted = true
		attack_impact.emit()


func _emit_attack_finished() -> void:
	if not combat_active or current_state != State.ATTACK:
		return
	cancel_combat()
	attack_finished.emit()


func cancel_combat() -> void:
	if not combat_active:
		return
	combat_active = false
	_impact_emitted = true
	_set_state(motion_state)
