## 管理游戏内生命条、小地图、帧率及相机模式显示。
## 连接聊天和菜单输入状态，小地图跟随本地玩家，并发出自由相机切换请求。

extends CanvasLayer

signal free_camera_toggle_requested

const CHAT_SCRIPT := preload("res://scripts/ui/聊天框.gd")
const MENU_SCRIPT := preload("res://scripts/ui/游戏菜单.gd")
const COMPASS_DIRECTIONS := {
	"N": Vector2.UP, "S": Vector2.DOWN,
	"W": Vector2.LEFT, "E": Vector2.RIGHT,
}

## 小地图目标摄像机相对界面的节点路径；主场景设置为本地玩家顶视摄像机，留空或路径无效时跳过跟随。
@export var target_camera_path: NodePath

@onready var map_viewport: SubViewport = $小地图/SubViewport
@onready var map_camera: Camera3D = $小地图/SubViewport/地图摄像机
@onready var map_texture: TextureRect = $小地图/地图画面

var chat: VBoxContainer
var game_menu: Control
var debug_info: Label
var health_bar: ProgressBar
var health_label: Label
var _combat: Node
var _fps_elapsed := 0.0
var _free_camera_enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	map_texture.texture = map_viewport.get_texture()
	# 空合成器覆盖世界的体积云后处理，俯视地图只显示地形与标记。
	map_camera.compositor = Compositor.new()
	chat = CHAT_SCRIPT.new()
	chat.name = "聊天框"
	add_child(chat)
	game_menu = MENU_SCRIPT.new()
	game_menu.name = "游戏菜单"
	add_child(game_menu)
	game_menu.opened.connect(_menu_opened)
	debug_info = UIStyle.label("", 16)
	debug_info.name = "调试信息"
	debug_info.theme = UIStyle.theme()
	debug_info.position = Vector2(18, 90)
	debug_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_info.add_theme_color_override("font_outline_color", UIStyle.INK)
	debug_info.add_theme_constant_override("outline_size", 4)
	add_child(debug_info)
	_create_health_bar()
	_update_debug_info()


func set_free_camera_enabled(enabled: bool) -> void:
	_free_camera_enabled = enabled
	_update_debug_info()


func _update_debug_info() -> void:
	var mode := "自由相机 · WASD 移动 · Space 上升 · Ctrl 下降 · Shift 加速" if _free_camera_enabled else "第三人称 · Q 持剑/收剑 · 左键点按攻击 / 长按蓄力"
	debug_info.text = "FPS: %d\n%s" % [Engine.get_frames_per_second(), mode]


func _menu_opened() -> void:
	if is_instance_valid(_combat):
		_combat.cancel_attack()
	if chat.is_open:
		chat.close_chat()
	chat.hide()
	game_menu.closed.connect(chat.show, CONNECT_ONE_SHOT)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_TAB and not Session.input_blocked and not get_tree().paused:
		free_camera_toggle_requested.emit()
		get_viewport().set_input_as_handled()
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

func _process(delta: float) -> void:
	_fps_elapsed += delta
	if _fps_elapsed >= 0.25:
		_fps_elapsed = 0.0
		_update_debug_info()
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
		var map_offset: Vector2 = COMPASS_DIRECTIONS[direction]
		label.position = center + map_offset.rotated(heading) * 83.0 - label.size * 0.5
	map_camera.projection = target_camera.projection
	map_camera.size = target_camera.size
	map_camera.cull_mask = target_camera.cull_mask
	map_camera.environment = target_camera.environment
	map_camera.near = target_camera.near
	map_camera.far = target_camera.far


func _create_health_bar() -> void:
	var panel := PanelContainer.new()
	panel.name = "玩家生命面板"
	panel.position = Vector2(18, 14)
	panel.size = Vector2(270, 68)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme = UIStyle.theme()
	panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.07, 0.14, 0.20, 0.88), 8, 10))
	add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	health_label = UIStyle.label("生命 100 / 100", 16)
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.name = "玩家血条"
	health_bar.custom_minimum_size = Vector2(250, 16)
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("background", UIStyle.box(Color(0.20, 0.10, 0.14), 4, 0))
	health_bar.add_theme_stylebox_override("fill", UIStyle.box(Color(0.88, 0.20, 0.29), 4, 0))
	column.add_child(health_bar)

func bind_player_health(combat: Node) -> void:
	if is_instance_valid(_combat) and _combat.health_changed.is_connected(_update_health):
		_combat.health_changed.disconnect(_update_health)
	_combat = combat
	_combat.health_changed.connect(_update_health)
	_update_health(_combat.health, _combat.max_health)

func _update_health(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "生命 %d / %d" % [current, maximum]
