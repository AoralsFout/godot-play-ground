## 管理体积云计算合成器的管线、纹理和渲染回调。
## 主线程提交资源快照，渲染线程执行云、光束与最终合成，并在退出时释放显卡资源。

extends CompositorEffect

signal failed(message: String)

const SOURCE = preload("res://scripts/clouds/cloud_postprocess_source.gd")
const PASS_BINDINGS = SOURCE.PASS_BINDINGS

var _mutex := Mutex.new()
var _fields: Array[Dictionary] = []
var _field_indices: Dictionary = {}
var _shader_sources: Array = []
var _numeric_values := PackedFloat32Array()
var _frame_textures: Array = []
var _rd: RenderingDevice
var _shaders: Array[RID] = []
var _pipelines: Array[RID] = []
var _owned_rids: Array[RID] = []
var _parameter_buffer := RID()
var _depth_sampler := RID()
var _linear_sampler := RID()
var _noise_sampler := RID()
var _fallback_2d := RID()
var _fallback_3d := RID()
var _compile_failed := false
# 仅基准启用；正常运行不分割计算列表、不读取时间戳。
var profiling_enabled := false
var _profile_frame := -1
var _profile_samples: Array[Dictionary] = []

func take_profile_samples() -> Array[Dictionary]:
	_mutex.lock()
	var samples := _profile_samples.duplicate()
	_profile_samples.clear()
	_mutex.unlock()
	return samples

func _collect_profile() -> void:
	var frame := _rd.get_captured_timestamps_frame()
	if frame == _profile_frame:
		return
	_profile_frame = frame
	var times: Dictionary = {}
	for index in range(_rd.get_captured_timestamps_count()):
		var name := _rd.get_captured_timestamp_name(index)
		if name.begins_with("nubis/"):
			times[name] = _rd.get_captured_timestamp_gpu_time(index)
	var sample: Dictionary = {}
	for index in range(4):
		var prefix := "nubis/%d/" % index
		if times.has(prefix + "begin") and times.has(prefix + "end"):
			sample[["raymarch", "shaft_seed", "shaft_blur", "composite"][index]] = (times[prefix + "end"] - times[prefix + "begin"]) / 1000000.0
	if not sample.is_empty():
		_mutex.lock()
		_profile_samples.append(sample)
		_mutex.unlock()

func _init() -> void:
	# 在场景渲染完成、MSAA resolve 之后合成；Godot 色调映射/输出在其后。
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_color = true
	access_resolved_depth = true

func prepare(material: ShaderMaterial) -> void:
	var built := SOURCE.build()
	_fields.assign(built.fields)
	_shader_sources = built.shaders
	_numeric_values.resize(_fields.size() * 4)
	for index in range(_fields.size()):
		_field_indices[_fields[index].name] = index
	sync_material(material)

# 主线程只传值/资源快照；渲染回调不访问场景节点或 ShaderMaterial。
func sync_material(material: ShaderMaterial) -> void:
	var values := PackedFloat32Array()
	for field in _fields:
		var value: Variant = material.get_shader_parameter(field.name)
		var packed := _pack_value(field.default if value == null else value, field.linear)
		values.append_array(PackedFloat32Array([packed.x, packed.y, packed.z, packed.w]))
	var textures: Array = [material.get_shader_parameter("cloud_map"), material.get_shader_parameter("perlin_texture"), material.get_shader_parameter("worley_texture")]
	_mutex.lock()
	_numeric_values = values
	_frame_textures = textures
	_mutex.unlock()

func update_parameters(values: Dictionary) -> void:
	_mutex.lock()
	for name in values:
		if not _field_indices.has(name):
			continue
		var index: int = _field_indices[name]
		var packed := _pack_value(values[name], _fields[index].linear)
		for channel in range(4):
			_numeric_values[index * 4 + channel] = packed[channel]
	_mutex.unlock()

static func _pack_value(value: Variant, linear_color: bool) -> Vector4:
	if value is Color:
		var color: Color = value.srgb_to_linear() if linear_color else value
		return Vector4(color.r, color.g, color.b, color.a)
	if value is Vector4: return value
	if value is Vector3: return Vector4(value.x, value.y, value.z, 0.0)
	if value is Vector2: return Vector4(value.x, value.y, 0.0, 0.0)
	return Vector4(float(value), 0.0, 0.0, 0.0)

func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT or _compile_failed or _fields.is_empty():
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	var scene_data := render_data.get_render_scene_data()
	if buffers == null or scene_data == null:
		return
	var size := buffers.get_internal_size()
	if size.x <= 0 or size.y <= 0:
		return
	if _rd == null:
		_rd = RenderingServer.get_rendering_device()
	if _rd == null or not _prepare_gpu():
		return
	if profiling_enabled:
		_collect_profile()
	_mutex.lock()
	var parameters := _numeric_values.duplicate()
	# 保留引用，保证对应的纹理在本帧提交完毕前仍存活。
	var textures := _frame_textures.duplicate()
	_mutex.unlock()
	var usage := RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	var shaft_size := Vector2i(maxi(1, ceili(size.x / 4.0)), maxi(1, ceili(size.y / 4.0)))
	# RenderSceneBuffers 负责随分辨率/视图变化清理这些纹理。
	buffers.create_texture("nubis_post", "cloud", RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage, RenderingDevice.TEXTURE_SAMPLES_1, size, buffers.get_view_count(), 1, false, false)
	buffers.create_texture("nubis_post", "depth", RenderingDevice.DATA_FORMAT_R32_SFLOAT, usage, RenderingDevice.TEXTURE_SAMPLES_1, size, buffers.get_view_count(), 1, false, false)
	buffers.create_texture("nubis_post", "moon", RenderingDevice.DATA_FORMAT_R16_SFLOAT, usage, RenderingDevice.TEXTURE_SAMPLES_1, size, buffers.get_view_count(), 1, false, false)
	buffers.create_texture("nubis_post", "seed", RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage, RenderingDevice.TEXTURE_SAMPLES_1, shaft_size, buffers.get_view_count(), 1, false, false)
	buffers.create_texture("nubis_post", "blur", RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT, usage, RenderingDevice.TEXTURE_SAMPLES_1, shaft_size, buffers.get_view_count(), 1, false, false)
	var map_rid := _texture_rid(textures[0], _fallback_2d)
	var perlin_rid := _texture_rid(textures[1], _fallback_3d)
	var worley_rid := _texture_rid(textures[2], _fallback_3d)
	for view in range(buffers.get_view_count()):
		var frame_parameters := parameters.duplicate()
		var projection := scene_data.get_view_projection(view)
		var transform := scene_data.get_cam_transform()
		transform.origin += transform.basis * scene_data.get_view_eye_offset(view)
		_append_projection(frame_parameters, projection)
		_append_projection(frame_parameters, projection.inverse())
		_append_projection(frame_parameters, Projection(transform))
		var bytes := frame_parameters.to_byte_array()
		_rd.buffer_update(_parameter_buffer, 0, bytes.size(), bytes)
		var cloud := buffers.get_texture_slice("nubis_post", "cloud", view, 0, 1, 1)
		var depth := buffers.get_texture_slice("nubis_post", "depth", view, 0, 1, 1)
		var seed := buffers.get_texture_slice("nubis_post", "seed", view, 0, 1, 1)
		var blur := buffers.get_texture_slice("nubis_post", "blur", view, 0, 1, 1)
		var moon := buffers.get_texture_slice("nubis_post", "moon", view, 0, 1, 1)
		var uniforms: Array[RDUniform] = [
			_image_uniform(0, buffers.get_color_layer(view)),
			_sampler_uniform(1, _depth_sampler, buffers.get_depth_layer(view)),
			_image_uniform(2, cloud), _image_uniform(3, depth),
			_sampler_uniform(4, _linear_sampler, map_rid),
			_sampler_uniform(5, _noise_sampler, perlin_rid),
			_sampler_uniform(6, _noise_sampler, worley_rid),
			_buffer_uniform(7, _parameter_buffer), _image_uniform(8, seed),
			_sampler_uniform(9, _linear_sampler, seed), _image_uniform(10, blur),
			_sampler_uniform(11, _linear_sampler, blur),
			_image_uniform(12, moon),
		]
		var compute_list := -1 if profiling_enabled else _rd.compute_list_begin()
		for pass_index in range(4):
			if profiling_enabled:
				_rd.capture_timestamp("nubis/%d/begin" % pass_index)
				compute_list = _rd.compute_list_begin()
			var pass_uniforms: Array[RDUniform] = []
			for binding in PASS_BINDINGS[pass_index]:
				pass_uniforms.append(uniforms[binding])
			var uniform_set := UniformSetCacheRD.get_cache(_shaders[pass_index], 0, pass_uniforms)
			_rd.compute_list_bind_compute_pipeline(compute_list, _pipelines[pass_index])
			_rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
			var dispatch_size := shaft_size if pass_index == 1 or pass_index == 2 else size
			_rd.compute_list_dispatch(compute_list, ceili(dispatch_size.x / 8.0), ceili(dispatch_size.y / 8.0), 1)
			if profiling_enabled:
				_rd.compute_list_end()
				_rd.capture_timestamp("nubis/%d/end" % pass_index)
			elif pass_index < 3:
				_rd.compute_list_add_barrier(compute_list)
		if not profiling_enabled:
			_rd.compute_list_end()

func _prepare_gpu() -> bool:
	if not _pipelines.is_empty():
		return true
	for code in _shader_sources:
		var source := RDShaderSource.new()
		source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
		source.source_compute = code
		var spirv := _rd.shader_compile_spirv_from_source(source)
		if not spirv.compile_error_compute.is_empty():
			_compile_failed = true
			_report_failure.call_deferred("云后处理着色器编译失败：" + spirv.compile_error_compute)
			return false
		var shader := _rd.shader_create_from_spirv(spirv)
		if not shader.is_valid():
			_compile_failed = true
			_report_failure.call_deferred("无法创建云后处理着色器。")
			return false
		_owned_rids.append(shader) # 管线与 uniform set 随 shader 自动释放。
		var pipeline := _rd.compute_pipeline_create(shader)
		if not pipeline.is_valid():
			_compile_failed = true
			_report_failure.call_deferred("无法创建云后处理计算管线。")
			return false
		_shaders.append(shader)
		_pipelines.append(pipeline)
	_parameter_buffer = _rd.storage_buffer_create((_fields.size() + 12) * 16)
	_owned_rids.append(_parameter_buffer)
	_depth_sampler = _make_sampler(false, false)
	_linear_sampler = _make_sampler(true, false)
	_noise_sampler = _make_sampler(true, true)
	_fallback_2d = _make_fallback(false)
	_fallback_3d = _make_fallback(true)
	return true

func _make_sampler(linear: bool, repeat: bool) -> RID:
	var state := RDSamplerState.new()
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR if linear else RenderingDevice.SAMPLER_FILTER_NEAREST
	state.mag_filter = state.min_filter
	state.mip_filter = state.min_filter
	state.max_lod = 16.0
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT if repeat else RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	state.repeat_v = state.repeat_u
	state.repeat_w = state.repeat_u
	var sampler := _rd.sampler_create(state)
	_owned_rids.append(sampler)
	return sampler

func _make_fallback(volume: bool) -> RID:
	var format := RDTextureFormat.new()
	format.texture_type = RenderingDevice.TEXTURE_TYPE_3D if volume else RenderingDevice.TEXTURE_TYPE_2D
	format.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	format.width = 1
	format.height = 1
	format.depth = 1
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
	var texture := _rd.texture_create(format, RDTextureView.new(), [PackedByteArray([0])])
	_owned_rids.append(texture)
	return texture

static func _texture_rid(texture: Variant, fallback: RID) -> RID:
	if texture == null:
		return fallback
	var rid := RenderingServer.texture_get_rd_texture(texture.get_rid())
	return rid if rid.is_valid() else fallback

static func _append_projection(values: PackedFloat32Array, matrix: Projection) -> void:
	for column in [matrix.x, matrix.y, matrix.z, matrix.w]:
		values.append_array(PackedFloat32Array([column.x, column.y, column.z, column.w]))

static func _image_uniform(binding: int, rid: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = binding
	uniform.add_id(rid)
	return uniform

static func _sampler_uniform(binding: int, sampler: RID, texture: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.binding = binding
	uniform.add_id(sampler)
	uniform.add_id(texture)
	return uniform

static func _buffer_uniform(binding: int, rid: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = binding
	uniform.add_id(rid)
	return uniform

func _report_failure(message: String) -> void:
	enabled = false
	push_error(message)
	failed.emit(message)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd != null:
		var device := _rd
		var rids := _owned_rids.duplicate()
		# 不捕获正在析构的资源；释放也在渲染线程执行。
		RenderingServer.call_on_render_thread(func() -> void:
			for rid in rids:
				if rid.is_valid():
					device.free_rid(rid)
		)
