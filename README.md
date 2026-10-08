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

第三人称使用 `WASD` 移动、`Space` 跳跃，按住 `Shift` 奔跑。行走速度默认为 6 米/秒，奔跑为 12 米/秒，可在玩家节点的 `Move Speed` / `Run Speed` 调整。模型在 `Idle`、`walk`、`run` 间平滑切换；空中上升播放 `jump`，下降（包括离开平台）循环播放 `falling`，落地恢复对应的地面动画。按 `Q` 切换空手/持剑，待机、行走、奔跑、跳跃和下落会立即切换到对应的 `*-with-sword` 动画；持剑版待机、行走、奔跑和下落循环播放，跳跃播放一次。剑的显示跟随装备状态，空手下落时也会隐藏。联机同步持剑、奔跑、接地状态和竖直速度；聊天或菜单打开时停止接收移动、奔跑、跳跃和持剑切换输入。自由相机中切换持剑会保留角色的静止状态。

奔跑验收：`Godot --headless --path . --script res://tests/玩家奔跑验收.gd` 验证左右 Shift、行走/奔跑速度、斜向移动、动画切换、输入阻塞、自由相机和远程奔跑状态。

持剑验收：`Godot --headless --path . --script res://tests/玩家持剑验收.gd` 验证 Q 键、长按去重、全部动作的持剑切换、循环、剑可见性、输入阻塞、自由相机和远程状态。

跳跃验收：`Godot --headless --path . --script res://tests/玩家跳跃验收.gd` 验证起跳、下降、走出平台、落地恢复、输入阻塞、自由相机和远程空中动画。

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

当前地图显示 `超大地形v2`。`地形场景.gd` 关闭隐藏旧地图的碰撞，并对肋柱、道路的三角网格开启双面碰撞，防止镜像缩放或背向表面造成玩家穿入。其他模型继续使用导入碰撞配置。碰撞验收使用实际玩家胶囊，覆盖 32 根肋柱、道路上下表面、地形与塔，并验证连续贴墙移动、道路落地和跳跃：`Godot --headless --path . --script res://tests/地图碰撞验收.gd`。

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

## 第二版路网

第二版地图的无桥基线路网保存为 `超大地形v2_路网.glb`（当前带桥版本见下节）：约 15.8 公里砂石路，主环线宽 12 米，北部半岛、南端和塔群支路宽 7–8 米。道路横截面保持等高，纵向平滑并限制坡度不超过 12%，路口为平整平台。路面下方地形随之削坡、填方，外侧以缓坡接回原地形。路线避开海水、塔群、肋柱及已放置的树石。道路带静态双面碰撞，并显示在主视图和小地图。

可编辑的完整场景保存为 `source_art/terrain/超大地形v2_路网.blend`，其中「路网」集合包含道路和隐藏的中心线参考。原 v2 源文件和模型保留。游戏由原 v2 模型叠加独立路网 GLB；其中「地形_整平」替换原「地形」的显示与碰撞。后续需将「路网」集合中的道路及「地形_整平」一起导出到 `assets/models/超大地形v2_路网.glb`，原地形作为隐藏的「地形_路网原始-noimp」保留在 Blender 中，不导出。

`tools/build_v2_roads.py` 在原 v2 Blender 场景中生成路网；若已存在「路网」集合则停止，避免重复叠加。路线数据和 Godot 坐标采样保存在 `source_art/terrain/路网数据.json`。运行 `Godot --headless --path . --script res://tests/路网验收.gd` 验证导入、碰撞、海拔、贴地、玩家落地及跳跃。

平整处理：在带路网的 Blender 场景中运行 `tools/grade_v2_roads.py`。脚本保留路线的整体走向，放缓局部过紧弯道，统一路口高程、平滑纵坡、生成横向等高路面，并只在道路周围细分地形后削坡填方。再次执行时始终从保留的原地形计算，避免反复修改累积误差。路网验收同时检查左右高差和已替换地形的碰撞。

在 Blender 中执行 `tools/validate_graded_roads.py` 可检查全部道路横截面的等高、纵坡上限及路口平整度。

## 两岛跨海桥

当前地图挂载 `超大地形v2_路网桥梁.glb`，从主岛东侧环路跨向东南侧大岛。桥身长 820 米，含引道总长约 1.47 公里，车行路面宽 12 米；桥面海拔 45 米，距海面 30 米。桥面横向等高，两端引道最大纵坡约 7.31%，桥头地形同步整平。桥梁带桥墩、基础、纵梁、桥台、连续护栏与副岛落地点，主视图和小地图均可见。

完整可编辑源文件是 `source_art/terrain/超大地形v2_路网桥梁.blend`，「跨海桥」集合保存结构和隐藏中心线。「路网」与「跨海桥」两个集合的网格一起导出为 `assets/models/超大地形v2_路网桥梁.glb`，包含道路和桥头整平后的地形；原有无桥版本继续保留。

重建顺序：在无桥的 `超大地形v2_路网.blend` 中完成道路整平并保存，再运行 `tools/build_v2_bridge.py`。脚本保留无桥基线并另存带桥版本。不要在带桥版本直接重跑道路整平脚本，否则会覆盖桥头整地；应先修改无桥基线，再重建桥梁。桥位、跨度、高程和引道参数集中在桥梁脚本中，验收采样位于 `source_art/terrain/桥梁数据.json`。

`Godot --headless --path . --script res://tests/桥梁验收.gd` 检查桥面与引道碰撞、横向平整、原路接入、桥头贴地、实际玩家胶囊完整跨岛行走及护栏阻挡；`tests/路网验收.gd` 继续验证原有路网。
