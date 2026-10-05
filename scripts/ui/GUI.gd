extends CanvasLayer

const CHAT_SCRIPT := preload("res://scripts/ui/聊天框.gd")
const MENU_SCRIPT := preload("res://scripts/ui/游戏菜单.gd")
const COMPASS_DIRECTIONS := {
	"N": Vector2.UP, "S": Vector2.DOWN,
	"W": Vector2.LEFT, "E": Vector2.RIGHT,
}

@export var target_camera_path: NodePath

@onready var map_viewport: SubViewport = $小地图/SubViewport
@onready var map_camera: Camera3D = $小地图/SubViewport/地图摄像机
@onready var map_texture: TextureRect = $小地图/地图画面

var chat: VBoxContainer
var game_menu: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	map_texture.texture = map_viewport.get_texture()
	chat = CHAT_SCRIPT.new()
	chat.name = "聊天框"
	add_child(chat)
	game_menu = MENU_SCRIPT.new()
	game_menu.name = "游戏菜单"
	add_child(game_menu)
	game_menu.opened.connect(_menu_opened)


func _menu_opened() -> void:
	if chat.is_open:
		chat.close_chat()
	chat.hide()
	game_menu.closed.connect(chat.show, CONNECT_ONE_SHOT)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed("ui_cancel"):
		if chat.is_open:
			if chat.input.has_ime_text():
				return
			chat.close_chat()
		elif game_menu.is_open:
			game_menu.back()
		else:
			game_menu.open_menu()
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_T and not chat.is_open and not game_menu.is_open:
		chat.open_chat()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if target_camera_path.is_empty():
		return

	var target_camera := get_node_or_null(target_camera_path) as Camera3D
	if target_camera == null:
		return

	map_camera.global_position = target_camera.global_position
	map_camera.global_basis = target_camera.global_basis
	# 俯视摄像机的上方向向量指向玩家的朝向。
	var heading := atan2(-map_camera.global_basis.y.x, -map_camera.global_basis.y.z)
	var center := map_texture.position + map_texture.size * 0.5
	for direction: String in COMPASS_DIRECTIONS:
		var label := $小地图.get_node(direction) as Label
		var offset: Vector2 = COMPASS_DIRECTIONS[direction]
		label.position = center + offset.rotated(heading) * 83.0 - label.size * 0.5
	map_camera.projection = target_camera.projection
	map_camera.size = target_camera.size
	map_camera.cull_mask = target_camera.cull_mask
	map_camera.environment = target_camera.environment
	map_camera.near = target_camera.near
	map_camera.far = target_camera.far
