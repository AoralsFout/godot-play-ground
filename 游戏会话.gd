extends Node
## 独立管理连接，不受场景切换影响。仅由主机发布房间数据。

signal players_changed
signal chat_received(entry: Dictionary)
signal connection_status_changed(message: String)
signal player_state_received(peer_id: int, state: Dictionary)

const MAIN_MENU := "res://主菜单.tscn"
const GAME_SCENE := "res://根节点.tscn"
const MAX_PLAYERS := 16
const MAX_HISTORY := 100
const CONNECT_TIMEOUT := 10.0

var is_multiplayer := false
var input_blocked := false
var connecting := false
var nickname := "玩家"
var players: Dictionary = {}
var player_states: Dictionary = {}
var chat_history: Array[Dictionary] = []
var menu_notice := ""
var room_address := ""
var peer: ENetMultiplayerPeer
var _connect_elapsed := 0.0
var _latency_elapsed := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)


func _process(delta: float) -> void:
	if connecting:
		_connect_elapsed += delta
		if _connect_elapsed >= CONNECT_TIMEOUT:
			_fail_connection("连接超时，请检查房主 IP、端口和网络。")
	if not is_multiplayer or peer == null or not multiplayer.is_server():
		return
	_latency_elapsed += delta
	if _latency_elapsed >= 1.0:
		_latency_elapsed = 0.0
		for id: int in players:
			if id == 1:
				players[id]["ping"] = 0
			elif id in multiplayer.get_peers():
				var remote := peer.get_peer(id)
				players[id]["ping"] = int(remote.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		_publish_players()


func local_id() -> int:
	return multiplayer.get_unique_id() if is_multiplayer else 1


func is_host() -> bool:
	return is_multiplayer and multiplayer.is_server()


func validate_room(player_name: String, address: String, port_text: String, hosting: bool) -> String:
	if player_name.strip_edges().is_empty():
		return "请输入昵称。"
	if player_name.strip_edges().length() > 24:
		return "昵称最多 24 个字符。"
	if not address.is_valid_ip_address():
		return "请输入有效的 IP 地址。"
	if not hosting and address in ["0.0.0.0", "::"]:
		return "加入房间请填写房主的 IP，不能使用监听地址。"
	if not port_text.is_valid_int() or int(port_text) < 1 or int(port_text) > 65535:
		return "端口必须为 1 到 65535 的整数。"
	return ""


func start_single_player() -> void:
	_reset()
	nickname = "玩家"
	players[1] = {"nickname": nickname, "ping": 0}
	_enter_game()


func host_room(player_name: String, address: String, port: int) -> Error:
	_reset()
	var new_peer := ENetMultiplayerPeer.new()
	new_peer.set_bind_ip(address)
	var error := new_peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		new_peer.close()
		return error
	peer = new_peer
	multiplayer.multiplayer_peer = peer
	is_multiplayer = true
	nickname = _clean_name(player_name)
	room_address = "%s:%d" % [address, port]
	players[1] = {"nickname": nickname, "ping": 0}
	_enter_game()
	return OK


func join_room(player_name: String, address: String, port: int) -> Error:
	_reset()
	var new_peer := ENetMultiplayerPeer.new()
	var error := new_peer.create_client(address, port)
	if error != OK:
		new_peer.close()
		return error
	peer = new_peer
	multiplayer.multiplayer_peer = peer
	is_multiplayer = true
	connecting = true
	nickname = _clean_name(player_name)
	room_address = "%s:%d" % [address, port]
	connection_status_changed.emit("正在连接 %s…" % room_address)
	return OK


func cancel_connection() -> void:
	_reset()
	connection_status_changed.emit("")


func return_to_menu(message: String = "") -> void:
	_reset()
	menu_notice = message
	get_tree().change_scene_to_file(MAIN_MENU)


func _reset() -> void:
	get_tree().paused = false
	input_blocked = false
	connecting = false
	is_multiplayer = false
	_connect_elapsed = 0.0
	_latency_elapsed = 0.0
	if peer != null:
		peer.close()
	peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	player_states.clear()
	chat_history.clear()
	room_address = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _enter_game() -> void:
	connecting = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _connected() -> void:
	if connecting:
		_register_player.rpc_id(1, nickname)


func _connection_failed() -> void:
	if connecting:
		_fail_connection("无法连接房间，请检查 IP 和端口，确认房主已创建房间。")


func _fail_connection(message: String) -> void:
	_reset()
	connection_status_changed.emit(message)


func _server_disconnected() -> void:
	if connecting:
		_fail_connection("房间已关闭，或房主拒绝了连接。")
	elif is_multiplayer:
		return_to_menu("与房主断开连接，已返回主菜单。")


func _peer_disconnected(id: int) -> void:
	if not is_host() or not players.has(id):
		return
	var departing_name: String = players[id]["nickname"]
	players.erase(id)
	player_states.erase(id)
	_publish_players()
	_broadcast_chat(0, "系统", "%s 离开了房间" % departing_name)


@rpc("any_peer", "call_remote", "reliable")
func _register_player(player_name: String) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if id <= 1 or players.has(id):
		return
	players[id] = {"nickname": _clean_name(player_name), "ping": -1}
	_accept_join.rpc_id(id, players)
	_publish_players()
	_broadcast_chat(0, "系统", "%s 加入了房间" % players[id]["nickname"])


@rpc("authority", "call_remote", "reliable")
func _accept_join(roster: Dictionary) -> void:
	if not connecting:
		return
	players = roster.duplicate(true)
	_enter_game()


func _publish_players() -> void:
	players_changed.emit()
	if is_host():
		_receive_players.rpc(players)


@rpc("authority", "call_remote", "reliable")
func _receive_players(roster: Dictionary) -> void:
	players = roster.duplicate(true)
	for id: int in player_states.keys():
		if not players.has(id):
			player_states.erase(id)
	players_changed.emit()


func kick_player(id: int) -> void:
	if not is_host() or id == 1 or not players.has(id):
		return
	_kicked.rpc_id(id)
	# 断开 ENet 对等连接前，先发送完说明消息。
	peer.get_peer(id).peer_disconnect_later()
	_peer_disconnected(id)


@rpc("authority", "call_remote", "reliable")
func _kicked() -> void:
	return_to_menu.call_deferred("你已被房主踢出房间。")


func send_chat(message: String) -> void:
	var clean := message.strip_edges().left(256)
	if clean.is_empty():
		return
	if not is_multiplayer:
		_receive_chat(1, nickname, clean)
	elif is_host():
		_handle_chat(1, clean)
	else:
		_request_chat.rpc_id(1, clean)


@rpc("any_peer", "call_remote", "reliable")
func _request_chat(message: String) -> void:
	if is_host():
		_handle_chat(multiplayer.get_remote_sender_id(), message)


func _handle_chat(id: int, message: String) -> void:
	if not players.has(id):
		return
	var clean := message.strip_edges().left(256)
	if clean.is_empty():
		return
	_broadcast_chat(id, players[id]["nickname"], clean)


func _broadcast_chat(id: int, player_name: String, message: String) -> void:
	_receive_chat(id, player_name, message)
	_receive_chat.rpc(id, player_name, message)


@rpc("authority", "call_remote", "reliable")
func _receive_chat(id: int, player_name: String, message: String) -> void:
	var entry := {"id": id, "nickname": player_name, "message": message,
		"received_at": Time.get_ticks_msec(), "time": Time.get_time_string_from_system()}
	chat_history.append(entry)
	if chat_history.size() > MAX_HISTORY:
		chat_history.pop_front()
	chat_received.emit(entry)


func publish_local_state(state: Dictionary) -> void:
	if not is_multiplayer:
		return
	if is_host():
		_relay_state(1, state)
	else:
		_submit_state.rpc_id(1, state)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _submit_state(state: Dictionary) -> void:
	if is_host():
		var id := multiplayer.get_remote_sender_id()
		if players.has(id):
			_relay_state(id, state)


func _relay_state(id: int, state: Dictionary) -> void:
	_receive_state(id, state)
	_receive_state.rpc(id, state)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _receive_state(id: int, state: Dictionary) -> void:
	if not players.has(id) or id == local_id():
		return
	player_states[id] = state
	player_state_received.emit(id, state)


func _clean_name(value: String) -> String:
	var clean := value.strip_edges().replace("\n", " ").replace("\r", " ").left(24)
	return "玩家" if clean.is_empty() else clean
