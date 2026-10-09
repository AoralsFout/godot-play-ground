## 构建聊天记录、近期消息和消息输入框。
## 使用原生文本输入支持中文输入法，协调聊天期间的玩家输入阻塞。

extends VBoxContainer
## 原生 LineEdit 负责 Unicode 文本、输入法预编辑和候选框定位。

signal active_changed(active: bool)

const MESSAGE_LIFETIME := 8.0
const MAX_RECENT := 5
const IDLE_HINT := "T 聊天  ·  Esc 菜单  ·  Tab 自由相机"
var is_open := false
var recent: VBoxContainer
var history_panel: PanelContainer
var history_scroll: ScrollContainer
var history_list: VBoxContainer
var compose_panel: PanelContainer
var input: LineEdit
var hint: Label
var _recent_rows: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UIStyle.theme()
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 18
	offset_bottom = -18
	recent = VBoxContainer.new()
	recent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(recent)
	history_panel = PanelContainer.new()
	history_panel.add_theme_stylebox_override("panel", UIStyle.box(Color(0.06, 0.14, 0.20, 0.92), 8, 12))
	add_child(history_panel)
	var history_content := VBoxContainer.new()
	history_panel.add_child(history_content)
	history_content.add_child(UIStyle.label("聊天记录", 16, UIStyle.ACCENT))
	history_scroll = ScrollContainer.new()
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_content.add_child(history_scroll)
	history_list = VBoxContainer.new()
	history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_scroll.add_child(history_list)
	compose_panel = PanelContainer.new()
	compose_panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.INK, 8, 8))
	add_child(compose_panel)
	input = LineEdit.new()
	input.placeholder_text = "输入消息，Enter 发送"
	input.max_length = 256
	input.custom_minimum_size.y = 42
	input.text_submitted.connect(_send)
	compose_panel.add_child(input)
	hint = UIStyle.label(IDLE_HINT, 14, UIStyle.MUTED)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_outline_color", UIStyle.INK)
	hint.add_theme_constant_override("outline_size", 4)
	add_child(hint)
	history_panel.hide()
	compose_panel.hide()
	for entry in Session.chat_history:
		_append_history(entry)
	Session.chat_received.connect(_message_received)
	get_viewport().size_changed.connect(_resize_chat)
	_resize_chat()


func _resize_chat() -> void:
	var viewport_size := get_viewport_rect().size
	offset_right = 18 + minf(500, maxf(240, viewport_size.x - 36))
	offset_top = -minf(390, viewport_size.y - 40)
	history_scroll.custom_minimum_size.y = minf(220, maxf(100, viewport_size.y - 260))


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	for index in range(_recent_rows.size() - 1, -1, -1):
		var entry := _recent_rows[index]
		var age := (now - int(entry["created_at"])) / 1000.0
		var row: Control = entry["node"]
		if age >= MESSAGE_LIFETIME:
			row.queue_free()
			_recent_rows.remove_at(index)
		else:
			row.modulate.a = clampf(MESSAGE_LIFETIME - age, 0.0, 1.0)


func open_chat() -> void:
	is_open = true
	recent.hide()
	history_panel.show()
	compose_panel.show()
	hint.text = "Enter 发送  ·  Esc 收起"
	Session.input_blocked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	input.grab_focus()
	_scroll_to_bottom.call_deferred()
	active_changed.emit(true)


func close_chat() -> void:
	is_open = false
	input.release_focus()
	history_panel.hide()
	compose_panel.hide()
	recent.show()
	hint.text = IDLE_HINT
	Session.input_blocked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	active_changed.emit(false)


func _send(value: String) -> void:
	# 按回车确认中文候选词时，不能发送尚未完成的消息。
	if input.has_ime_text():
		return
	if not value.strip_edges().is_empty():
		Session.send_chat(value)
		input.clear()
	close_chat()


func _message_label(entry: Dictionary, include_time: bool) -> Label:
	var prefix := "[%s] " % entry["time"] if include_time else ""
	var result := UIStyle.label("%s%s：%s" % [prefix, entry["nickname"], entry["message"]], 16)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not include_time:
		result.max_lines_visible = 3
	if entry["id"] == 0:
		result.add_theme_color_override("font_color", UIStyle.ACCENT)
	return result


func _append_history(entry: Dictionary) -> void:
	history_list.add_child(_message_label(entry, true))
	while history_list.get_child_count() > Session.MAX_HISTORY:
		var oldest := history_list.get_child(0)
		history_list.remove_child(oldest)
		oldest.queue_free()


func _message_received(entry: Dictionary) -> void:
	_append_history(entry)
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", UIStyle.box(Color(0.06, 0.14, 0.20, 0.78), 6, 8))
	row.add_child(_message_label(entry, false))
	recent.add_child(row)
	_recent_rows.append({"node": row, "created_at": entry["received_at"]})
	if _recent_rows.size() > MAX_RECENT:
		var oldest: Dictionary = _recent_rows.pop_front()
		oldest["node"].queue_free()
	if is_open:
		_scroll_to_bottom.call_deferred()


func _scroll_to_bottom() -> void:
	await get_tree().process_frame
	if is_instance_valid(history_scroll):
		history_scroll.scroll_vertical = int(history_scroll.get_v_scroll_bar().max_value)
