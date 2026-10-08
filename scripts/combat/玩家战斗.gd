extends Node3D

signal health_changed(current: int, maximum: int)
signal attack_resolved(damage: int, hit_count: int)

const SECTOR := preload("res://scripts/combat/攻击扇形.gd")
enum Phase { IDLE, PRESSING, CHARGING, SWINGING }

@export_group("生命")
@export var max_health: int = 100
@export_group("攻击")
@export var base_damage: int = 20
@export var max_damage: int = 70
@export_range(0.05, 0.5, 0.01) var hold_threshold: float = 0.18
@export_range(0.2, 5.0, 0.05) var max_charge_seconds: float = 1.8
@export var quick_radius: float = 2.8
@export var quick_angle_degrees: float = 110.0
@export var charged_radius: float = 5.0
@export var charged_angle_degrees: float = 34.0
@export_group("蓄力镜头")
@export var charge_camera_distance: float = 3.1
@export var charge_camera_fov: float = 58.0
@export var charge_camera_offset: float = 0.65

var health: int
var phase := Phase.IDLE
var held_seconds := 0.0
var charge_ratio := 0.0
var _attack_damage := 0
var _attack_radius := 0.0
var _attack_angle := 0.0
var _attack_forward := Vector3.FORWARD
var _selected: Array[Node3D] = []
var _normal_distance := 4.0
var _normal_fov := 75.0
var _normal_offset := 0.0
var _impact_pending := false
var indicator: MeshInstance3D
@onready var player: CharacterBody3D = get_parent()

func _ready() -> void:
	health = max_health
	indicator = SECTOR.new()
	indicator.name = "蓄力攻击范围"
	add_child(indicator)
	indicator.top_level = true

func initialize() -> void:
	_normal_distance = player.camera_arm.spring_length
	_normal_fov = player.camera.fov
	_normal_offset = player.camera.h_offset
	player.player_model.attack_impact.connect(_resolve_attack)
	player.player_model.attack_finished.connect(_finish_attack)
	if player.is_local:
		player.add_to_group("combat_players")

func can_accept_input() -> bool:
	return player.is_local and not player.free_camera_enabled and not Session.input_blocked and not get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func press_attack() -> void:
	if phase != Phase.IDLE or not can_accept_input():
		return
	player.sword_equipped = true
	player.player_model.set_sword_equipped(true)
	phase = Phase.PRESSING
	held_seconds = 0.0
	charge_ratio = 0.0

func release_attack() -> void:
	if phase != Phase.PRESSING and phase != Phase.CHARGING:
		return
	if not can_accept_input():
		cancel_attack()
		return
	var charged := phase == Phase.CHARGING
	_attack_damage = roundi(lerpf(base_damage, maxi(base_damage, max_damage), charge_ratio)) if charged else base_damage
	_attack_radius = charged_radius if charged else quick_radius
	_attack_angle = charged_angle_degrees if charged else quick_angle_degrees
	_attack_forward = get_aim_forward()
	player.player_model.face_combat_direction(_attack_forward)
	phase = Phase.SWINGING
	_impact_pending = true
	_clear_selection()
	indicator.hide()
	player.player_model.play_attack()

func get_aim_forward() -> Vector3:
	var forward: Vector3 = -player.camera_yaw.global_basis.z
	forward.y = 0.0
	return forward.normalized()

func movement_multiplier() -> float:
	if phase == Phase.CHARGING:
		return 0.35
	if phase == Phase.SWINGING:
		return 0.15
	return 1.0

func _physics_process(delta: float) -> void:
	if not player.is_local:
		return
	if phase != Phase.IDLE and not can_accept_input():
		cancel_attack()
	if phase == Phase.PRESSING or phase == Phase.CHARGING:
		held_seconds += delta
		if phase == Phase.PRESSING and held_seconds >= hold_threshold:
			phase = Phase.CHARGING
			player.player_model.begin_charge()
		charge_ratio = clampf((held_seconds - hold_threshold) / maxf(max_charge_seconds, 0.01), 0.0, 1.0)
	if phase == Phase.CHARGING:
		var forward := get_aim_forward()
		player.player_model.face_combat_direction(forward)
		indicator.global_position = player.global_position + Vector3.DOWN * 1.12
		indicator.global_rotation = Vector3(0.0, atan2(-forward.x, -forward.z), 0.0)
		indicator.radius = charged_radius
		indicator.angle_degrees = charged_angle_degrees
		indicator.set_charge(charge_ratio)
		indicator.show()
		_update_selection(forward)
	var zooming := phase == Phase.CHARGING
	var weight := 1.0 - exp(-9.0 * delta)
	player.camera_arm.spring_length = lerpf(player.camera_arm.spring_length, charge_camera_distance if zooming else _normal_distance, weight)
	player.camera.fov = lerpf(player.camera.fov, charge_camera_fov if zooming else _normal_fov, weight)
	player.camera.h_offset = lerpf(player.camera.h_offset, charge_camera_offset if zooming else _normal_offset, weight)

func _in_sector(enemy: Node3D, forward: Vector3, reach: float, angle: float) -> bool:
	return not enemy.dead and SECTOR.contains(enemy.global_position + Vector3.UP * 0.55 - player.global_position, forward, reach, angle, enemy.hit_radius) and _has_line_of_sight(enemy)

func _has_line_of_sight(enemy: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(player.global_position, enemy.global_position + Vector3.UP * 0.55, 1)
	query.exclude = [player.get_rid(), enemy.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _update_selection(forward: Vector3) -> void:
	var next: Array[Node3D] = []
	for enemy: Node3D in get_tree().get_nodes_in_group("combat_enemies"):
		if _in_sector(enemy, forward, charged_radius, charged_angle_degrees):
			next.append(enemy)
			enemy.set_selected(true)
	for enemy in _selected:
		if is_instance_valid(enemy) and not next.has(enemy):
			enemy.set_selected(false)
	_selected = next

func _clear_selection() -> void:
	for enemy in _selected:
		if is_instance_valid(enemy):
			enemy.set_selected(false)
	_selected.clear()

func _resolve_attack() -> void:
	if phase != Phase.SWINGING or not _impact_pending:
		return
	_impact_pending = false
	var hit_count := 0
	for enemy: Node3D in get_tree().get_nodes_in_group("combat_enemies"):
		# 以剑落下这一帧的敌人位置判定，蓄力时选中并不保证命中。
		if _in_sector(enemy, _attack_forward, _attack_radius, _attack_angle):
			enemy.take_damage(_attack_damage, _attack_forward)
			hit_count += 1
	attack_resolved.emit(_attack_damage, hit_count)

func _finish_attack() -> void:
	phase = Phase.IDLE
	charge_ratio = 0.0
	_impact_pending = false

func cancel_attack() -> void:
	phase = Phase.IDLE
	charge_ratio = 0.0
	_impact_pending = false
	indicator.hide()
	_clear_selection()
	player.player_model.cancel_combat()

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	# 当前战斗原型中血量归零后继续操控角色。

func _exit_tree() -> void:
	_clear_selection()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(indicator) and phase != Phase.IDLE:
		cancel_attack()
