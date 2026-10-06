extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/玩家.tscn")
var avatars: Dictionary = {}
var _next_slot := 0
var game_time := 0.0
var water_material: ShaderMaterial

@onready var player_container: Node3D = $Players
@onready var gui: CanvasLayer = $GUI


func _ready() -> void:
	var water: MeshInstance3D = $世界场景/水面
	water_material = water.get_active_material(0).duplicate() as ShaderMaterial
	water.set_surface_override_material(0, water_material)
	water_material.set_shader_parameter("use_game_time", true)
	# 也支持直接从编辑器运行此场景。
	if Session.players.is_empty():
		Session.players[1] = {"nickname": "玩家", "ping": 0}
	Session.players_changed.connect(_sync_players)
	Session.player_state_received.connect(_receive_state)
	gui.free_camera_toggle_requested.connect(_toggle_free_camera)
	_sync_players()


func _process(delta: float) -> void:
	game_time += delta
	water_material.set_shader_parameter("game_time", game_time)


func _sync_players() -> void:
	for id: int in avatars.keys():
		if not Session.players.has(id):
			avatars[id].queue_free()
			avatars.erase(id)
	for id: int in Session.players:
		if avatars.has(id):
			continue
		var avatar := PLAYER_SCENE.instantiate()
		avatar.name = "Player_%d" % id
		avatar.peer_id = id
		avatar.is_local = id == Session.local_id()
		avatar.player_nickname = Session.players[id]["nickname"]
		avatar.set_multiplayer_authority(id)
		_next_slot += 1
		avatar.position = Vector3((_next_slot - 1) % 8 * 2.0, 4, -10 + floorf((_next_slot - 1) / 8.0) * 2.0)
		avatar.rotation.y = PI
		player_container.add_child(avatar)
		avatars[id] = avatar
		if avatar.is_local:
			avatar.free_camera_changed.connect(gui.set_free_camera_enabled)
			gui.target_camera_path = gui.get_path_to(avatar.get_node("顶视图摄像机枢轴/顶视图摄像机"))
		elif Session.player_states.has(id):
			avatar.apply_network_state(Session.player_states[id])


func _toggle_free_camera() -> void:
	var avatar: Node3D = avatars.get(Session.local_id())
	if is_instance_valid(avatar):
		avatar.toggle_free_camera()


func _receive_state(id: int, state: Dictionary) -> void:
	if avatars.has(id) and id != Session.local_id():
		avatars[id].apply_network_state(state)
