# PlayGround

Godot 4.7 项目。运行入口为 `scenes/主菜单.tscn`；游戏场景为 `scenes/根节点.tscn`。

## 当前项目结构

| 目录 | 用途 |
| --- | --- |
| `scenes/` | 主菜单、游戏入口，以及 world / player / ui 场景 |
| `scripts/` | core 会话与主场景逻辑、world 环境、player 控制、ui 界面 |
| `shaders/` | terrain 地形、water 海面与水下、sky 天空、ui 小地图着色器 |
| `materials/` | 地形共享材质、晴空资源 |
| `assets/models/` | 游戏使用的 `超大地形.glb` |
| `assets/ui/` | 图标和小地图玩家箭头 |
| `source_art/terrain/` | 当前可编辑的 `超大地形.blend`；由 `.gdignore` 排除自动导入 |
| `tests/` | 功能、联机、地形碰撞、水面及天空验收 |

场景关系：`根节点 → 世界场景 → 地图 → 超大地形`。地图直接承载 GLB，统一绑定地形材质。当前场景没有树林、草地或旧 VoxelGI 烘焙节点；天空、日月光照和海面效果仍由环境脚本管理。

## 地形与美术源文件

地形覆盖 8 × 8 公里，划分为 64 个 1 公里块。原有巨构、塔与碎石集中在中央局部区域，外围保持裸地形。Blender Z=15 对应 Godot Y=15，真实海面与小地图海面均为 8200 × 8200 米；地形材质的海拔参数跟随真实海面高度。

Blender 对象、分组和材质采用中文名称。网格的 `-col` 后缀生成静态碰撞，参考对象与预览辅助的 `-noimp` 后缀排除导入，地形材质使用 `-vcol`。导出 GLB 时保留这些名称，并开启 Godot 导入选项中的名称后缀解析。GLB 只包含模型；运行时地表外观由 `materials/地形海拔材质.tres` 和 `shaders/terrain/地形海拔.gdshader` 控制。

编辑 `source_art/terrain/超大地形.blend` 后，将当前场景导出为 GLB，覆盖 `assets/models/超大地形.glb`。Blender 源文件已解除旧地图库的依赖。

## 验证

将命令中的 `Godot` 替换为本机 Godot 控制台可执行文件路径：

```powershell
Godot --headless --editor --path . --import
Godot --headless --path . --script res://tests/大地形验收.gd
Godot --headless --path . --script res://tests/水面验收.gd
Godot --headless --path . --script res://tests/天空光照验收.gd
./tests/run-tests.ps1 -Godot 'Godot控制台可执行文件路径'
```

地形截图验收使用图形模式：`Godot --path . --script res://tests/大地形验收.gd -- --render`。截图与日志写入 `.godot/`，不作为项目美术资源管理。
