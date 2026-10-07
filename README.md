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

GUI 左上角显示 FPS 和当前相机模式。`Tab` 切换第三人称与自由相机；自由相机使用鼠标转向、`WASD` 飞行、`Space` 上升、`Ctrl` 下降、`Shift` 加速，可穿过场景观察云和地形。进入时复制当前视角，角色留在原位，退出后恢复第三人称。聊天或菜单打开时不切换相机、不移动视角，小地图继续追踪角色。

相机验收：`Godot --headless --path . --script res://tests/自由相机验收.gd` 验证切换和输入阻塞；窗口模式加 `-- --render` 额外验证飞行、鼠标转向并保存 `.godot/camera-validation/free_camera.png`。

选中 `世界场景/世界环境`，在检查器的「天空 · 太阳自动轮转」中开启 `Sun Auto Rotate`。`Sun Rotation Speed` 按度/秒控制速度，负值反向、0 暂停；`Sun Rotation Axis` 可选择 X 昼夜循环或 Y 水平方位轮转。默认从日光当前角度开始，以 1 度/秒推进，6 分钟一圈。`Sun Rotation Editor Preview` 控制编辑器中是否推进；运行时仍遵循主开关和游戏暂停。关闭主开关时停留在当前角度，天空、云光照及海面继续跟随日光。

## 体积云

`世界场景/体积云` 接入 `E:\GodotProjects\volume-cloude` 的球壳体积云实现。支持 Perlin / Perlin-Worley 三维噪声、覆盖度与高度剖面、细节侵蚀、砧状云、风动画、Nubis 自阴影和散射、大气融合、光束，以及地形与海面的太阳云影。世界场景采用源项目当前保存的云形状参数，太阳与夜间环境补光跟随本项目的日月控制器。

选中该节点即可在检查器调节云量、高度、风速、步进预算、后处理和云影。`clouds_enabled` 关闭云及云影；`animation_enabled` 单独冻结云形状，游戏暂停也会冻结动画。云参数位于 `scripts/world/体积云.gd`，共用渲染代码位于 `shaders/clouds/` 和 `scripts/clouds/`，云图与三维噪声资源分别位于 `assets/clouds/` 和 `materials/clouds/`。

运行时使用 Forward+ 计算合成器，主视口保持项目原有分辨率。海面倒影有独立合成器，修正镜像摄像机位于海平面下时的星球遮挡。小地图使用空合成器覆盖世界后处理，并跳过云影采样。编辑器、关闭后处理或计算管线失败时使用同一密度与步进代码的基础云预览；基础预览没有计算光束。

体积云验收覆盖参数同步、暂停、昼夜、游戏替换水面材质、合成器释放和重新进入场景。GPU 模式额外验证四个计算通道、三维噪声、主视图和海面倒影的云开关差分，并保存白天、夜晚、海面与基础预览截图：

```powershell
Godot --headless --path . --script res://tests/体积云验收.gd
Godot --path . --script res://tests/体积云验收.gd -- --render
```

截图输出到 `.godot/cloud-validation/`。GPU 验收须使用窗口模式和 Forward+。云质量预算可通过 `march_steps`、`light_steps` 和 `ground_shadow_steps` 调节；当前预设沿用源项目的 96 次视线、16 次自阴影、12 次地面云影预算。

光束按 Nubis 的流程生成：太阳周围的宽高光乘云透射率，径向向外偏移后在四分之一分辨率模糊，最终作为远距离 Mie 入散射的遮罩。默认 `light_shaft_spread = 35` 度、`light_shaft_length = 0.94`、`light_shaft_offset = 0.12`、`light_shaft_samples = 64`；`light_shaft_strength` 控制合成强度，`atmosphere_mie_density` 控制气溶胶浓度。散射从 500 米后平滑启用，几何深度截断近景，云不透明度连续缩短空气段。云前的空气不再重复乘云透射率。

`post_debug_view` 的 `Light shafts` 显示径向模糊遮罩，`Shaft highlight` 显示偏移后的高光源，`Mie contribution` 显示实际散射贡献。固定视角验收会检查可见光束、80 米不透明物体的遮挡、背向太阳和夜间关闭，并输出白天及低太阳角度截图到 `.godot/shaft-validation/`：

```powershell
Godot --path . --script res://tests/光束验收.gd
```

低太阳角度、太阳周围有多处云隙时，长光束最明显。此效果仍使用屏幕空间遮罩，画面外的云遮挡无法重建；参考图的云形状、时间和色彩也会影响最终观感。

月光也参与云的方向散射、多重散射、银边、云内自阴影和 Mie 光束，主视图与海面倒影共享模型，基础预览支持月光直射。太阳在地平线上时月光直射严格为零，太阳从 0° 降到 -6° 时平滑开启，日出时淡出；月亮隐藏或位于地平线下也关闭。月光颜色和强度跟随 `世界环境` 的月亮设置，`体积云/Lighting` 下的 `Moon Lighting Enabled` 和 `Moon Light Multiplier` 可以单独控制云的月光。`Moon` 留空时跟随天空控制器的月光节点；`Moon direct light` 调试视图单独显示月光通道。日月自阴影查询使用同一个预算，白天不执行月光密度查询。

月光验收：`Godot --headless --path . --script res://tests/月光体积云验收.gd`；窗口模式加 `-- --render` 检查月光受光面、自阴影、白天关闭、倒影、月光束和基础预览，截图位于 `.godot/moon-validation/`。

## 地形与美术源文件

地形覆盖 8 × 8 公里，划分为 64 个 1 公里块。原有巨构、塔与碎石集中在中央局部区域，外围保持裸地形。Blender Z=15 对应 Godot Y=15；地形材质的海拔参数跟随真实海面高度。小地图海面为 8200 × 8200 米。

真实海面默认开启 `世界场景/水面/Infinite Ocean`：近处精细环形网格和远处外圈一起跟随当前相机，覆盖范围按相机视锥自动扩展到视距之外，越过地图边界仍可看到海面并进入水下。波浪按世界坐标计算，移动覆盖范围不改变波纹位置。网格数量固定，`Water Size` 为最小覆盖尺寸；关闭 `Infinite Ocean` 则恢复原有固定尺寸边界。此功能提供视觉上的无限海面，地图外没有新增地形或海床。

无限海面验收：`Godot --headless --path . --script res://tests/无限海面验收.gd`；窗口模式加 `-- --render` 检查地图外的实际海面覆盖，并保存越界、高空和水下截图到 `.godot/ocean-validation/`。

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
