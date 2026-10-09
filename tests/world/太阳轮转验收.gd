## 太阳轮转功能验收。
## 检查太阳轮转速度、轴向、暂停、编辑器预览及天空参数同步。

extends SceneTree

const SKY_SCRIPT := preload("res://scripts/world/天空.gd")
var _failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _run() -> void:
	var world := Node3D.new()
	var sun := DirectionalLight3D.new()
	sun.name = "日光"
	sun.rotation_degrees = Vector3(-10.0, 35.0, 0.0)
	world.add_child(sun)
	var moon := DirectionalLight3D.new()
	moon.name = "月光"
	moon.rotation_degrees = Vector3(-30.0, -40.0, 0.0)
	world.add_child(moon)
	var sky := SKY_SCRIPT.new()
	sky.set_process(false)
	world.add_child(sky)
	root.add_child(world)
	var original := sun.rotation_degrees
	var moon_original := moon.rotation_degrees
	sky._process(1.0)
	_check(sun.rotation_degrees.is_equal_approx(original), "默认开启了太阳轮转")
	sky.sun_auto_rotate = true
	sky.sun_rotation_speed = 10.0
	sky._process(2.0)
	_check(is_equal_approx(sun.rotation_degrees.x, original.x + 20.0), "轮转没有按度/秒推进 X 轴")
	_check(is_equal_approx(sun.rotation_degrees.y, original.y), "昼夜轮转修改了太阳方位")
	_check(sky.sky_material.get_shader_parameter("sky_sun_direction").is_equal_approx(sun.global_basis.z.normalized()), "轮转后天空方向没有同步")
	_check(sun.light_energy < 0.001, "太阳进入地平线下后没有关闭直射光")
	sky.sun_rotation_speed = -20.0
	sky._process(1.0)
	_check(sun.rotation_degrees.is_equal_approx(original), "反向轮转没有回到原角度")
	_check(sun.light_energy > 0.0, "太阳回到地平线上后没有恢复直射光")
	sky.sun_rotation_speed = 0.0
	sky._process(100.0)
	_check(sun.rotation_degrees.is_equal_approx(original), "速度 0 仍在轮转")
	sky.sun_rotation_axis = 1
	sky.sun_rotation_speed = 15.0
	sky._process(2.0)
	_check(is_equal_approx(sun.rotation_degrees.y, original.y + 30.0), "方位轮转没有按 Y 轴推进")
	_check(is_equal_approx(sun.rotation_degrees.x, original.x), "方位轮转修改了太阳高度")
	sun.rotation_degrees.y = 179.0
	sky._process(1.0)
	_check(is_equal_approx(sun.rotation_degrees.y, -166.0), "跨越一圈时没有正确环绕")
	_check(moon.rotation_degrees.is_equal_approx(moon_original), "太阳轮转修改了独立月亮的方向")
	sky.sun_auto_rotate = false
	var stopped := sun.rotation
	sky._process(5.0)
	_check(sun.rotation.is_equal_approx(stopped), "关闭主开关后仍在轮转")
	sky.sun_auto_rotate = true
	sky.sun_rotation_editor_preview = false
	sky._process(1.0)
	if Engine.is_editor_hint():
		_check(sun.rotation.is_equal_approx(stopped), "关闭编辑器预览后太阳仍在轮转")
		sky.sun_rotation_editor_preview = true
		sky._process(1.0)
		_check(not sun.rotation.is_equal_approx(stopped), "开启编辑器预览后没有轮转")
	else:
		_check(not sun.rotation.is_equal_approx(stopped), "编辑器预览开关关闭了运行时轮转")
	sky.set_process(true)
	paused = true
	stopped = sun.rotation
	for frame in 3:
		await process_frame
	_check(sun.rotation.is_equal_approx(stopped), "游戏暂停后太阳仍在轮转")
	paused = false
	sky.set_process(false)
	sky.sun_path = NodePath("../不存在的日光")
	sky._process(1.0)
	world.queue_free()
	await process_frame
	print("太阳轮转验收：%s（%s）" % ["通过" if _failures == 0 else "%d 项失败" % _failures,
		"编辑器" if Engine.is_editor_hint() else "运行时"])
	quit(0 if _failures == 0 else 1)
