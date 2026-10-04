extends RefCounted
## 使用与草地分布.gdshaderinc 相同的世界空间噪声，使地面颜色与草叶分布一致。

static func cell_hash(cell: Vector2i, noise_seed: int) -> float:
	var value := (cell.x * 374761393 + cell.y * 668265263 + noise_seed * 1274126177) & 0xffffffff
	value = ((value ^ (value >> 13)) * 1274126177) & 0xffffffff
	value = value ^ (value >> 16)
	return float(value & 65535) / 65535.0


static func noise_at(point: Vector2, noise_seed: int) -> float:
	var cell := Vector2i(floori(point.x), floori(point.y))
	var weight := point - Vector2(cell)
	weight = weight * weight * (Vector2.ONE * 3.0 - weight * 2.0)
	return lerpf(lerpf(cell_hash(cell, noise_seed), cell_hash(cell + Vector2i(1, 0), noise_seed), weight.x),
		lerpf(cell_hash(cell + Vector2i(0, 1), noise_seed), cell_hash(cell + Vector2i(1, 1), noise_seed), weight.x), weight.y)


static func density_at(world_xz: Vector2, noise_seed: int, patch_scale: float, coverage: float) -> float:
	var point := world_xz * patch_scale
	var value := noise_at(point, noise_seed) * 0.75 + noise_at(point * 2.17 + Vector2(31.7, -19.2), noise_seed) * 0.25
	return smoothstep(1.0 - coverage, 1.0 - coverage + 0.16, value)
