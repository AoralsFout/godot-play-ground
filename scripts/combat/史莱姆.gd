extends CharacterBody3D

@export var max_health: int = 140
@export var move_speed: float = 2.4
@export var attack_damage: int = 10
@export var attack_range: float = 1.65
@export var attack_windup: float = 0.42
@export var attack_recovery: float = 0.85
@export var aggro_range: float = 24.0
@export var corpse_wait: float = 1.2
@export var fade_seconds: float = 1.3
@export var hit_radius: float = 0.65

var health: int
var dead := false
var selected := false
var target: CharacterBody3D
var _time := 0.0
var _hurt_time := 0.0
var _death_time := 0.0
var _attack_time := -1.0
var _cooldown := 0.0
var _attack_direction := Vector3.FORWARD
var _knockback := Vector3.ZERO
var _animator: AnimationPlayer
var _animation_playback: AnimationNodeStateMachinePlayback
var _current_animation: StringName = &""
@onready var animation_tree: AnimationTree = $AnimationTree
var _body_material: StandardMaterial3D
@onready var visual: Node3D = $外观
@onready var body: MeshInstance3D = $外观/模型/身体
@onready var health_bar: Sprite3D = $头顶血条
@onready var collision: CollisionShape3D = $碰撞

func _ready() -> void:
	health = max_health
	add_to_group("combat_enemies")
	_body_material = body.get_active_material(0).duplicate() as StandardMaterial3D
	body.material_override = _body_material
	_setup_animations()
	_play_animation(&"idle")
	_update_health_bar()

func set_selected(value: bool) -> void:
	selected = value and not dead

func _physics_process(delta: float) -> void:
	_time += delta
	_hurt_time = maxf(0.0, _hurt_time - delta)
	if dead:
		_death_time += delta
		var fade := clampf((_death_time - corpse_wait) / maxf(fade_seconds, 0.01), 0.0, 1.0)
		for mesh: GeometryInstance3D in visual.find_children("*", "GeometryInstance3D", true, false):
			mesh.transparency = fade
		if fade >= 1.0:
			queue_free()
		return
	_update_color()
	_cooldown = maxf(0.0, _cooldown - delta)
	if not is_instance_valid(target):
		_find_target()
	var direction := Vector3.ZERO
	if is_instance_valid(target):
		direction = target.global_position - global_position
		direction.y = 0.0
	var distance := direction.length()
	if _attack_time >= 0.0:
		_attack_time += delta
		velocity.x = _attack_direction.x * 3.2 if _attack_time < attack_windup else 0.0
		velocity.z = _attack_direction.z * 3.2 if _attack_time < attack_windup else 0.0
		if _attack_time >= attack_windup:
			_try_hit_player()
			_attack_time = -1.0
			_cooldown = attack_recovery
	elif is_instance_valid(target) and distance <= attack_range and _cooldown <= 0.0:
		_attack_direction = direction.normalized()
		_attack_time = 0.0
		_play_animation(&"attack", 0.375 / maxf(attack_windup, 0.01))
		velocity.x = 0.0
		velocity.z = 0.0
	elif is_instance_valid(target) and distance > attack_range * 0.85 and distance <= aggro_range:
		direction = direction.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		visual.rotation.y = atan2(-direction.x, -direction.z)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 14.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 14.0)
	velocity += _knockback * delta * 16.0
	_knockback = _knockback.move_toward(Vector3.ZERO, delta * 24.0)
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if _attack_time < 0.0:
		_play_animation(&"move-forward" if Vector2(velocity.x, velocity.z).length() > 0.1 else &"idle")
	var bounce := sin(_time * 8.0) * 0.04 if Vector2(velocity.x, velocity.z).length() > 0.1 else sin(_time * 2.5) * 0.02
	var squash := -0.16 * sin(clampf(_attack_time / maxf(attack_windup, 0.01), 0.0, 1.0) * PI) if _attack_time >= 0.0 else bounce
	visual.scale = Vector3(1.0 - squash * 0.5, 1.0 + squash, 1.0 - squash * 0.5)

func _find_target() -> void:
	var nearest := INF
	for candidate: CharacterBody3D in get_tree().get_nodes_in_group("combat_players"):
		var distance := global_position.distance_to(candidate.global_position)
		if distance < nearest:
			nearest = distance
			target = candidate

func _try_hit_player() -> void:
	if not is_instance_valid(target):
		return
	var offset := target.global_position - (global_position + Vector3.UP * 0.55)
	if absf(offset.y) > 1.6:
		return
	offset.y = 0.0
	if offset.length() > attack_range + 0.35 or (_attack_direction.dot(offset.normalized()) < 0.2 and offset.length() > 0.6):
		return
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, target.global_position, 1)
	query.exclude = [get_rid(), target.get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		target.take_damage(attack_damage)

func take_damage(amount: int, direction: Vector3 = Vector3.ZERO) -> void:
	if dead or amount <= 0:
		return
	health = maxi(0, health - amount)
	_hurt_time = 0.24
	_knockback = direction * 4.0
	# 受击打断史莱姆本次扑击，玩家攻击不会重复结算。
	_attack_time = -1.0
	_cooldown = maxf(_cooldown, 0.32)
	_update_health_bar()
	_update_color()
	if health == 0:
		_die()

func _update_color() -> void:
	var color := Color(0.10, 0.78, 0.18, 0.78)
	if _hurt_time > 0.0:
		color = Color(1.0, 0.13, 0.16, 0.92)
	elif selected:
		# 约 1.1 秒一轮的轻微亮度起伏。
		color = color.lerp(Color(0.70, 1.0, 0.78), (sin(_time * TAU / 1.1) * 0.5 + 0.5) * 0.20)
	_body_material.albedo_color = color

func _update_health_bar() -> void:
	var image := Image.create(128, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.06, 0.12, 0.10, 0.92))
	image.fill_rect(Rect2i(3, 3, 122, 12), Color(0.25, 0.16, 0.17, 1.0))
	var width := roundi(122.0 * float(health) / max_health)
	if width > 0:
		image.fill_rect(Rect2i(3, 3, width, 12), Color(0.86, 0.20, 0.26, 1.0))
	health_bar.texture = ImageTexture.create_from_image(image)

func _die() -> void:
	dead = true
	selected = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	collision.set_deferred("disabled", true)
	health_bar.hide()
	visual.scale = Vector3.ONE
	_play_animation(&"died")


func _setup_animations() -> void:
	animation_tree.active = false
	_animator = visual.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := AnimationLibrary.new()
	for animation_name: StringName in _animator.get_animation_list():
		var animation := _animator.get_animation(animation_name).duplicate() as Animation
		animation.loop_mode = Animation.LOOP_LINEAR if animation_name in [&"idle", &"move-forward", &"move-forward-fast", &"falling"] else Animation.LOOP_NONE
		library.add_animation(animation_name, animation)
	_animator.remove_animation_library(&"")
	_animator.add_animation_library(&"", library)
	animation_tree.anim_player = animation_tree.get_path_to(_animator)
	animation_tree.root_node = animation_tree.get_path_to(_animator.get_node(_animator.root_node))
	animation_tree.tree_root = animation_tree.tree_root.duplicate(true)
	_animation_playback = animation_tree.get("parameters/StateMachine/playback")
	animation_tree.active = true

func _play_animation(animation_name: StringName, speed: float = 1.0) -> void:
	if _current_animation == animation_name:
		return
	_current_animation = animation_name
	animation_tree.set("parameters/Speed/scale", speed)
	if _animation_playback.is_playing():
		_animation_playback.travel(animation_name)
	else:
		_animation_playback.start(animation_name)
