extends SceneTree
## 使用 Forward+ 离线烘焙，不在游戏启动时执行。
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := load("res://世界场景.tscn").instantiate() as Node3D
	root.add_child(world)
	world.get_node("水面").set_process(false)
	world.get_node("世界环境").set_process(false)
	var gi := world.get_node("VoxelGI 全局光照") as VoxelGI
	gi.position.y = 40.0
	gi.size = Vector3(4000, 180, 3000)
	# 平面小地图代理仅用于显示，不应成为遮挡全局光照（GI）的不透明顶盖。
	world.get_node("地图水面").gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	await process_frame
	await process_frame
	print("BAKE sea=15 GI_bottom=", gi.global_position.y - gi.size.y * 0.5)
	gi.bake(world)
	if gi.data == null:
		push_error("VoxelGI bake produced no data")
		quit(1)
		return
	var error := ResourceSaver.save(gi.data, "res://assets/海岛光照.res")
	print("BAKE save=", error, " bounds=", gi.data.get_bounds())
	world.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
