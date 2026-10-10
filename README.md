# PlayGround

Godot 4.7 项目。运行入口为 `scenes/ui/主菜单.tscn`；游戏场景为 `scenes/core/根节点.tscn`。

目录与注释约定见 [项目结构说明](docs/项目结构.md)。

## 当前项目结构

| 目录 | 用途 |
| --- | --- |
| `scenes/` | 按 core / world / player / enemies / ui 划分入口与预制场景 |
| `scripts/` | core 会话、world 环境、clouds 共用渲染、player 控制、combat 战斗与 ui 界面 |
| `shaders/` | terrain 地形、water 海面与水下、sky 天空、clouds 体积云、ui 小地图着色器 |
| `materials/` | 按 terrain / sky / clouds 划分地形材质、天空与云噪声 |
| `assets/models/` | 按 player / enemies / terrain 存放实际游戏模型 |
| `assets/ui/` | 图标和小地图玩家箭头 |
| `source_art/` | terrain / player / enemies / weapons 制作源文件；archive 为历史源文件，terrain/exports 为无桥中间导出；均排除自动导入 |
| `animations/` | player / enemies 的动画树资源 |
| `tests/` | 按 player / combat / world 划分现有功能与渲染验收 |
| `tools/terrain/` | Blender 道路生成、整平、桥梁重建与网格验收工具 |

场景关系：`根节点 → 世界场景 → 地图 → 超大地形v2 + 路网桥梁`。地图组合第二版基础模型与当前桥梁路网，统一绑定地形材质；已移除隐藏的第一版地形及其运行时 GLB。天空、日月光照和海面效果由环境脚本管理。

GUI 左上角显示玩家生命进度条，下方显示 FPS 和当前相机模式。`Tab` 切换第三人称与自由相机；自由相机使用鼠标转向、`WASD` 飞行、`Space` 上升、`Ctrl` 下降、`Shift` 加速，可穿过场景观察云和地形。进入时复制当前视角，角色留在原位，退出后恢复第三人称。聊天或菜单打开时不切换相机、不移动视角，小地图继续追踪角色。

第三人称使用 `WASD` 移动、`Space` 跳跃，按住 `Shift` 奔跑。行走速度默认为 6 米/秒，奔跑为 12 米/秒，可在玩家节点的 `Move Speed` / `Run Speed` 调整。模型由 AnimationTree 在 `Idle`、`walk`、`run` 间平滑切换；空中上升播放 `jump`，下降（包括离开平台）循环播放 `falling`，落地恢复对应的地面动画。按 `Q` 切换空手/持剑，待机、行走、奔跑、跳跃和下落会立即切换到对应的 `*-with-sword` 动画；持剑版待机、行走、奔跑和下落循环播放，跳跃播放一次。剑的显示跟随装备状态，空手下落时也会隐藏。联机同步持剑、奔跑、接地状态和竖直速度；聊天或菜单打开时停止接收移动、奔跑、跳跃和持剑切换输入。自由相机中切换持剑会保留角色的静止状态。

奔跑验收：`Godot --headless --path . --script res://tests/player/玩家奔跑验收.gd` 验证左右 Shift、行走/奔跑速度、斜向移动、动画切换、输入阻塞、自由相机和远程奔跑状态。

行走和待机时模型始终跟随第三人称相机的水平朝向，方向键只改变移动方向，按实际移动相对模型的方向混合前进、后退、左移和右移；斜向行走混合相邻两个动作。空手及持剑均使用四方向动作，相机俯仰不影响模型的水平转向，非奔跑的空中阶段也保持相机朝向。奔跑仍按原逻辑朝移动方向平滑转身，结束奔跑后行走恢复相机朝向；战斗继续使用瞄准及挥剑锁定的攻击方向，自由相机仍冻结角色。联机额外同步模型朝向，避免远程侧移或后退被显示成前进。

四向行走验收：`Godot --headless --path . --script res://tests/player/玩家四向行走验收.gd` 检查空手及持剑的八个移动方向、行走与待机跟随相机朝向、模型正前方校正、实际腿骨姿态和斜向混合、奔跑转向及远程朝向；报告保存到 `.godot/walk-validation/report.json`。

持剑验收：`Godot --headless --path . --script res://tests/player/玩家持剑验收.gd` 验证 Q 键、长按去重、全部动作的持剑切换、循环、剑可见性、输入阻塞、自由相机和远程状态。

跳跃验收：`Godot --headless --path . --script res://tests/player/玩家跳跃验收.gd` 验证起跳、下降、走出平台、落地恢复、输入阻塞、自由相机和远程空中动画。

相机验收：`Godot --headless --path . --script res://tests/player/自由相机验收.gd` 验证切换和输入阻塞；窗口模式加 `-- --render` 额外验证飞行、鼠标转向并保存 `.godot/camera-validation/free_camera.png`。

选中 `世界场景/世界环境`，在检查器的「天空 · 太阳自动轮转」中开启 `Sun Auto Rotate`。`Sun Rotation Speed` 按度/秒控制速度，负值反向、0 暂停；`Sun Rotation Axis` 可选择 X 昼夜循环或 Y 水平方位轮转。默认从日光当前角度开始，以 1 度/秒推进，6 分钟一圈。`Sun Rotation Editor Preview` 控制编辑器中是否推进；运行时仍遵循主开关和游戏暂停。关闭主开关时停留在当前角度，天空、云光照及海面继续跟随日光。

## 体积云

`世界场景/体积云` 接入 `E:\GodotProjects\volume-cloude` 的球壳体积云实现。支持 Perlin / Perlin-Worley 三维噪声、覆盖度与高度剖面、细节侵蚀、砧状云、风动画、Nubis 自阴影和散射、大气融合、光束，以及地形与海面的太阳云影。世界场景采用源项目当前保存的云形状参数，太阳与夜间环境补光跟随本项目的日月控制器。

选中该节点即可在检查器调节云量、高度、风速、步进预算、后处理和云影。`clouds_enabled` 关闭云及云影；`animation_enabled` 单独冻结云形状，游戏暂停也会冻结动画。云参数位于 `scripts/world/体积云.gd`，共用渲染代码位于 `shaders/clouds/` 和 `scripts/clouds/`，云图与三维噪声资源分别位于 `assets/clouds/` 和 `materials/clouds/`。

运行时使用 Forward+ 计算合成器，主视口保持项目原有分辨率。海面倒影有独立合成器，修正镜像摄像机位于海平面下时的星球遮挡。小地图使用空合成器覆盖世界后处理，并跳过云影采样。编辑器、关闭后处理或计算管线失败时使用同一密度与步进代码的基础云预览；基础预览没有计算光束。

体积云验收覆盖参数同步、暂停、昼夜、游戏替换水面材质、合成器释放和重新进入场景。GPU 模式额外验证四个计算通道、三维噪声、主视图和海面倒影的云开关差分，并保存白天、夜晚、海面与基础预览截图：

```powershell
Godot --headless --path . --script res://tests/world/体积云验收.gd
Godot --path . --script res://tests/world/体积云验收.gd -- --render
```

截图输出到 `.godot/cloud-validation/`。GPU 验收须使用窗口模式和 Forward+。云质量预算可通过 `march_steps`、`light_steps` 和 `ground_shadow_steps` 调节；当前预设沿用源项目的 96 次视线、16 次自阴影、12 次地面云影预算。

光束按 Nubis 的流程生成：太阳周围的宽高光乘云透射率，径向向外偏移后在四分之一分辨率模糊，最终作为远距离 Mie 入散射的遮罩。默认 `light_shaft_spread = 35` 度、`light_shaft_length = 0.94`、`light_shaft_offset = 0.12`、`light_shaft_samples = 64`；`light_shaft_strength` 控制合成强度，`atmosphere_mie_density` 控制气溶胶浓度。散射从 500 米后平滑启用，几何深度截断近景，云不透明度连续缩短空气段。云前的空气不再重复乘云透射率。

`post_debug_view` 的 `Light shafts` 显示径向模糊遮罩，`Shaft highlight` 显示偏移后的高光源，`Mie contribution` 显示实际散射贡献。固定视角验收会检查可见光束、80 米不透明物体的遮挡、背向太阳和夜间关闭，并输出白天及低太阳角度截图到 `.godot/shaft-validation/`：

```powershell
Godot --path . --script res://tests/world/光束验收.gd
```

低太阳角度、太阳周围有多处云隙时，长光束最明显。此效果仍使用屏幕空间遮罩，画面外的云遮挡无法重建；参考图的云形状、时间和色彩也会影响最终观感。

月光也参与云的方向散射、多重散射、银边、云内自阴影和 Mie 光束，主视图与海面倒影共享模型，基础预览支持月光直射。太阳在地平线上时月光直射严格为零，太阳从 0° 降到 -6° 时平滑开启，日出时淡出；月亮隐藏或位于地平线下也关闭。月光颜色和强度跟随 `世界环境` 的月亮设置，`体积云/Lighting` 下的 `Moon Lighting Enabled` 和 `Moon Light Multiplier` 可以单独控制云的月光。`Moon` 留空时跟随天空控制器的月光节点；`Moon direct light` 调试视图单独显示月光通道。日月自阴影查询使用同一个预算，白天不执行月光密度查询。

月光验收：`Godot --headless --path . --script res://tests/world/月光体积云验收.gd`；窗口模式加 `-- --render` 检查月光受光面、自阴影、白天关闭、倒影、月光束和基础预览，截图位于 `.godot/moon-validation/`。

## 地形与美术源文件

当前地图显示 `超大地形v2`。`地形场景.gd` 关闭被整平路网替换的原地表，并对肋柱、道路和桥梁的三角网格开启双面碰撞，防止镜像缩放或背向表面造成玩家穿入。其他模型继续使用导入碰撞配置。碰撞验收使用实际玩家胶囊，覆盖 32 根肋柱、道路上下表面、地形与塔，并验证连续贴墙移动、道路落地和跳跃：`Godot --headless --path . --script res://tests/world/地图碰撞验收.gd`。

地形覆盖 8 × 8 公里，划分为 64 个 1 公里块。原有巨构、塔与碎石集中在中央局部区域，外围保持裸地形。Blender Z=15 对应 Godot Y=15；地形材质的海拔参数跟随真实海面高度。小地图海面为 8200 × 8200 米。

真实海面默认开启 `世界场景/水面/Infinite Ocean`：近处精细环形网格和远处外圈一起跟随当前相机，覆盖范围按相机视锥自动扩展到视距之外，越过地图边界仍可看到海面并进入水下。波浪按世界坐标计算，移动覆盖范围不改变波纹位置。网格数量固定，`Water Size` 为最小覆盖尺寸；关闭 `Infinite Ocean` 则恢复原有固定尺寸边界。此功能提供视觉上的无限海面，地图外没有新增地形或海床。

无限海面验收：`Godot --headless --path . --script res://tests/world/无限海面验收.gd`；窗口模式加 `-- --render` 检查地图外的实际海面覆盖，并保存越界、高空和水下截图到 `.godot/ocean-validation/`。

Blender 对象、分组和材质采用中文名称。网格的 `-col` 后缀生成静态碰撞，参考对象与预览辅助的 `-noimp` 后缀排除导入，地形材质使用 `-vcol`。导出 GLB 时保留这些名称，并开启 Godot 导入选项中的名称后缀解析。GLB 只包含模型；运行时地表外观由 `materials/terrain/地形海拔材质.tres` 和 `shaders/terrain/地形海拔.gdshader` 控制。

当前基础模型由 `source_art/terrain/超大地形v2.blend` 导出为 `assets/models/terrain/超大地形v2.glb`；路网与桥梁制作流程见下文。第一版源文件保存在 `source_art/archive/terrain/`，不参与游戏导入。

## 验证

将命令中的 `Godot` 替换为本机 Godot 控制台可执行文件路径：

```powershell
Godot --headless --editor --path . --import
```

地形和路网验收：`Godot --headless --path . --script res://tests/world/地图碰撞验收.gd`、`Godot --headless --path . --script res://tests/world/路网验收.gd`。截图与日志写入 `.godot/`，不作为项目美术资源管理。

## 第二版路网

第二版地图的无桥基线路网保存为 `source_art/terrain/exports/超大地形v2_路网.glb`，作为制作中间导出排除游戏导入（当前带桥版本见下节）：约 15.8 公里砂石路，主环线宽 12 米，北部半岛、南端和塔群支路宽 7–8 米。道路横截面保持等高，纵向平滑并限制坡度不超过 12%，路口为平整平台。路面下方地形随之削坡、填方，外侧以缓坡接回原地形。路线避开海水、塔群、肋柱及已放置的树石。道路带静态双面碰撞，并显示在主视图和小地图。

可编辑的完整场景保存为 `source_art/terrain/超大地形v2_路网.blend`，其中「路网」集合包含道路和隐藏的中心线参考。原 v2 源文件和模型保留。当前游戏由原 v2 模型叠加带桥路网 GLB；其中「地形_整平」替换原「地形」的显示与碰撞。后续需将「路网」集合中的道路及「地形_整平」一起导出到 `source_art/terrain/exports/超大地形v2_路网.glb`，原地形作为隐藏的「地形_路网原始-noimp」保留在 Blender 中，不导出。

`tools/terrain/build_v2_roads.py` 在原 v2 Blender 场景中生成路网；若已存在「路网」集合则停止，避免重复叠加。路线数据和 Godot 坐标采样保存在 `source_art/terrain/路网数据.json`。运行 `Godot --headless --path . --script res://tests/world/路网验收.gd` 验证导入、碰撞、海拔、贴地、玩家落地及跳跃。

平整处理：在带路网的 Blender 场景中运行 `tools/terrain/grade_v2_roads.py`。脚本保留路线的整体走向，放缓局部过紧弯道，统一路口高程、平滑纵坡、生成横向等高路面，并只在道路周围细分地形后削坡填方。再次执行时始终从保留的原地形计算，避免反复修改累积误差。路网验收同时检查左右高差和已替换地形的碰撞。

在 Blender 中执行 `tools/terrain/validate_graded_roads.py` 可检查全部道路横截面的等高、纵坡上限及路口平整度。

## 两岛跨海桥

当前地图挂载 `超大地形v2_路网桥梁.glb`，从主岛东侧环路跨向东南侧大岛。桥身长 820 米，含引道总长约 1.47 公里，车行路面宽 12 米；桥面海拔 45 米，距海面 30 米。桥面横向等高，两端引道最大纵坡约 7.31%，桥头地形同步整平。桥梁带桥墩、基础、纵梁、桥台、连续护栏与副岛落地点，主视图和小地图均可见。

完整可编辑源文件是 `source_art/terrain/超大地形v2_路网桥梁.blend`，「跨海桥」集合保存结构和隐藏中心线。「路网」与「跨海桥」两个集合的网格一起导出为 `assets/models/terrain/超大地形v2_路网桥梁.glb`，包含道路和桥头整平后的地形；无桥版本保存在制作源文件及中间导出目录中。

重建顺序：在无桥的 `超大地形v2_路网.blend` 中完成道路整平并保存，再运行 `tools/terrain/build_v2_bridge.py`。脚本保留无桥基线并另存带桥版本。不要在带桥版本直接重跑道路整平脚本，否则会覆盖桥头整地；应先修改无桥基线，再重建桥梁。桥位、跨度、高程和引道参数集中在桥梁脚本中，验收采样位于 `source_art/terrain/桥梁数据.json`。

`Godot --headless --path . --script res://tests/world/桥梁验收.gd` 检查桥面与引道碰撞、横向平整、原路接入、桥头贴地、实际玩家胶囊完整跨岛行走及护栏阻挡；`tests/world/路网验收.gd` 继续验证原有路网。


## 史莱姆对战

游戏入口场景在玩家出生点前方放置一只史莱姆，使用现有的 `assets/models/enemies/史莱姆.glb` 及移动、攻击、死亡动画。史莱姆在 24 米内追击，近身准备约 0.42 秒后扑击，命中扣 10 点生命，攻击后休息 0.85 秒。生命条始终位于头顶，受击短暂变红并打断扑击；死亡后保留 1.2 秒，再用 1.3 秒淡出并移除。

左键点按直接挥剑，采用半径 2.8 米、110° 的隐藏扇形，基础伤害为 20。按住超过 0.18 秒进入 `attack-ready` 准备动作，镜头平滑拉近并稍向肩侧偏移，显示半径 5 米、34° 的浅红扇形；区域贴地并跟随相机水平朝向。范围内的史莱姆轻微缓慢闪烁，移出范围立即取消提示。进入蓄力后 1.8 秒达到最大 70 点伤害，扇形颜色和透明度随蓄力加深；继续长按不会超过上限。

释放时由 AnimationTree 的上半身战斗层播放 `attack-1`，在动画第 0.30 秒的落剑方法轨道结算一次伤害。使用那一刻的敌人位置和释放时锁定的攻击方向；目标离开、位于背后、高度差过大或被墙遮挡时不会命中。首次攻击自动持剑，蓄力及挥剑期间减速；Q 收剑、进入自由相机、聊天、暂停菜单或窗口失焦会取消攻击。玩家初始生命为 100，归零后暂时继续移动和攻击。

可在玩家场景的「战斗」节点调整生命、伤害、蓄力时间、范围和镜头参数；「model」节点的「战斗动画」分组可调整伤害关键帧时间。史莱姆行为参数位于敌人场景根节点。此版为本地对战流程，联机仍沿用原有的移动和装备同步。

对战验收：`Godot --path . res://tests/combat/对战流程验收.tscn`，通过真实左键事件、实际模型动画、地面碰撞及GUI验证点按/长按、延迟结算、伤害上限、选择、输入保护、追击、零血操作和死亡淡出；截图及结果保存到 `.godot/combat-validation/`。

史莱姆视觉反馈验收：`Godot --path . res://tests/combat/史莱姆视觉反馈验收.tscn`，加载实际模型及海面倒影裁剪，比较选中闪烁和受击变红的渲染像素，并检查恢复原色、扣血及裁剪关闭后的材质还原。结果与截图位于 `.godot/slime-feedback/`。

## AnimationTree 与战斗分层

玩家场景的 `model/AnimationTree` 使用 `animations/player/玩家动画树.tres`，史莱姆场景的 `AnimationTree` 使用 `animations/enemies/史莱姆动画树.tres`。AnimationPlayer 保留导入动画库，运行时播放和切换统一由 AnimationTree 驱动。可以在 Godot 编辑器中打开这两个资源查看图结构。

玩家根图将 `Locomotion` 移动状态机与 `Combat` 战斗状态机连接到 `UpperBody` 骨骼过滤混合节点。移动状态包括 Idle、Walk、Run、Jump、Falling；每个状态通过 Equipment 节点平滑混合空手与持剑动作。Walk / Run 的 Speed 节点按实际移动速度调整步频，蓄力和挥砍减速时腿部仍然迈步；移动停止后恢复待机。

Walk 的 Unarmed / Sword 节点分别使用 `AnimationNodeBlendSpace2D`，前、后、左、右采样对应 `walk`、`walk-back`、`walk-left`、`walk-right` 及各自的 `-with-sword` 动作。混合坐标 X 正值向右、Y 负值向前，以模型朝向和 Forward Yaw Offset 校正后的实际速度计算。采样同步推进并使用向前行走的统一周期，较长的后退源动作按时间轴缩放，保持方向及装备切换时的步态相位；循环在模型导入设置中保留。

战斗层播放 Charge → Hold，以及准备或保持状态 → Attack。Hold 在每个玩家初始化时从 `attack-ready` 末帧提取，长按不会重复抬剑，也不会暂停移动层。过滤范围按骨架层级从 `骨骼.001`（第一节脊柱）向下遍历，包含躯干、头和双臂，排除根部和双腿；战斗期间角色朝向仍跟随瞄准。可以在 model 的 Upper Body Root Bone 调整过滤起点，Combat Blend Time 调整战斗层淡入淡出，Blend Time 调整移动和装备姿势过渡。

`combat/hold` 和带命中、结束方法轨道的 `combat/strike` 由脚本为每个实例生成。树图和这些附加动画各自独立，避免本地、远程玩家互相改变状态。方法轨道也经过 UpperBody 过滤，并对命中去重、取消攻击进行检查；攻击结束淡出战斗层，恢复当时的移动状态。剑的 visible 只由装备状态控制，模型中的 with-sword 动作继续保留。史莱姆使用独立的待机、移动、攻击、死亡状态机，Speed 参数维持原有扑击速度；受击颜色、外观弹跳和死亡淡出仍由行为脚本控制。

分层验收加载两份实际玩家模型，逐帧比较全部腿骨姿态，验证准备 / 保持 / 挥砍期间的腿部运动、步频、空中状态、装备显隐、实例隔离和攻击事件，并检查史莱姆攻击与死亡。图形模式保存对比截图与报告到 `.godot/tree-validation/`：

```powershell
Godot --path . res://tests/combat/动画树分层验收.tscn
Godot --headless --path . res://tests/combat/动画树分层验收.tscn
```

奔跑、跳跃和持剑验收已改为检查 AnimationTree 的移动状态；对战验收额外通过真实移动输入检查蓄力时的腿部迈步和减速。原有联机仍同步移动和装备，战斗分层沿用本地战斗范围。
