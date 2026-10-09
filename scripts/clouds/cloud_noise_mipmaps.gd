## 生成带三维逐级缩小纹理的云噪声资源。
## 在三个方向平均采样，供体积云控制器上传噪声，避免远景细节闪烁。

@tool
extends RefCounted


static func build(source_slices: Array[Image]) -> ImageTexture3D:
	if source_slices.is_empty():
		return null
	var width := source_slices[0].get_width()
	var height := source_slices[0].get_height()
	var depth := source_slices.size()
	var level_slices: Array[Image] = []
	for source_slice in source_slices:
		var slice := source_slice.duplicate() as Image
		# 保留噪声红通道的数值；每张 Image 只存当前层，不带二维 mip。
		slice.clear_mipmaps()
		slice.convert(Image.FORMAT_R8)
		level_slices.append(slice)
	var all_slices: Array[Image] = []
	all_slices.append_array(level_slices)
	var level_width := width
	var level_height := height
	var level_depth := depth
	while level_width > 1 or level_height > 1 or level_depth > 1:
		var next_width := maxi(1, level_width >> 1)
		var next_height := maxi(1, level_height >> 1)
		var next_depth := maxi(1, level_depth >> 1)
		var resized_slices: Array[Image] = []
		for slice in level_slices:
			var resized := slice.duplicate() as Image
			# 当前 128³ 纹理每轴减半，bilinear 在 XY 上平均相邻 2×2 texel。
			resized.resize(next_width, next_height, Image.INTERPOLATE_BILINEAR)
			resized_slices.append(resized)
		var next_slices: Array[Image] = []
		for z in range(next_depth):
			var data_a := resized_slices[mini(z * 2, level_depth - 1)].get_data()
			var data_b := resized_slices[mini(z * 2 + 1, level_depth - 1)].get_data()
			var averaged := PackedByteArray()
			averaged.resize(next_width * next_height)
			for pixel in range(averaged.size()):
				averaged[pixel] = (int(data_a[pixel]) + int(data_b[pixel]) + 1) >> 1
			next_slices.append(Image.create_from_data(next_width, next_height, false, Image.FORMAT_R8, averaged))
		all_slices.append_array(next_slices)
		level_slices = next_slices
		level_width = next_width
		level_height = next_height
		level_depth = next_depth
	var texture := ImageTexture3D.new()
	# 三维 mip 数据按层级排列：128 张 128²、64 张 64²……最后 1 张 1²。
	var error := texture.create(Image.FORMAT_R8, width, height, depth, true, all_slices)
	if error != OK:
		push_error("Cloud noise mipmap creation failed: %s" % error_string(error))
		return null
	return texture
