# Nubis：用 Decima 引擎创作实时体积云景
## 中英对照全译（SIGGRAPH 2017 · Advances in Real-Time Rendering）

> 原文件：Nubis-Authoring-Realtime-Volumetric-Cloudscapes-with-the-Decima-Engine-Final.pdf
> 讲者：Andrew Schneider & Nathan Vos（Guerrilla Games）
> 共 108 页，含幻灯片正文与全部讲者注释。
> 页码按 PDF 页序编号（第 N 页 = PDF 第 N 页），与幻灯片页脚印刷编号可能相差 1。

---

## 第 1 页

**EN:**
Welcome to the slides!

**中:**
欢迎来看这些幻灯片！

## 第 2 页

> 幻灯片文字：卢克·霍华德的云研究，1802 年 / Cloud Study by Luke Howard, 1802

**EN:**
Clouds have fascinated us for millennia.

**中:**
千百年以来，云一直令我们着迷。

**EN:**
Renee Descartes said of them "We think of them as the throne of god. That makes me hope that if I can explain their nature, one will easily believe that it is possible to find the causes of everything wonderful about earth."

**中:**
勒内·笛卡尔（Renee Descartes）曾这样谈论云：「我们视它们为神的宝座。这让我希望，如果我能解释它们的本质，人们就会容易相信，我们有可能找到地球上一切奇妙之物的成因。」

**EN:**
For centuries, soothsayers and prophets applied this idea quite literally. Clouds and storms were used to foretell drought or political upheaval. But, all of this was done without a scientific understanding of the nature of clouds.

**中:**
数个世纪以来，占卜者和先知们都相当字面地套用这一想法。人们用云和风暴来预言干旱或政治动荡。但这一切都是在没有对云的本质形成科学理解的情况下进行的。

**EN:**
By as late as 1802 the sentiment was that clouds were just clouds and understanding or even classifying them seemed as unreachable as they were to observers from the ground. Think about that.

**中:**
直到 1802 年，人们的看法仍然是：云就是云，而理解它们、甚至给它们分类，对地面上的观察者来说，似乎和它们本身一样遥不可及。想想这一点。

## 第 3 页

> 幻灯片文字：走出黑暗 / Out Of Darkness
> 幻灯片文字：卢克·霍华德，气象学家，1802 年 / Luke Howard, Meteorologist, 1802
> 幻灯片文字：肖像 / 图片来自英国国家气象图书馆与档案馆档案 / Portrait / Art from the archive of the National Meteorological Library And Archive [UK]
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：[Hamblyn, 2001]

**EN:**
But one night in that year, a young man named Luke Howard gave a lecture called "On the modifications of clouds" In this lecture, he classified clouds by their altitude, basic physical characteristics and the conditions that gave rise to their development using latin nouns and adjectives.

**中:**
但就在那一年的某个夜晚，一位名叫卢克·霍华德（Luke Howard）的年轻人做了一场题为「论云的变体」（On the modifications of clouds）的讲座。在这场讲座中，他用拉丁语的名词和形容词，依据云的高度、基本物理特征，以及促成其发展的条件，对云进行了分类。

## 第 4 页

> 幻灯片文字：云 / The Clouds
> 幻灯片文字：卢克·霍华德绘制的图示 / Renderings by Luke Howard
> 幻灯片文字：积云 / 层云 / 卷云 / Cumulus / Stratus / Cirrus
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：[Hamblyn, 2001]

**EN:**
Here are some Renderings that Howard made to illustrate his points.

**中:**
这里是霍华德为说明他的观点而绘制的一些图示。

**EN:**
Howard dubbed the
• stacked round clouds Cumulus, which means a heap or pile in Latin.
• The Long flat clouds became Stratus, which means layer or sheet in latin.
• The wispy stretched clouds that exist high in the atmosphere became Cirrus, which means hair or fibre in latin.

**中:**
霍华德把下面这些云分别命名：
• 层层堆叠的圆形云为 Cumulus（积云），在拉丁语中意为「堆」或「堆积」。
• 长而平坦的云为 Stratus（层云），在拉丁语中意为「层」或「片」。
• 存在于大气高层、纤细伸展的云为 Cirrus（卷云），在拉丁语中意为「毛发」或「纤维」。

## 第 5 页

> 幻灯片文字：云 / The Clouds
> 幻灯片文字：卢克·霍华德绘制的图示 / Renderings by Luke Howard
> 幻灯片文字：8 km / 5 mi；4 km / 2.5 mi；1.5 km / .93 mi
> 幻灯片文字：高 / Alto；卷 / Cirro
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：[Hamblyn, 2001]

**EN:**
Howard noticed that clouds formed in clusters at different altitudes below 10km.

**中:**
霍华德注意到，云会在 10 公里以下的不同高度上成簇形成。

**EN:**
So altitude also became a classifying factor. (I converted these to miles for all of the Yankees like me in the room.)
• While clouds below 1.5km retained their names like Stratus and Cumulus…
• Clouds above 1.5km but below 4km in altitude earned the prefix "Alto" Giving us names like altocumulus and altostratus.
• Clouds above 4km, in the top of the cloud zone earned the prefix Cirro.

**中:**
于是高度也成了一个分类依据。（为了照顾在座像我这样的美国佬，我把这些数值都换算成了英里。）
• 1.5 公里以下的云保留各自的名称，如层云（Stratus）和积云（Cumulus）……
• 高度在 1.5 公里以上、4 公里以下的云获得了前缀「Alto（高）」，于是就有了 altocumulus（高积云）和 altostratus（高层云）这样的名称。
• 4 公里以上、位于云层区顶部的云获得了前缀「Cirro（卷）」。

**EN:**
Howard was the first to propose, with evidence, that clouds formed from water vapor that had condensed on dust particles in the atmosphere.  He referred to this process as 'Nubification' The phrase never really caught on..

**中:**
霍华德是第一个提出并有证据支持「云由大气中凝结在尘埃颗粒上的水蒸气形成」这一观点的人。他把这一过程称为「Nubification（成云作用）」。这个说法始终没能真正流行起来……

**EN:**
But for Luke Howard, the rest was history.

**中:**
但对卢克·霍华德而言，其余的一切都已载入史册。

**EN:**
His system persists to this day, and the reason is because it squares an ancient circle in a way that was intuitive and accessible to everyone.

**中:**
他的分类体系沿用至今，原因在于它以人人都能直观理解、也易于接受的方式，化解了一道古老的难题。

## 第 6 页

> 幻灯片文字：克劳德·约瑟夫·韦尔内绘，1772 年 / Painting by Claude Joseph Vernet, 1772
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：云渲染 / Cloud Rendering

**EN:**
Scientists were not the only people developing an understanding of clouds. Before the invention of the camera, landscape painters needed to develop a system for remembering what the constantly changing cloudscapes looked like in order to compose their paintings. Maybe they were the first to understand the underlying physics involved as far as it served their purposes of recreation. These techniques were handed down within the confines of the fine art community for centuries.

**中:**
科学家并不是唯一一群在发展对云的理解的人。在相机发明之前，风景画家需要建立一套方法来记住不断变化的云景是什么样子，以便构图作画。也许，就服务于他们再现的目的而言，他们才是最早理解其中底层物理原理的人。数个世纪以来，这些技法在纯艺术圈子里代代相传。

**EN:**
Within the last half century, the computer evolved into a medium where science and art catalyzed the development of a new discipline called computer graphics.

**中:**
在过去半个世纪里，计算机演变成了一种媒介；在这里，科学与艺术共同催生出一门新的学科——计算机图形学。

## 第 7 页

> 幻灯片文字：「计算机图形学可以为我们呈现想象的世界……但只要稍加思索地运用，它也能帮助我们揭开自然秘密的面纱」——P.H. Richter，1970
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：计算机图形学 / Computer Graphics

**EN:**
In his book, the Beauty of Fractals,  P.H. Richter said "Computer graphics can present us with imaginary worlds … But used with some reflection, it can also help us to lift the veil on natures secrets"

**中:**
在其著作《分形之美》（The Beauty of Fractals）中，P.H. Richter 说：「计算机图形学可以为我们呈现想象的世界……但只要稍加思索地加以运用，它也能帮助我们揭开自然秘密的面纱。」

**EN:**
Well, I think that As artists and developers, this is one of the most exciting frontiers that we get to explore in computer graphics.

**中:**
嗯，我认为，作为美术人员和开发者，这正是我们能在计算机图形学中探索的最激动人心的前沿之一。

**EN:**
Soon enough, early pioneers of computer art and science turned their attention to clouds..

**中:**
很快，计算机艺术与科学的早期先驱们就把注意力转向了云……

## 第 8 页

**EN:**
In 1990, Carl Ludwig, one of the pioneers of ray-tracing at Blue Sky Studios designed a program which rendered clouds using a ray-march and implicit surfaces constructed from noise. I bring this example up instead of the numerous film and vfx examples of cg clouds from this decade because what he did back in the 90's was elegant, physically accurate and convincingly real. This is actually the first time that this image has been shown outside of the circle of people who know Carl, so thanks for letting us use it today for educational reference, Carl.

**中:**
1990 年，Blue Sky Studios 的光线追踪先驱之一卡尔·路德维希（Carl Ludwig）设计了一个程序，用光线步进（ray marching）和由噪声构成的隐式曲面来渲染云。我举这个例子，而不是这十年里众多电影和视效中的 CG 云例子，是因为他在 90 年代所做的东西简洁、物理准确，而且真实得令人信服。实际上，这张图是第一次在认识卡尔的人的小圈子之外公开展示，所以，感谢你允许我们今天把它用作教学参考，卡尔。

**EN:**
Before the recent advances in hardware and theory, we didn't have the tools or the language required to render something like this in real-time.

**中:**
在硬件和理论取得近期进展之前，我们没有所需的工具或语言，来实时渲染像这样的东西。

## 第 9 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：云渲染 / Cloud Rendering
> 幻灯片文字：早期实时体积云 / Early Real-Time Volumetric Clouds
> 幻灯片文字：• TrueSky [Simul, 2013]
> 幻灯片文字：• Reset Engine [Reset, 2012]

**EN:**
Since then, processing power has improved and the pioneers working on
• True Sky and the The Reset Engine started developing methods for rendering volumetric clouds in real-time for use inactual games. These recent advances gave my co-developer Nathan Vos and I and the rest of the team at Guerrilla the courage to try this ourselves.

**中:**
自那以后，算力不断提升，而致力于以下这些工作的先驱者
• True Sky 和 The Reset Engine——开始开发用于实际游戏的实时体积云渲染方法。这些近期进展给了我的合作开发者 Nathan Vos 以及 Guerrilla 团队的其他成员勇气，去亲自尝试这件事。

## 第 10 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：云渲染 / Cloud Rendering
> 幻灯片文字：[游戏内渲染] in-game render, 2015

**EN:**
In 2014, we decided to develop our own approach to rendering clouds for use in our game Horizon: Zero Dawn and in our engine, Decima, which is being used by Kojima Productions. In 2015, we shared our prototype as part of this course and offered a high level overview of how we model, light and render our cloudscapes in under 2 milliseconds.  This prototype, while successful and able to run on its own using a procedural weather simulation, still lacked the level of reproducibility and control for modeling, animating and lighting that would be required to support a heavily art directed game like Horizon, where the goal was for nature to appear hyper-real in gameplay and cutscenes.

**中:**
2014 年，我们决定开发自己的云渲染方案，用于我们的游戏《地平线：零之曙光》以及我们的引擎 Decima（Kojima Productions 也在使用该引擎）。2015 年，我们在这个课程中分享了我们的原型，并从较高层面概述了我们如何在 2 毫秒以内对云景进行建模、光照和渲染。这个原型虽然成功，也能依靠程序化天气模拟自行运行，但在建模、动画和光照方面，仍缺乏支撑一款像《地平线》这样高度依赖美术指导的游戏所需要的可复现性与可控性——在那款游戏里，目标是让自然在游玩过程和过场动画中呈现出超写实的效果。

## 第 11 页

> 幻灯片文字：SIGGRAPH 2017: Advances in Real-Time Rendering | Andrew Schneider & Nathan Vos | Guerrilla Games
> 幻灯片文字：NUBIS
> 幻灯片文字：用 Decima 引擎创作实时体积云景 / Authoring Real-Time Volumetric Cloudscapes with the Decima Engine

**EN:**
Our solution to these challenges and to simulating the the important natural phenomena of clouds is what we are going to discuss today.

**中:**
我们今天要讨论的，就是我们对这些挑战的解决方案，以及对云这一重要自然现象的模拟。

**EN:**
Nubis is our approach to artistically authoring real-time volumetric cloudscapes for games. In addition to including an authoring component, we improved the performance beyond our 2 ms budget.

**中:**
Nubis 是我们在游戏中以艺术方式创作实时体积云景的方案。除了包含创作组件之外，我们还把性能提升到超出 2 毫秒预算的水平。

**EN:**
Nubis uses no assets, only sets of instructions from our authoring system that evoke behaviors that are defined by probability. This holds true across the entire system.

**中:**
Nubis 不使用任何资产，只使用来自我们创作系统的一组组指令，它们唤起由概率定义的行为。这一点在整个系统中都成立。

**EN:**
There are 5 main components: #

**中:**
它由 5 个主要组件构成：#

## 第 12 页

> 幻灯片图示：创作系统 / 云密度模型 / 云光照模型 / 光线步进 / 后处理 / Authoring System / Cloud Density Model / Cloud Lighting Model / Ray March / Post Process
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | 系统组件 / System Components

**EN:**
• The Authoring system, which defines where to draw clouds and what type of clouds to draw as well as transitions and detail characteristics;

**中:**
• 创作系统，它定义在哪里绘制云、绘制什么类型的云，以及过渡与细节特征；

**EN:**
• Then there is the density model, which generates the physical forms of our clouds including the wispy and billowy shapes as well as the deformations. #

**中:**
• 然后是密度模型，它生成云的物理形态，包括纤细的与翻涌的形状，以及形变。#

**EN:**
• Next is The Lighting model which simulates the scattering and absorption effects associated with clouds. The lighting and density models are both a part of the

**中:**
• 接下来是光照模型，它模拟与云相关的散射和吸收效应。光照模型和密度模型都属于

**EN:**
• ray-march operation which is used to render the density and lighting data in slices away from the camera in an optimized way

**中:**
• ray marching 运算的一部分，该运算以优化的方式在远离相机的切片中渲染密度和光照数据

**EN:**
• Finally there is the post process shader which integrates our cloudscapes into each frame

**中:**
• 最后是后处理着色器，它把我们的云景整合进每一帧

## 第 13 页

> 幻灯片图示：创作系统 / 云密度模型 / 云光照模型 / 光线步进 / 后处理 / Authoring System / Cloud Density Model / Cloud Lighting Model / Ray March / Post Process
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | 系统组件 / System Components

**EN:**
It is necessary to understand the fundamentals of how and on what basis we model a single cloud before we can explain how we build entire cloudscapes. So first, we are going to start with the density model. Our cloud modeling approach is inspired by Howards 'Nubification', but rather than jumping right into our implementation, lets first go on a brief thought experiment. To truly understand the physics involved in cloud formation we need to experience it up close.

**中:**
在解释我们如何构建整片云景之前，有必要先理解我们建模单朵云的方式与依据这些基本原理。所以首先，我们从密度模型讲起。我们的云建模方法受到霍华德「Nubification（成云作用）」的启发，但先别急着直接进入我们的实现，我们先来做一个简短的思维实验。要真正理解云形成背后的物理原理，我们需要近距离地体验它。

## 第 14 页

**EN:**
So, we are going to imagine ourselves as balloons that have been released into the air.

**中:**
那么，我们就把自己想象成被放飞到空中的气球。

**EN:**
I know it's early and a lot of us are jetlagged, but lets try.

**中:**
我知道现在时间还早，我们中很多人还在倒时差，但还是试一试吧。

**EN:**
Our upward journey starts in the morning as the sun begins to heat the earth and forces water vapor to rise into the higher colder layers of the atmosphere.

**中:**
我们的上升之旅从清晨开始，此时太阳开始加热大地，迫使水蒸气上升到大气中更高、更冷的层。

## 第 15 页

> 幻灯片文字：[照片] Photograph
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | 背景 / Background

**EN:**
In the distance this vapor starts to slowly seep upward from the earth and enter a cool layer of morning air.

**中:**
在远处，这些水汽开始慢慢从地面向上渗出，进入清晨凉爽的空气层。

**EN:**
• This slow emission of vapor into cool air produces the sheet-like shapes that Howard referred to as stratus clouds.

**中:**
• 水汽这样缓慢地进入冷空气，产生了片状的形态，霍华德称之为层云（stratus clouds）。

## 第 16 页

> 幻灯片文字：[照片] Photograph
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | 背景 / Background

**EN:**
We notice that elsewhere, large pulses of warm vapor

**中:**
我们注意到，在别处，大股温暖的水汽脉冲

**EN:**
• appear to create the stacked, round shapes that Howard describes as Cumulus clouds. They tower around us as a warm updraft of air lifts us into the atmosphere. This updraft is part of what is known as a convection current.

**中:**
• 似乎制造出霍华德所说的积云（Cumulus clouds）那种层叠的圆形形态。随着一股温暖的上升气流把我们托入大气，它们在我们四周高耸而立。这股上升气流是所谓对流（convection current）的一部分。

## 第 17 页

> 幻灯片文字：[照片] Photograph
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | 背景 / Background

**EN:**
We feel a force pushing us to the side and then dropping us.  We have entered a pocket instability in the convection current called turbulence.

**中:**
我们感到一股力量把我们推向一侧，随后又让我们下坠。我们进入了对流中的一处不稳定气穴，也就是湍流。

**EN:**
• This disturbing force shreds clouds and tears them apart all around us, which produces wispy and curling shapes.

**中:**
• 这种扰动之力撕碎并扯裂我们周围的云，产生出纤细卷曲的形态。

**EN:**
We see that the light from the sun creates shafts of light in the hazy pockets of water vapor all around us.

**中:**
我们看到太阳的光线在我们周围朦胧的水汽团中形成一道道光束。

## 第 18 页

> 幻灯片文字：[照片] Photograph
> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | 背景 / Background

**EN:**
As we rise higher, past the point where this vapor cools andcondenses on dust and salt particles, we see a clear line of demarcation where local pockets of condensed vapor become dense enough that light rays can't avoid hitting the vapor and scatter instead of continuing to the ground.

**中:**
随着我们继续升高，越过水汽冷却并凝结在尘埃和盐粒上的那个高度，我们看到一条清晰的分界线：局部凝结的水汽团变得足够稠密，以至于光线无法避开它们，只能被散射，而无法继续射向地面。

**EN:**
We also notice that some cumulus clouds have begin to overlap and cluster together into sheets of their own.  This is what Howard referred to as stratocumulus clouds because they are both a sheet and a stack of round shapes.

**中:**
我们还注意到，一些积云已经开始彼此重叠、聚集成它们自己的片层。这就是霍华德所说的层积云（stratocumulus clouds），因为它们既是片层，又是圆形形态的堆叠。

**EN:**
Also, The temperature is dropping by 6.5 degrees Celsius for every kilometer that we ascend. (3) This shouldn't be hard to imagine in this ballroom.

**中:**
此外，我们每上升一公里，温度就下降 6.5 摄氏度。(3) 在这个宴会厅里，这一点应该不难想象。

---

## 第 19 页

> 幻灯片文字：NUBIS | 背景 / Background
> Advances in Real-Time Rendering, Siggraph 2017（页脚）
> [图] Photograph / 照片

**EN:**
The wind up here is quite strong
• and it begins to push us and other clouds to the side as we rise.

**中:**
这里高处的风相当强劲，
• 随着我们不断上升，它开始把我们和其他的云都推向一侧。

---

## 第 20 页

> 幻灯片文字：NUBIS | 背景 / Background
> Advances in Real-Time Rendering, Siggraph 2017（页脚）
> [视频] Video / 视频

**EN:**
A large billowing cumulus congestus cloud passes by us on our journey. There is a peculiar effect on the clouds that we did not see from the ground.  The edges appear dark. Curious.

**中:**
在我们这段旅程中，一朵巨大而翻腾的浓积云（cumulus congestus）从我们身旁经过。云上出现了一种我们在地面上从未见过的奇特效果。云的边缘看上去是暗的。耐人寻味。

---

## 第 21 页

> 幻灯片文字：NUBIS | 背景 / Background
> Advances in Real-Time Rendering, Siggraph 2017（页脚）
> [视频] Video / 视频

**EN:**
Suddenly the temperature drops sharply. We look back to the horizon and see that we are entering a new layer of clouds, the Alto layer. We are passing through a sheet that Howard described as the Altostratus clouds.

**中:**
突然，温度骤降。我们回头望向地平线，看到自己正在进入新的一层云——高层（Alto）层。我们正穿过一片 Howard 所描述的、被称为高层云（Altostratus）的云幕。

---

## 第 22 页

> 幻灯片文字：NUBIS | 背景 / Background
> Advances in Real-Time Rendering, Siggraph 2017（页脚）
> [图] Photograph / 照片

**EN:**
Behind us we see that a cumulus cloud has
• punched through the alto layer.
• It is becoming the grandest of the cloud forms, the Cumulonimbus cloud.

**中:**
在我们身后，我们看到一朵积云
• 冲破了高层云层。
• 它正在变成最宏大的云形态——积雨云（Cumulonimbus）。

---

## 第 23 页

> 幻灯片文字：NUBIS | 背景 / Background
> Advances in Real-Time Rendering, Siggraph 2017（页脚）
> [图] Photograph / 照片

**EN:**
With the alto clouds now below us we see the top of the cumulus cloud continues to rise until it hits another colder layer of air in what is called the cirro layer.
• It spreads out in the classic anvil shape.

**中:**
如今高层云已在我们下方，我们看到那朵积云的顶部继续上升，直到撞上另一层更冷的空气——也就是所谓的卷云层（cirro layer）。
• 它铺展开来，形成经典的砧状（anvil）外形。

---

## 第 24 页

> 幻灯片文字：NUBIS | 背景 / Background
> Advances in Real-Time Rendering, Siggraph 2017（页脚）
> [图] Photograph / 照片

**EN:**
Behind us we see the stretched, fibrous shapes of the cirrus clouds. Up here it is below freezing and all water has crystalized into ice.
• which has compressed the clouds into sheets of wispy striations.

**中:**
在我们身后，我们看到卷云（cirrus）被拉伸成的纤维状形态。在这高处，气温低于冰点，所有的水都已结晶成冰。
• 冰把云压成了一片片丝丝缕缕的条纹。

---

## 第 25 页

> 幻灯片文字：NUBIS | 背景 / Background
> Advances in Real-Time Rendering, Siggraph 2017（页脚）
> [图] Photograph / 照片

**EN:**
Eventually the low pressure stresses our elastic bodies so much that we pop…….  And fall back into our chairs in this convention center ballroom.

**中:**
最终，低气压把我们富有弹性的身体拉扯到极限，以至于我们「砰」地一声……又落回到这间会议中心宴会厅里的椅子上。

---

## 第 26 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> • Cloud type determined by vapor / heat
> • Density changes  / height
> • Minus, Alto, Cirro
> • Roiling, Tearing, Curling, Spreading
> • Skewing by wind
> Advances in Real-Time Rendering, Siggraph 2017（页脚）
>
> 幻灯片文字（中）：云的类型由水汽 / 热量决定；密度随高度变化；低层（Minus）、高层（Alto）、卷云层（Cirro）；翻涌、撕裂、卷曲、铺展；受风倾斜（Skewing by wind）

**EN:**
Ok, Lets catalog what we observed on our journey.

**中:**
好，让我们把旅途中观察到的东西编成一份清单。

**EN:**
• We saw how vapor and heat rise to form clouds
• And that over this vertical journey, temperature decreases causing the density of water molecules to increase
• We also noticed 3 distinct regions of clouds: The the lower or minus clouds, The alto clouds and the cirro clouds.
• Additionally, we saw how instability can shape clouds by and producing tearing, spreading, and roiling shapes.
• We saw that Wind also skews clouds as they rise.

**中:**
• 我们看到了水汽和热量如何上升形成云
• 也看到在这段垂直旅程中，温度下降，使得水分子的密度增加
• 我们还注意到三个截然不同的云区：较低的 minus 云，alto 云，以及 cirro 云。
• 此外，我们看到不稳定性如何塑造云，产生撕裂、铺展和翻涌的形态。
• 我们还看到，风在云上升的过程中也会使其发生倾斜。

---

## 第 27 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> Cloud Coverage  Cloud Type（云的覆盖度 / 云的类型）
> Advances in Real-Time Rendering, Siggraph 2017（页脚）

**EN:**
Now, lets form some abstractions using these observations.

**中:**
现在，让我们利用这些观察来做一些抽象。

**EN:**
Real-time is all about compression, so If we had to reduce the experience we just had down to two pieces of information we could say
• that we saw variations in cloud coverage and in cloud type over space. I mentioned early on that Nubis is comprised of a set of predefined behaviors. Most of the behaviors in the density model are dictated by these variables.

**中:**
实时渲染的核心就是压缩，所以如果必须把刚刚经历的体验归纳成两条信息，我们可以说
• 我们看到了云在空间上的覆盖度和云的类型的变化。我在前面提到过，Nubis 由一组预定义的行为构成。密度模型中的大多数行为都由这些变量决定。

---

## 第 28 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> height（高度）
> Advances in Real-Time Rendering, Siggraph 2017（页脚）

```
remap(value, original_min, original_max, new_min, new_max)
{
return new_min + (((value - original_min) / (original_max - original_min)) * (new_max - new_min))
}
stratus    =    remap(height, 0.0, 0.1, 0.0, 1.0)    *    remap(height, 0.2, 0.3, 1.0, 0.0)
```

**EN:**
• If we were to describe the probability of change in density over height for a cloud we might envision a gradient like this

**中:**
• 如果我们要描述一朵云的密度随高度变化的概率，我们可能会设想出一个像这样的梯度。

**EN:**
• We can implement this mathematically using a remapping function. For the non-coders in the room this is like the setRange in Maya or the Fit in Houdini.

**中:**
• 我们可以用一个重映射函数在数学上实现它。对房间里不写代码的人来说，这就像 Maya 里的 setRange 或者 Houdini 里的 Fit。

**EN:**
• We combine two of these gradients to create an area of high density probability as in the gradient above.

**中:**
• 我们把两个这样的梯度组合起来，形成如上图梯度所示的高密度概率区域。

**EN:**
• If we wish to describe all of the stages of a cloud in the minus layer, we can simply adjust the in and out points of our remap function.

**中:**
• 如果我们想描述低层（minus layer）中一朵云的所有阶段，只需调整 remap 函数的入点和出点。

---

## 第 29 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> type（类型）
> 0 1
> Cumulus / Stratocumulus / Stratus（积云 / 层积云 / 层云）
> Advances in Real-Time Rendering, Siggraph 2017（页脚）

```
remap(y, 0, .1, 0, 1)    *    remap(y, .2, .3, 1, 0)
```

**EN:**
• Since we know that cloud type is determined by rate of emission and temperature, and that each cloud type has a different height range
• we can order a set of these adjustments according to cloud type in order to represent the height probabilities for each type of cloud.

**中:**
• 既然我们知道云的类型由排放速率和温度决定，而且每种云类型都有不同的高度范围
• 我们就可以按云类型对一组这样的调整进行排序，从而表示每种云的高度概率。

**EN:**
• Type, can then serve as the value which modifies the in and out points of our remap functions.

**中:**
• 于是，类型（Type）就可以作为修改我们 remap 函数入点和出点的那个值。

**EN:**
Lets look at this in practice.

**中:**
让我们看看它在实践中的效果。

---

## 第 30 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> Stratus / Stratocumulus / Cumulus（层云 / 层积云 / 积云）
> [游戏内渲染] in-game render
> Advances in Real-Time Rendering, Siggraph 2017（页脚）

**EN:**
This is our cumulus Gradient

**中:**
这是我们的积云（cumulus）梯度。

---

## 第 31 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> Stratus / Stratocumulus（层云 / 层积云）
> [游戏内渲染] in-game render
> Advances in Real-Time Rendering, Siggraph 2017（页脚）

**EN:**
Our Stratocumulus gradient

**中:**
我们的层积云（Stratocumulus）梯度。

---

## 第 32 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> Stratus（层云）
> [游戏内渲染] in-game render
> Advances in Real-Time Rendering, Siggraph 2017（页脚）

**EN:**
And our stratus gradient.

**中:**
以及我们的层云（stratus）梯度。

---

## 第 33 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> Perlin-Worley / 1-Worley / Perlin
> [Schneider, 2015]
> Advances in Real-Time Rendering, Siggraph 2017（页脚）

**EN:**
If we were to describe the curling and roiling shapes over 3 dimensional space we might use 3d textures like Perlin noise, inverted Worley noise or, as we proposed in 2015, a combination of both depending on cloud type or height.

**中:**
如果我们要在三维空间中描述那些卷曲和翻涌的形态，我们可能会使用 3D 纹理，比如 Perlin 噪声、反相的 Worley 噪声，或者像我们在 2015 年提出的那样，根据云的类型或高度把两者组合起来。

**EN:**
Our Perlin-Worley composite noise has been the subject of discussion in the community.

**中:**
我们的 Perlin-Worley 合成噪声一直是社区讨论的话题。

---

## 第 34 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> Perlin-Worley
> GameDev.net Forum:
> https://www.gamedev.net/forums/topic/680832-horizonzero-dawn-cloud-system
> Sebastien Hillaire from Frostbite published a generator:
> https://github.com/sebh/TileableVolumeNoise
> Advances in Real-Time Rendering, Siggraph 2017（页脚）

```
perlin-worley = remap( perlin , 1.0 - worley , 1.0, 0.0, 1.0)
```

**EN:**
• Some developers in the gamedev.net forum are doing great work with it, you should really check it out.

**中:**
• gamedev.net 论坛上的一些开发者围绕它做出了很棒的工作，你们真的应该去看看。

**EN:**
• Sebastien Hillaire from frostbite also put out some code last year to generate this noise. I spoke to him about this and in the near future, you can expect a contribution from us to this codebase.

**中:**
• Frostbite 的 Sebastien Hillaire 去年也发布了一些生成这种噪声的代码。我和他谈过这件事，在不久的将来，你们可以期待我们向这个代码库做出贡献。

**EN:**
• Our approach, In principle, was to subtract the web like shapes of Worley noise from the low density regions of perlin noise in order to introduce round shapes there.

**中:**
• 原则上，我们的做法是从 Perlin 噪声的低密度区域中减去 Worley 噪声那种网状的形状，从而在那里引入圆润的形状。

**EN:**
But, Rather than hashing out the entire procedure for this here (sorry for the bad pun) I'm going to provide something that can get you started right away…

**中:**
不过，与其在这里把整套流程从头 hash 一遍（抱歉，这个双关有点烂），我打算直接给你们一个能马上上手的东西……

---

## 第 35 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> • Houdini Digital Asset
> • Comes with instructions, batteries not included.
> • Returns a tiling 2D Texture Array
> http://bit.ly/nubisnoisegen
> [shaderbits.com blog]
> Advances in Real-Time Rendering, Siggraph 2017（页脚）
>
> 幻灯片文字（中）：Houdini 数字资产；附带说明，电池不含在内；返回一个可平铺的 2D 纹理数组

**EN:**
We are going to give you the noise generator we used.

**中:**
我们打算把所用的噪声生成器给你们。

**EN:**
• It is a Houdini Digital asset That operates in the cops context.
• There are usage instructions in the download
• It produces a tiling array of 3d texture slices which you can convert into a 3d texture using your engine of choice.

**中:**
• 它是一个 Houdini 数字资产，运行在 cops 上下文中。
• 下载包里附有使用说明。
• 它会生成一个可平铺的 3D 纹理切片数组，你可以用自己选用的引擎把它转换成 3D 纹理。

**EN:**
You are free to use this but please share your results with the community, especially when you inevitably improve it! The slides will be online today so you can also grab this link then.

**中:**
你们可以自由使用它，但请把成果分享给社区，尤其是当你们不可避免地把它改进之后！幻灯片今天就会上线，届时你们也可以在上面找到这个链接。

---

## 第 36 页

> 幻灯片文字：NUBIS | 密度模型 / Density Model
> [代码实现示例，见幻灯片] [code implementation example in the slides]
> Advances in Real-Time Rendering, Siggraph 2017（页脚）

```
base_cloud = remap(low_freq_noise, high_freq_noise, 1.0, 0.0, 1.0)
```

**EN:**
As detailed in in the 2015 course, we use a set of
• low frequency Perlin Worley and Worley noises to form the basis of the potential cloud surface and a set of
• high frequency Worley noises to add detail by eroding the base cloud shape with
• a remapping function. We decided to use remapping functions in our noise fBms because of a really useful behavior: as opposed to multiplying the noises together, Remapping prevents a loss of too much density at the core of the base cloud shape.

**中:**
正如 2015 年的课程中详细介绍的那样，我们使用一组
• 低频的 Perlin-Worley 和 Worley 噪声来构成潜在的云表面的基底，以及一组
• 高频的 Worley 噪声，通过
• 一个重映射函数来侵蚀基础云的形状，从而增加细节。我们之所以决定在噪声 fBm 中使用重映射函数，是因为它有一个非常有用的特性：与把噪声相乘相比，重映射可以避免基础云形状核心处的密度损失过多。

---

## 第 37 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render

**EN:**
Here's what our clouds look like WITHOUT using noise as a base probability for density.

**中:**
这就是我们的云在不使用噪声作为密度（density）基础概率时的样子。

## 第 38 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render

**EN:**
Our Low frequency noises really form the foundation of our clouds, as you can see.

**中:**
如你所见，我们的低频噪声确实构成了云的基础。

## 第 39 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render

**EN:**
And the high frequency noises add detail without taking anything away at the center of the cloud.

**中:**
而高频噪声则在云的中心区域增添细节，同时不会削减任何东西。

**EN:**
Its kind of like carving out a block of clay, except that all of the details are already stored in the clay and you are just revealing them as you carve. But in that analogy what dictates how deep to carve?

**中:**
这有点像雕刻一块黏土，只不过所有细节本来就已经存储在黏土里，你只是在雕刻的过程中把它们显露出来。但在那个比喻里，是什么决定了要雕多深呢？

## 第 40 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> 幻灯片文字：coverage / 覆盖度
> 0 1
>
> ```
> cloud_with_coverage = remap(noise, cloud_coverage, 1.0, 0.0, 1.0)
> ```

**EN:**
If we think back to our thought experiment we also recall that there were large scale variations in emission of moisture which created individual clouds.
• We can express this by defining a cloud by its coverage of the sky at a given point.

**中:**
如果我们回想一下之前的思维实验，我们也会记起，水汽的排放存在大尺度的变化，这些变化形成了单独的云朵。
• 我们可以通过用云在天空中某一给定位置处的覆盖度（coverage）来定义一朵云，以此表达这一点。

**EN:**
Also, because we are using our noise as a base probability for cloud density in a sample,
• we can apply the coverage value as an erosion in another remapping function. This allows the cloud appear to expand or contract over a gradient of coverage values in space.

**中:**
另外，由于我们是把噪声用作某个采样点上云密度的基础概率，
• 我们可以把覆盖度值作为另一个重映射函数中的侵蚀来应用。这使得云能够随着空间中覆盖度值的梯度而膨胀或收缩。

**EN:**
Here is an example.

**中:**
这里有一个例子。

## 第 41 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render

**EN:**
As the coverage value increases across the sky, the clouds in this image begin to inflate. This is useful when animating cloud coverage in transitions.

**中:**
随着覆盖度值在天空中逐渐增大，这张图像中的云开始膨胀。这在过渡中为云覆盖度做动画时很有用。

## 第 42 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render

**EN:**
As the coverage value increases across the sky, the clouds in this image begin to inflate. This is useful when animating cloud coverage in transitions.

**中:**
随着覆盖度值在天空中逐渐增大，这张图像中的云开始膨胀。这在过渡中为云覆盖度做动画时很有用。

## 第 43 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render

**EN:**
As the coverage value increases across the sky, the clouds in this image begin to inflate. This is useful when animating cloud coverage in transitions.

**中:**
随着覆盖度值在天空中逐渐增大，这张图像中的云开始膨胀。这在过渡中为云覆盖度做动画时很有用。

## 第 44 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render

**EN:**
As the coverage value increases across the sky, the clouds in this image begin to inflate. This is useful when animating cloud coverage in transitions.

**中:**
随着覆盖度值在天空中逐渐增大，这张图像中的云开始膨胀。这在过渡中为云覆盖度做动画时很有用。

## 第 45 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render
> [视频] [video]
>
> ```
> p += wind_direction * time_offset;
> p += height_fraction * wind_direction * 500.0;
> ```

**EN:**
In reality, clouds are not free floating objects but ephemeral results in a changing volume of probabilities.
• We can simulate their movement across their region of probability by adding an offset in the wind direction which is incremented in time.
• We can also use the direction of the wind to apply a skew to the clouds in this direction over height.

**中:**
在现实中，云并不是自由漂浮的物体，而是一个不断变化的概率体积中转瞬即逝的结果。
• 我们可以通过在风向上加入一个随时间递增的偏移，来模拟它们在各自的概率区域中的移动。
• 我们还可以利用风的方向，让云在高度方向上沿这个方向产生倾斜。

**EN:**
Here is a sped up example. Notice that the general shapes do not change, but the details do. This is because while the noise in the density model is animated, the coverage signal is not. For us this is an important deviation from our prototype system because when we are constructing art-directed cloudscapes as opposed to a simulated sky, we only want them to appear to be changing without altering the larger structure of the cloudscape.

**中:**
这里有一个加速播放的例子。注意整体形状没有改变，但细节改变了。这是因为密度模型中的噪声是动态的，而覆盖度信号不是。对我们来说，这是与原型系统的一个重要偏离，因为我们在构建的是美术指导的云景，而不是模拟的天空，我们只希望它们看起来在变化，而不改变云景更大的结构。

**EN:**
We are so glad that we didn't have to figure out how to do this with a skybox.

**中:**
我们非常庆幸，不必去搞清楚怎么用天空盒做到这件事。

## 第 46 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render
>
> ```
> coverage = pow(coverage, remap(height, 0.7, 0.8, 1.0, lerp(1.0, 0.5, anvil_bias)));
> ```

**EN:**
Finally, recall that when we were in the alto and cirro layers, the cumulus cloud started spreading out to form an anvil. To mimic this we treat these anvil shapes as a variation on the cumulus form by inflating the …

**中:**
最后，回想一下当我们在高积云层和卷云层时，积云开始铺展开来形成砧状（anvil）。为了模仿这一点，我们把这些砧状形态当作积云形态的一种变体，做法是把……膨胀开来

## 第 47 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render
>
> ```
> coverage = pow(coverage, remap(height, 0.7, 0.8, 1.0, lerp(1.0, 0.5, anvil_bias)));
> ```

**EN:**
coverage signal where it approaches

**中:**
覆盖度信号，在它接近

## 第 48 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render
>
> ```
> coverage = pow(coverage, remap(height, 0.7, 0.8, 1.0, lerp(1.0, 0.5, anvil_bias)));
> ```

**EN:**
the top of our cloud layer.

**中:**
我们云层顶部的地方。

## 第 49 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render
>
> ```
> coverage = pow(coverage, remap(height, 0.7, 0.8, 1.0, lerp(1.0, 0.5, anvil_bias)));
> ```

**EN:**
For Dramatic effect, we add a variation to the wind vector that allows …

**中:**
为了戏剧性的效果，我们给风矢量加入一个变化，让我们能够……

## 第 50 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Density Model
> [游戏内渲染] in-game render
>
> ```
> coverage = pow(coverage, remap(height, 0.7, 0.8, 1.0, lerp(1.0, 0.5, anvil_bias)));
> ```

**EN:**
us to skew the anvils in a direction that is not natural but looks cool.

**中:**
……把砧状云朝一个并不自然、但看起来很酷的方向倾斜。

**EN:**
So we have modeled some of the characteristics of the clouds of the lower atmosphere, but what about the alto and cirrus clouds?

**中:**
那么，我们已经为低层大气中的云建模了其中一些特征，但高积云和卷云呢？

**EN:**
The version that we shipped with Horizon only models the low clouds and uses a 2D texture lookup for the cirrus clouds, but I will show you some work we have been doing on this a bit later in the talk.

**中:**
我们在《地平线》中发布的版本只对低云建模，卷云则使用 2D 纹理查找，不过我会在稍后的演讲中展示我们在这方面一直在做的一些工作。

**EN:**
In the slides there will be a code example of how all of these parts are used together in the density sampler.

**中:**
幻灯片里会有一个代码示例，展示所有这些部分是如何在密度采样器中一起使用的。

## 第 51 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Authoring System
> 图示文字：Authoring System
> 图示文字：Cloud Density Model
> 图示文字：Cloud Lighting Model
> 图示文字：Ray March
> 图示文字：Post Process

**EN:**
Now that we have an idea of how to model a single cloud, we can define a procedural system, which generates the coverage and type values in order to construct entire cloud formations.

**中:**
既然我们已经了解了如何为单朵云建模，我们就可以定义一个程序化系统，由它生成覆盖度和类型值，从而构建出完整的云系。

**EN:**
But what is a cloud formation and how do they form?

**中:**
但什么是云系，它们又是如何形成的呢？

## 第 52 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Authoring System
> [照片] Photograph
> [Clausse & Facy, 1961]

**EN:**
According to Clausse and Facy in their seminal book, The Clouds, cloud formations form where two or more masses of air overlap. In these overlap regions, the vapor in the warmer air mass condenses when it contacts the colder air mass.
• If you look closely at this photograph, you can see the places where these air masses meet and allow clouds to form. You can also see that there are gaps in these areas where no clouds form or where their type changes.

**中:**
根据 Clausse 和 Facy 在他们那本开创性的著作《云》（The Clouds）中的说法，云系形成于两团或更多气团相互重叠的地方。在这些重叠区域中，较暖气团里的水汽在接触到较冷气团时凝结。
• 如果你仔细看这张照片，你能看到这些气团相遇并让云得以形成的位置。你还能看到这些区域中存在空隙，那里没有云形成，或者云的类型发生了变化。

**EN:**
Recall that our density model defines clouds according to Type and Coverage values.

**中:**
回想一下，我们的密度模型是依据类型（Type）和覆盖度（Coverage）值来定义云的。

**EN:**
As mentioned in our 2015 course, we generate these variations over space using several octaves of noise, and produce what we call a cloud map.

**中:**
正如我们在 2015 年课程中提到的，我们使用若干个噪声倍频（octave）在空间中生成这些变化，并产生我们所说的云图（cloud map）。

## 第 53 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Authoring System
> 图示文字：N / S / W E

**EN:**
The cloud map is an RGB buffer which represents a coverage area of about 100 square kilometers. The red and green channels represent cloud coverage. In this example cloud coverage is at 100% for the whole map.

**中:**
云图是一张 RGB 缓冲，它代表约 100 平方公里的覆盖区域。红、绿两个通道表示云的覆盖度。在这个例子中，整张地图的云覆盖度是 100%。

## 第 54 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> 幻灯片文字：NUBIS | Authoring System
> 图示文字：N / S / W E

**EN:**
A low frequency noise modulates cloud coverage to simulate those large regions where air masses overlap and clouds are allowed to form.

**中:**
一张低频噪声对云覆盖度进行调制，以模拟那些气团重叠、云得以形成的大尺度区域。

---

## 第 55 页

> 幻灯片文字：N / S / W E（指北/南/西/东）
> Advances in Real-Time Rendering, Siggraph 2017
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
Several higher frequency noises are composited with this to simulate the variations in vapor emission in these regions which form the footprints of our clouds. Perlin noise is used in the red channel , while a Perlin-Worley  noise is used in the green channel.

**中:**
若干个更高频的噪声与它合成，用来模拟这些区域中水汽发散的变化，这些区域构成了我们云的「足迹」。红色通道使用 Perlin 噪声，绿色通道使用 Perlin-Worley 噪声。

## 第 56 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> [游戏内渲染] in-game render
> Perlin
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
Either noise is used in the density sampler depending on if the artist wants connected cloud formations like this from Perlin noise…

**中:**
密度采样器会使用这两种噪声中的哪一种，取决于美术是否想要像这样由 Perlin 噪声生成的连片云体……

## 第 57 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> [游戏内渲染] in-game render
> Perlin-Worley
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
…or more isolated island like shapes with connective tissue from Perlin-Worley noise.

**中:**
……还是想要更孤立的、像岛屿一样、由 Perlin-Worley 噪声充当连接组织的形状。

## 第 58 页

> 幻灯片文字：N / S / W E（指北/南/西/东）
> Advances in Real-Time Rendering, Siggraph 2017
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
Finally, Another low frequency noise is used to define the modulation in cloud type. This goes into the blue channel, with a value of Zero being stratus, , 1 being cumulus or value of .5 indicates stratocumulus clouds.

**中:**
最后，用另一个低频噪声来定义云类型的调制。它写入蓝色通道，值为 0 表示层云（Stratus），值为 1 表示积云（Cumulus），值为 .5 则表示层积云（Stratocumulus）。

**EN:**
Recall that there are other things going on in our density model…

**中:**
回想一下，我们的密度模型里还有其他事情在发生……

## 第 59 页

> 幻灯片文字：云图 / Cloud Map
> 「多云」/ “Cloudy”
> 天气状态 / Weather State
> 「多云，有风」/ “Cloudy, Windy”
> -斜切 / -Skew
> -砧状形状 / -Anvil Shapes
> -移动速度 / -Movement Speed
> -移动方向 / -Movement Direction
> -云密度 / -Cloud Density
> Advances in Real-Time Rendering, Siggraph 2017
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
The cloud map is just a part of a larger set of instructions that tell our density model what to produce.

**中:**
云图只是一大组指令中的一部分，这组指令告诉我们的密度模型要生成什么。

**EN:**
• The map is incorporated into what we call a weather state. The weather state adds more characteristics used in modeling clouds.

**中:**
• 这张图会被纳入我们所说的「天气状态」之中。天气状态补充了更多用于云的建模的特征。

**EN:**
These include

**中:**
这些特征包括

**EN:**
• Skew,

**中:**
• 斜切，

**EN:**
• Anvil inflation,

**中:**
• 砧状膨胀，

**EN:**
• Movement

**中:**
• 移动

**EN:**
• and direction controls and

**中:**
• 和方向控制，以及

**EN:**
• density controls.

**中:**
• 密度控制。

**EN:**
These are treated same at every sample, so they didn't need to be stored in the Cloud Map.

**中:**
这些在每个采样点上的处理方式都相同，所以不需要存储在云图里。

**EN:**
Before we look at how to use all of these controls to build various cloudscapes, Lets briefly look at how cloudscapes are used in art and photography as this informs our approach for Horizon.

**中:**
在我们看如何用这些控制项搭建各种体积云景之前，先简要看看云景在绘画和摄影中是如何被使用的，因为这影响了我们为《地平线：零之曙光》所采取的做法。

## 第 60 页

> 幻灯片文字：Painting by John Constable（John Constable 的画作）
> 「天空是主音，是情感的主要器官。」/ “The Sky is the keynote and chief  organ of  sentiment.”
> – John Constable
> Advances in Real-Time Rendering, Siggraph 2017
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
We should always start with the British landscape painter, John Constable.

**中:**
我们总是应该从英国风景画家 John Constable 说起。

**EN:**
• Look at the subtle shapes produced by the clouds. [His arrangement of clouds in this work adds depth layers in the top of the frame in a way that is similar to cascading curtains that are pulled back at the beginning of a play.]

**中:**
• 看看这些云所产生的微妙形状。[他在这幅作品中对云的安排，在画面顶部叠加出了层层深度，就像一出戏开场时被拉开的层叠幕布。]

**EN:**
• Constable said that the  “Sky is the keynote and the chief organ of sentiment.” What he meant was that clouds are an important emotional element of any landscape artwork regardless of how visible they are. When we think back to how early man feared the storms that brought destruction, or the clear skies that could bring drought, it is easy to understand why this emotional response is so engrained. We don't even realize how images like this affect us emotionally until we actually think about it. In games, we want to elicit emotional responses like this, so for Nubis, the clouds, as viewed from each camera angle, would need to evoke a similar emotional response.

**中:**
• Constable 说过「天空是主音，是情感的主要器官。」他的意思是，无论云多么显眼，它都是任何风景作品中重要的情感元素。当我们回想早期人类如何畏惧带来毁灭的风暴、或带来旱灾的晴空，就不难理解为什么这种情感反应如此根深蒂固。直到我们真的去想一想，才会意识到这样的图像在情感上对我们有多大影响。在游戏里，我们想要唤起这样的情感反应，所以对 Nubis 而言，从每一个摄像机角度看过去的云，都需要唤起类似的情感反应。

## 第 61 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> Painting by Albert Bierstadt（Albert Bierstadt 的画作）
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
Artists like Albert Bierstadt, here, were part of a natural romanticism movement, which really captured several aspects of what we were trying to achieve for Horizon.

**中:**
像这里的 Albert Bierstadt 这样的画家属于自然浪漫主义运动，他们真实地捕捉到了我们为《地平线》想要达成的若干方面。

**EN:**
• This image promotes a feeling of mystic awe as the eye is drawn to the dramatic bright area in the mountains where pillars of cumuloform clouds appear to

**中:**
• 这幅画唤起一种神秘的敬畏感，视线被吸引到山间那片戏剧性的明亮区域，那里一柱柱积云状的云似乎

**EN:**
• grow out of the mountains, which has the effect of extending the landscape vertically.

**中:**
• 从山中生长出来，效果是把风景在垂直方向上延展开来。

## 第 62 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> Photograph by Ansel Adams（Ansel Adams 的摄影作品）
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
Other artists, such as the Photographer, Ansel Adams, were also very important for us because of the detail, tonal contrasts and composition of clouds

**中:**
其他艺术家，比如摄影家 Ansel Adams，对我们同样非常重要，原因在于细节、影调对比以及云的构图

**EN:**
• which lend dimensionality to the sky. His images are Iconic representations of the American West, as well.

**中:**
• 这些让天空有了立体感。他的影像也堪称美国西部的标志性表现。

## 第 63 页

> 幻灯片文字：• 为以下内容设定情绪与基调：/ • Set mood and tone for:
> • 遭遇战 / • Encounters
> • 探索 / • Exploration
> • 过场动画 / • Cutscenes
> • 延展风景 / • Extend the landscape
> • 可艺术指导、真实的结构 / • Art-Directable,  Realistic structures
> • 细节的演化，而非云体形态的演化 / • Evolution of details, not cloud formations
> • 行为随天气而变化 / • Changes in behavior based on Weather.
> Advances in Real-Time Rendering, Siggraph 2017
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
So the precedents set by these artists were clear.

**中:**
所以这些艺术家立下的先例是清楚的。

**EN:**
• We would need to help set the tone for Encounters, cut scenes and exploration of the world of Horizon.

**中:**
• 我们需要帮助为《地平线》世界中的遭遇战、过场动画和探索设定基调。

**EN:**
• The cloudscapes should also extend the landscape of the world and

**中:**
• 体积云景还应该延展这个世界的风景，并且

**EN:**
• Design wise, we also wanted to be able to generate realistic structures, not purely random noise patterns.

**中:**
• 从设计角度，我们还希望能够生成真实的结构，而不只是纯随机的噪声图案。

**EN:**
• Additionally, we knew that we wanted the clouds to evolve over time, but this evolution should not break the general arrangement of our cloudscapes, and

**中:**
• 此外，我们知道希望云随时间演化，但这种演化不应破坏我们体积云景的整体布局，并且

**EN:**
• Finally, That the cloud formations themselves would need to change as the weather conditions changed.

**中:**
• 最后，云体形态本身需要随着天气条件的变化而变化。

**EN:**
• Now that I have covered our methods and goals for cloudscapes, lets look at some examples from horizon.

**中:**
• 既然我已经讲完了我们在体积云景上的方法和目标，那就来看一些《地平线》里的例子。

## 第 64 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> [游戏内渲染] in-game render
> 云图 / Cloud Map
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
Mornings in the desert can be quite cold. If there is any vapor emission, it will probably create stratus clouds. So Cloud type was set to zero for this cloud map as you can see by the lack of Blue. We also wanted our mornings to be calm and peaceful, so In situations like this the clouds were meant to be felt more than seen, such as in the Constable painting.

**中:**
沙漠的清晨可能相当寒冷。如果有任何水汽发散，大概都会形成层云。所以这张云图的云类型被设为零，你可以从蓝色通道的缺失看出来。我们还希望清晨是平静、安宁的，所以在这样的情形下，云更多是被「感觉到」而不是被「看到」的，就像在 Constable 的画里那样。

## 第 65 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> [游戏内渲染] in-game render
> 云图 / Cloud Map
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
In contrast, the probability of cumulus clouds can increase in the afternoons, So this cloud map uses a higher cloud type value. We modeled the desert cumulus clouds after the Ansel Adams photographs.

**中:**
相比之下，积云在午后出现的概率会增加，所以这张云图使用了更高的云类型值。我们的沙漠积云是参照 Ansel Adams 的摄影作品来建模的。

## 第 66 页

> 幻灯片文字：云图 / Cloud Map
> NUBIS | 创作系统 / NUBIS | Authoring System
> Advances in Real-Time Rendering, Siggraph 2017
> [游戏内渲染] in-game render

**EN:**
In the alpine regions, we tried extending the landscape …Bierstadt style… by modeling isolated cumulus congestus columns.

**中:**
在高山地区，我们尝试以……Bierstadt 风格……来延展风景，做法是对孤立的浓积云云柱进行建模。

**EN:**
The big white arrow in the weather map indicates the camera direction.

**中:**
天气图里那个大白色箭头表示摄像机方向。

**EN:**
If you look closely, you can see where

**中:**
如果仔细看，你可以看到

**EN:**
• the reduction in the blue channel corresponds

**中:**
• 蓝色通道的减弱对应于

**EN:**
• to a stratus cloud band.

**中:**
• 一条层云云带。

## 第 67 页

> 幻灯片文字：天气模拟（着色器）/ Weather Simulation (Shader)
> 控制项（Decima 编辑器）/ Controls (Decima Editor)
> RGB 纹理（由天气模拟生成）/ RGB Texture (Generated by the Weather Simulation)
> 调整 云图（RGB 缓冲）/ Adjustments Cloud Map (RGB Buffer)
> Advances in Real-Time Rendering, Siggraph 2017
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
We used the weather simulation to produce procedural cloud maps like these for most of the game, but there were some situations, like cutscenes and important events, where the cloudscape needed a bit more control.

**中:**
在游戏的大部分内容里，我们使用天气模拟来生成像这样的程序化云图，但在某些情形下——比如过场动画和重要事件——体积云景需要更多的控制。

**EN:**
• We can override the result of the weather system using any texture. So, What we do to in cases like these is

**中:**
• 我们可以用任意纹理覆盖天气系统的结果。所以在这样的情形下，我们做的是

**EN:**
• adjust the results of the weather simulation in an image editor by increasing or decreasing coverage and type in specific areas.

**中:**
• 在图像编辑器里调整天气模拟的结果，在特定区域提高或降低覆盖度和类型值。

**EN:**
Here's a dramatic example.

**中:**
这里有一个很戏剧性的例子。

## 第 68 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> NUBIS | 创作系统 / NUBIS | Authoring System
> [游戏内渲染] in-game render
> [视频] [video]

**EN:**
This is a custom cloud map that I made for the Big boss fight at the end of the game.

**中:**
这是我为游戏结尾的最终 Boss 战做的一张自定义云图。

**EN:**
In the weather map in the corner of the screen, the white arrow indicates the camera direction. The point of the arrow indicates the camera position. You can see that the big blue area with low coverage corresponds to the opening around the sun in the image.

**中:**
在屏幕角落的天气图里，白色箭头表示摄像机方向。箭头的尖端表示摄像机位置。你可以看到，那片覆盖度很低的大片蓝色区域，对应于画面中太阳周围的那片开口。

**EN:**
• By combining several weather maps I made a kind of Frankencloudscape that incorporated the characteristics of several different systems at once.

**中:**
• 通过组合好几张天气图，我做出了一种类似「科学怪人云景」（Frankencloudscape）的东西，它一次性融合了好几个不同天气系统的特征。

**EN:**
• Also, when the the art director came by and said “I want a hole right here” it was as simple as

**中:**
• 而且，当艺术总监走过来说「我要正好在这儿开个洞」时，事情简单到只需要

**EN:**
• painting black on to the cloud map in the area that he indicated.

**中:**
• 在他指出的那块区域的云图上涂黑即可。

**EN:**
This is an area that really interests us.  We are beginning to look at ways to make this more intuitive and procedural in the future.

**中:**
这是一个真正让我们感兴趣的方向。我们开始研究将来如何让它更直观、更程序化。

**EN:**
So I have described how we generate procedural or custom cloud maps for a given location, but we also Have to account for the changing weather conditions

**中:**
好，我已经讲了我们如何为给定地点生成程序化或自定义的云图，但我们也必须考虑不断变化的天气条件

## 第 69 页

> [本页文字不全，为跨页句子的一部分]

**EN:**
throughout the day.

**中:**
在一天之中。

## 第 70 页

> 幻灯片文字：天气状态「多云」/ Weather State “Cloudy”
> 天气状态「晴朗」/ Weather State “Clear”
> 天气状态「风暴」/ Weather State “Storm”
> 天气循环 区域 A / Weather Cycle Zone A
> 天气调度器 / Weather Scheduler
> 天气循环「最终 Boss 战」/ Weather Cycle “Big Boss Fight”
> Advances in Real-Time Rendering, Siggraph 2017
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
Based on the climate and Art direction for a given region or Zone in the world map,

**中:**
基于世界地图上某个区域或分区的气候与艺术指导，

**EN:**
• we made a collection of weather states to cycle between. In this cycle, we blend between the 3 basic presets in the game. The States in Zone A, for example,

**中:**
• 我们做了一组天气状态，让它们在彼此之间循环。在这个循环里，我们在游戏中的 3 个基础预设之间做混合。比如区域 A 里的这些状态

**EN:**
• were used in the weather scheduler, Which decides what weather state to transition to next. The weather scheduler makes its decisions based on chance, but we have control over which weather states that it can use based on the time of day. Recall that Cumulus clouds usually don't appear in the morning.

**中:**
• 被用在天气调度器里，由它决定接下来过渡到哪个天气状态。天气调度器依据随机性来做决定，但我们可以根据一天中的时段，控制它能使用哪些天气状态。回想一下，积云通常不会在早晨出现。

**EN:**
• For Encounters like a boss fight, we defined specific cycles that overrode the regional cycles.

**中:**
• 对于像 Boss 战这样的遭遇战，我们定义了专门的循环，覆盖掉区域循环。

## 第 71 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> [游戏内渲染] in-game render
> NUBIS | 创作系统 / NUBIS | Authoring System
> [视频] [video]

**EN:**
The switch from one state to another is handled as a blend that takes place over about 10-30 seconds depending on the situation. This example has been sped up, otherwise you wouldn't really notice the change. But you can check it out yourself in the game.

**中:**
从一个状态切换到另一个状态，是以混合的方式处理的，根据具体情形大约持续 10-30 秒。这个例子做了加速，否则你其实不太会注意到这个变化。但你可以自己在游戏里看看。

**EN:**
It's a simple lerp between the current state and the next one in the schedule

**中:**
它就是当前状态与排程中下一个状态之间的一次简单线性插值（lerp）。

## 第 72 页

> 幻灯片文字：Advances in Real-Time Rendering, Siggraph 2017
> NUBIS | 创作系统 / NUBIS | Authoring System

**EN:**
And what about regional differences in climate and art direction? We had 10 regional zones in Horizon and 70 zones for things like Bandit camps , where the art director always wanted foreboding dark clouds .

**中:**
那气候和艺术指导上的地区差异又怎么处理呢？在《地平线》里我们有 10 个区域分区，还有 70 个用于像土匪营地这类地方的分区，在这些地方，艺术总监总是想要那种不祥的乌云。

**EN:**
As you move between these zones, The weather Scheduler replaces the next weather state in the schedule with the first randomly selected weather state in the new zone, and then starts the transition immediately.

**中:**
当你在这些分区之间移动时，天气调度器会把排程中的下一个天气状态，替换为新分区里随机选出的第一个天气状态，然后立即开始过渡。

---

## 第 73 页

> NUBIS | Cloud Lighting Model

> 幻灯片文字：创作（Authoring）、系统（System）、云（Cloud）

> 幻灯片文字：密度模型（Density Model）、云光照模型（Cloud Lighting Model）、光线步进（Ray March）、后处理（Post Process）

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
Our Authoring system and density model both directly inform our lighting calculations when we ray-march our cloudscapes.

**中:**
我们的创作系统与密度模型，都直接为我们对体积云景做 ray marching（光线步进）时的光照计算提供输入。

## 第 74 页

> NUBIS | Cloud Lighting Model

> 幻灯片文字："Clouds are bodies without surface." — Leonardo da Vinci

> [图] Photograph

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
Leonardo, the master of deduction and abstraction, called clouds "Bodies without surface". This is a fact.  When you look at a cloud you are peering into it's interior. This makes shading volumetrics like clouds more complicated than shading a surface.

**中:**
达·芬奇这位推演与抽象的大师，把云称作「没有表面的物体」。这是事实。当你看着一朵云时，你其实是在窥视它的内部。这就使得对云这类体积介质做着色，比给一个表面着色要复杂得多。

## 第 75 页

> NUBIS | Cloud Lighting Model

> 幻灯片文字：Beer-Lambert Law（比尔-朗伯定律）｜Absorption / Out-scattering（吸收 / 外散射）

> 幻灯片文字：Henyey-Greenstein Phase Function（Henyey-Greenstein 相位函数）｜Scattering（散射）

> 幻灯片公式：`Energy = exp( -density_along_light_ray ) *  HG( cos(θ), eccentricity)`

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
For performance reasons, the way you normally calculate Radiance or the light energy at a point in a volume is to combine the
• Beer-Lambert law, which simulates Transmittance and accounts for out-scattering and absorption with the
• Henyey-Greenstein Phase Function, which simulates the directional effects of light scattering. This is what's known as a single scattering lighting model.

**中:**
出于性能原因，通常计算体积中某一点的辐射度（Radiance），也就是光能量时，做法是把下面两者结合起来：
• 比尔定律（Beer-Lambert law），它模拟透射率，并处理外散射与吸收；
• Henyey-Greenstein 相位函数，它模拟光散射的方向性效应。这就是所谓的单次散射光照模型。

**EN:**
While this works for optically thin media like fog, it doesn't work so well for thick clouds because it fails to account for light that has scattered in, or in-scattered, to the sample point after bouncing off of hypothetical water molecules in the cloud. So, we propose a new model specifically for cheaply lighting thick volumetric clouds in a way that is more realistic.

**中:**
这套做法对于雾这样光学上很薄的介质是有效的，但对厚重的云就不太灵了，因为它没有考虑光在云中撞上假想的水分子之后、内散射（in-scatter）到采样点的那部分光。于是我们提出了一个新模型，专门用来以较低开销、且更真实的方式为厚重的体积云打光。

## 第 76 页

> NUBIS | Cloud Lighting Model

> 幻灯片文字：Absorption / Out-scatter Probability（吸收 / 外散射概率）｜In-Scatter Probability（内散射概率）｜Directional Scattering Probability（方向性散射概率）

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
Our Lighting model is an attenuation model, meaning that we start with the full light intensity and only do work to reduce it. It is a combination of 3 probabilities:
Directional scattering probability, which gives us finer control over the silver lining effect in clouds.
Absorption / out-scatter probability which also accounts for in-scattering.
And in-scattering probability, which accounts for the dark edges and bases to clouds.
First, lets look at directional scattering.

**中:**
我们的光照模型是一个衰减模型，意思是：我们从完整的光强度出发，之后所做的全部工作只是把它削减。它由 3 个概率组合而成：
方向性散射概率，它让我们能更精细地控制云中的银边（云隙透光）效果。
吸收 / 外散射概率，它同时也兼顾了内散射。
以及内散射概率，它解释了云的暗色边缘与暗色底部。
首先，我们来看方向性散射。

## 第 77 页

> NUBIS | Cloud Lighting Model

> 幻灯片代码：

```
cos_angle = dot(normalize(light_vector), normalize(view_vector));
HenyeyGreenstein(cos_angle, eccentricity)
{
return ((1.0 - eccentricity * eccentricity) / pow((1.0 + eccentricity * eccentricity - 2.0 * eccentricity * cos_angle), 3.0 / 2.0)) / 4.0 * PI;
}
```

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
This is the standard implementation of the Henyey-Greenstein function.  You calculate the cosine of an angle using the
• light vector and the
• view vector and supply it along with a
• directional scattering bias to the function, which makes the light scatter forward or backward. You then apply the result wherever you calculate the radiance of your sample.

**中:**
这是 Henyey-Greenstein 函数的标准实现。你用
• 光照向量和
• 视线向量
算出一个夹角的余弦值，把它连同
• 一个方向性散射偏置
一起传进该函数；这个偏置会让光向前散射或向后散射。然后，你在任何计算采样点辐射度的地方乘上这个结果。

**EN:**
There is one limitation with this though.

**中:**
不过，它有一个局限。

## 第 78 页

> NUBIS | Cloud Lighting Model

> 幻灯片文字：90º

> 幻灯片公式：`Energy = HG( cos(θ), eccentricity)`

> [游戏内渲染] in-game render

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
The Eccentricity value that worked well for mid-day failed to provide the bright highlights around the sun that we needed at sunset. If we stepped into the wilderness of artistic license and changed the eccentricity so that it was …

**中:**
那个在正午时表现良好的偏心率（Eccentricity）取值，到了日落时却无法提供我们所需要的、太阳周围的明亮高光。如果我们踏入「艺术自由发挥」的荒野，把偏心率改成……

## 第 79 页

> NUBIS | Cloud Lighting Model

> 幻灯片文字：90º

> 幻灯片公式：`Energy = HG( cos(θ), eccentricity)`

> 幻灯片文字：`eccentricity = 1.0`

> [游戏内渲染] in-game render

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
more forward scattering, we got the highlights that we needed near the sun, but the clouds 90 degrees away from the sun became too dark. In order to retain the baseline forward scattering behavior and get the silver lining highlights that we needed,

**中:**
……让前向散射更强，我们确实在太阳附近得到了所需的高光，但距离太阳 90 度方向上的云变得太暗了。为了既保留基线的前向散射行为，又能得到我们所需要的那种银边高光，

## 第 80 页

> NUBIS | Cloud Lighting Model

> 幻灯片文字：90º

> 幻灯片文字：`eccentricity = 0.6`

> 幻灯片公式：`Energy = max( HG( cos(θ), eccentricity), silver_intensity * HG( cos(θ), 0.99 – silver_spread))`

> [游戏内渲染] in-game render

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
we combined two Henyey-Greenstein phase functions using a max() operation. Now, since we had already taken artistic license, why stop there? We added an intensity control for this second phase function call that allowed us to

**中:**
我们用一次 max() 运算把两个 Henyey-Greenstein 相位函数结合了起来。既然我们已经动用过艺术自由了，何必就此收手？我们为第二次相位函数调用加了一个强度控制，它让我们可以

## 第 81 页

> NUBIS | Cloud Lighting Model

> 幻灯片文字：90º

> 幻灯片文字：`eccentricity = 0.6 ++`

> 幻灯片公式：`Energy = max( HG( cos(θ), eccentricity), silver_intensity * HG( cos(θ), 0.99 – silver_spread))`

> [游戏内渲染] in-game render

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
independently control the intensity of this effect

**中:**
独立地控制这一效果的强度

## 第 82 页

> NUBIS | Cloud Lighting Model

> 幻灯片文字：90º

> 幻灯片文字：`eccentricity = 0.6 ++ --`

> 幻灯片公式：`Energy = max( HG( cos(θ), eccentricity), silver_intensity * HG( cos(θ), 0.99 – silver_spread))`

> [游戏内渲染] in-game render

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
and its spread away from the sun.

**中:**
以及它从太阳向外扩散的范围。

**EN:**
It may not be particularly Kosher, in fact I'm sure someone in the audience is pulling their hair out right now. To that I would say first, enjoy the fact that you have hair!
Second, We don't like bandaids like this so this is also an area that we are continuing to investigate.

**中:**
这么做也许不太「正统」，事实上我敢肯定，此刻台下已经有人在揪自己的头发了。对此我想说：第一，庆幸你还有头发可揪吧！
第二，我们并不喜欢这种打补丁式的做法，所以这也是我们仍在持续研究的一个方向。

## 第 83 页

> NUBIS | Cloud Lighting Model

> [视频] [video]

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
Here's an example of how this looked during the time of day transition.

**中:**
这里有一个例子，展示它在一天内时段过渡过程中的表现。

## 第 84 页

> NUBIS | Cloud Lighting Model

> 幻灯片公式：`Energy = exp( - density_along_light_ray)`

> [游戏内渲染] in-game render

> 幻灯片文字：[Wrenninge, 2013]

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
As mentioned before, the beer-lambert law only accounts for attenuation of light and not emission from light that has in-scattered to the sample point. This makes clouds too dark as in the image above.  Our solution was similar to Magnus Wrenninge's Multiple Scattering approximation.

**中:**
如前所述，比尔定律只考虑了光的衰减，没有考虑内散射到采样点的光所带来的发射贡献。这会让云显得太暗，就像上图那样。我们的解决方案与 Magnus Wrenninge 的多重散射近似方法相似。

## 第 85 页

> NUBIS | Cloud Lighting Model

> 幻灯片公式：`Energy = max( exp( - density_along_light_ray ),  (exp(-density_along_light_ray * 0.25) * 0.7) )`

> [游戏内渲染] in-game render

> 幻灯片文字：[Wrenninge, 2013]

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
We combine two beer-lambert functions using a max operation. The attenuation value for the second function was reduced to push light further into the cloud. However, we reduced its influence so that we didn't overpower the result. Additionally, to make sure this only happens when we look away from the sun, we ramp down this affect as the angle between the view ray and the light ray decrease. You can find a code example of that in the slides.

**中:**
我们用一次 max 运算把两个比尔定律函数结合起来。第二个函数的衰减值被调低，以便把光推得更深入云内部。不过我们同时削弱了它的影响力，以免它盖过整体结果。此外，为了确保这一效果只在背对太阳看时才发生，我们随着视线射线与光线射线之间夹角的减小，把这个影响逐渐压下去。你可以在幻灯片里找到对应的代码示例。

**EN:**
There is a link at the end of this presentation to the solution that Seb Hillaire offered in 2016, which is worth considering as well.

**中:**
在本次演讲的结尾有一个链接，指向 Seb Hillaire 在 2016 年给出的方案，那个方案同样值得考虑。

## 第 86 页

> NUBIS | Cloud Lighting Model

> [图] Photograph

> 幻灯片文字：*

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
In-scattering or rather, the lack of it, also creates another lighting effect associated with clouds. In-scattering is when a light ray that has scattered in a cloud is combined with others on its way to your eye, effectively brightening the region of the cloud you are looking at.

**中:**
内散射——更确切地说，是内散射的缺失——还带来了另一种与云相关的光照效果。内散射指的是：在云中发生散射的一条光线，在射向你眼睛的途中与其他光线汇合，从而有效地提亮你正看着的那片云的区域。

**EN:**
In order for this to happen, you need to be looking at an area that has lots  of rays scattering into it. Scattering only occurs where there is cloud material. So, it follows that the deeper you are in a cloud, the more scattering contributors you will have.

**中:**
要让这件事发生，你需要看向一个有很多光线散射进去的区域。散射只发生在有云物质的地方。所以可以推出：你在云里越深，参与散射的贡献者就越多。

**EN:**
Recall the Leonardo quote. We can actually see into the regions where a lot of scattering happens.

**中:**
回想一下达·芬奇的那句话。我们其实能看进那些发生大量散射的区域内部。

## 第 87 页

> NUBIS | Cloud Lighting Model

> [图] Photograph

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
So the amount of in-scattering on the edges of clouds is lower, which makes them appear dark. This is especially noticeable when looking at the sun facing sides of clouds and this has to do with the directional scattering effect I mentioned earlier. In 2015 we made a function to approximate this effect and called it the powder sugar function. We have since improved this to account for the fact that the effect is not purely directional.

**中:**
所以云边缘处的内散射量更低，这使它们看起来偏暗。当你看着云朝太阳的那一侧时，这一点尤其明显，而这与我之前提到的方向性散射效应有关。2015 年我们做了一个函数来近似这一效果，管它叫「糖粉函数」（powder sugar function）。后来我们改进了它，以考虑这样一个事实：这一效果并非纯粹是方向性的。

## 第 88 页

> NUBIS | Cloud Lighting Model

> [图] Photograph

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
Additionally, we can assume, that because there are no strong scattering sources below clouds, the bottoms will have fewer occurrences of in-scattering as well,.

**中:**
此外，我们可以假设：由于云的下方没有强散射光源，云的底部同样会更少地发生内散射。

**EN:**
We represent both of the probabilities in a two term function called the In-Scatter Probability Function.
Lets take a look.

**中:**
我们把这两个概率表示在一个两段式函数里，称之为内散射概率函数（In-Scatter Probability Function）。
我们来看一看。

## 第 89 页

> NUBIS | Cloud Lighting Model

> 幻灯片代码：

```
depth_probability = 0.05 + pow( lodded_density, remap( height, 0.3, 0.85, 0.5, 2.0 ))2.0 )
vertical_probability = pow( remap( height, 0.07, 0.14, 0.1, 1.0 ), 0.8 )
in-scatter_probability = depth_probability * vertical_probability
```

> 幻灯片文字：[code implementation example in the slides]（幻灯片中的代码实现示例）

> [游戏内渲染] in-game render

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
What you see here is the result of our lighting model with JUST the attenuation and phase components.
Now lets account for in-scattering probability.. First, we need to know how much density exists around our sample position to have an idea of how much light could potentially scatter into the point.

**中:**
你在这里看到的是我们的光照模型仅包含衰减与相位两部分时的结果。
现在让我们把内散射概率也算进来。首先，我们需要知道采样位置周围存在多少密度，以便大致判断可能有多少光会散射进这一点。

## 第 90 页

> NUBIS | Cloud Lighting Model

> 幻灯片代码：

```
depth_probability = 0.05 + pow( lodded_density, remap( height, 0.3, 0.85, 0.5, 2.0 ))2.0 )
vertical_probability = pow( remap( height, 0.07, 0.14, 0.1, 1.0 ), 0.8 )
in-scatter_probability = depth_probability * vertical_probability
```

> 幻灯片文字：[code implementation example in the slides]（幻灯片中的代码实现示例）

> [游戏内渲染] in-game render

> Advances in Real-Time Rendering, Siggraph 2017

**EN:**
We do this by sampling our cloud at a low LOD level and then squaring the result to account for attenuation along the in-scatter path. However, you can see that it is too dark. This is because we are now saying that there is little to no in-scattering on the edges of clouds. Which of course, is incorrect.

**中:**
我们的做法是在较低的 LOD 层级上对云采样，然后把结果平方，以计入沿内散射路径的衰减。不过，你可以看到它变得太暗了。这是因为我们此刻等于在说：云的边缘上几乎没有内散射。这当然是错的。

---

## 第 91 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 云光照模型 / NUBIS | Cloud Lighting Model

> [游戏内渲染] / in-game render

> 幻灯片文字：`[幻灯片中的代码实现示例]` / `[code implementation example in the slides]`

```
depth_probability = 0.05 + pow( lodded_density, remap( height, 0.3, 0.85, 0.5, 2.0 ))
vertical_probability = pow( remap( height, 0.07, 0.14, 0.1, 1.0 ), 0.8 )
in-scatter_probability = depth_probability * vertical_probability
```

**EN:**
So, we also relax this effect over altitude and apply a small bias to compensate for this.

**中:**
所以，我们还让这一效果随高度逐渐放松，并施加一个小的偏置来补偿它。

**EN:**
In the slides you will see an example of how to ensure that this effect retains some directionality. This is an improvement over the purely directional result from the Powder Sugar function we offered in 2015.

**中:**
在幻灯片里你会看到一个示例，说明如何确保这一效果仍保留一定的方向性。这是对我们 2015 年给出的 Powder Sugar 函数那种纯方向性结果的改进。

## 第 92 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 云光照模型 / NUBIS | Cloud Lighting Model

> [游戏内渲染] / in-game render

> 幻灯片文字：`[幻灯片中的代码实现示例]` / `[code implementation example in the slides]`

```
depth_probability = 0.05 + pow( lodded_density, remap( height, 0.3, 0.85, 0.5, 2.0 ))
vertical_probability = pow( remap( height, 0.07, 0.14, 0.1, 1.0 ), 0.8 )
in-scatter_probability = depth_probability * vertical_probability
```

**EN:**
The second component accounts for The decrease in in-scattering over height. We represent this with a gradient. The range of this gradient depends, of course, on how you define your height gradients in the density model.

**中:**
第二个分量考虑了内散射随高度的递减。我们用一个梯度来表示它。这个梯度的范围，当然取决于你在密度模型中如何定义高度梯度。

**EN:**
We multiply both components to represent in-scattering probability.

**中:**
我们把两个分量相乘，来表示内散射概率。

**EN:**
Again, there will be full code examples for the lighting model in the slides.

**中:**
同样，幻灯片里会有光照模型的完整代码示例。

## 第 93 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 云光照模型 / NUBIS | Cloud Lighting Model

> [游戏内渲染] / in-game render

**EN:**
Additionally, one side note, we do not clamp any values in our lighting model. This allows support for HDR, which is a big thing for the PS4.

**中:**
另外，还有一个附注：我们的光照模型中不对任何值做钳制（clamp）。这样才能支持 HDR，而 HDR 对 PS4 来说是很重要的一件事。

## 第 94 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片图示文字：创作 / 系统 / 云 / 密度模型 / 云光照模型 / Ray March / 后处理
> Authoring / System / Cloud / Density Model / Cloud Lighting Model / Ray March / Post Process

> 幻灯片文字：NUBIS | Ray March 优化 / NUBIS | Ray-March Optimizations

**EN:**
The Lighting model and density model are actually functions which get called inside of the ray-march. I'm going to explain our Ray march at a high level and offer a code examples in the slides so that we can focus on how the optimizations that we made over a standard ray-march improved performance.

**中:**
光照模型和密度模型实际上都是在 ray marching 内部被调用的函数。我会从高层面上讲一讲我们的 ray marching，并在幻灯片里给出代码示例，这样我们就可以把重点放在：相比标准的 ray marching，我们所做的优化如何提升了性能。

## 第 95 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | Ray March 优化 / NUBIS | Ray-March Optimizations

> 幻灯片文字：`[幻灯片中的代码实现示例]` / `[code implementation example in the slides]`

**EN:**
Our ray march takes place in a spherical layer of atmosphere. The step count ranges between 54 and 96 samples depending on if the view ray is pointing up or to the horizon.

**中:**
我们的 ray marching 在一个球壳状的大气层中进行。步数在 54 到 96 个采样之间，取决于视线射线是指向上方天空还是指向地平线。

**EN:**
In the beginning of our ray-march we take large steps through the volume and sample only the low frequency noises at a low LOD level with our density sampler. We can get away with this because the high frequency cloud noises are applied as a subtraction to the edges of the low frequency noise.

**中:**
在 ray marching 的开头，我们以大步长穿过体积，并且只用密度采样器在低 LOD 级别上采样低频噪声。我们之所以可以这样做，是因为高频云噪声是以减法的方式作用在低频噪声的边缘上。

**EN:**
We then take short steps and sample using all of the frequencies of noise and related instructions.

**中:**
之后我们改用小步长，并使用所有频率的噪声及相关指令进行采样。

**EN:**
Once we have taken 10 samples in this manner which return zero density, we switch back to large steps and cheap samples until we reach an alpha value of 1 along the view ray or we reach the end of our spherical ray-march volume.

**中:**
一旦我们以这种方式连续取了 10 个返回零密度的采样，就切回大步长和廉价的采样，直到沿视线射线的 alpha 值达到 1，或者到达我们球壳 ray marching 体积的末端。

**EN:**
At each expensive sample, when the density is nonzero, we take 5 density samples in a light aligned cone to use in our lighting calculation, decreasing the LOD level for each sample. The cone sample and the decreasing LOD level have the effect of smoothing out the artifacts that you would normally get from taking only 5 light samples to light a dense volume.

**中:**
在每一个昂贵的采样点上，当密度不为零时，我们会在一个与光线对齐的锥体内取 5 个密度采样用于光照计算，并让每个采样的 LOD 级别递减。锥体采样加上递减的 LOD 级别，能平滑掉那种通常只用 5 个光照采样来照亮一个稠密体积时会出现的瑕疵。

## 第 96 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | Ray March 优化 / NUBIS | Ray-March Optimizations

**EN:**
The reason we are able to render our cloudscapes in 2ms is re-projection. You can look at the 2015 course for more information on this. One thing to keep in mind is that your cloud ray march must be fast enough so that all of the threads can produce pixels fast enough to prevent artifacts.

**中:**
我们之所以能在 2ms 内渲染出体积云景，靠的是重投影（re-projection）。你可以查看 2015 年的课程了解更多相关信息。有一点要记住：你的云 ray marching 必须足够快，快到让所有线程都能及时产出像素，从而避免瑕疵。

## 第 97 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | Ray March 优化 / NUBIS | Ray-March Optimizations

> [游戏内渲染（PS4）] / in-game render [ PS4 ]

> 幻灯片文字：
> - 基线 + 重投影 / Baseline + Reprojection —— 22 ms
> - LOD 与步长 / LOD & Step Size —— 8.1 ms
> - 只对非零密度做光照 / Only Light Nonzero Density —— 3.34 ms

**EN:**
As for the ray march optimizations, lets look at a typical scenario in our game. Clouds are partially obscured by the landscape and take up roughlyhalf of the screen.

**中:**
说到 ray marching 的优化，让我们看看游戏中一个典型场景。云被地形部分遮挡，大约占据半个屏幕。

**EN:**
Without any optimizations except temporal reprojection, Our shader takes 22ms to draw on the Standard PS4 Hardware.

**中:**
除了时域重投影之外不做任何优化时，我们的着色器在标准版 PS4 硬件上绘制需要 22ms。

**EN:**
As I add optimizations, the image will update. But as you will notice, there's no apparent difference in the clouds with each optimization.

**中:**
随着我逐项加入优化，画面会更新。但你会注意到，每加一项优化，云看上去并没有什么明显的差别。

**EN:**
When we introduce our Adaptive step size and LODing algorithm that number drops to 8.1

**中:**
当我们引入自适应步长（adaptive step size）和 LOD 算法后，这个数字降到 8.1。

**EN:**
When we are careful to only take light samples when we are inside of a cloud, that number drops to 3.34 ms

**中:**
当我们小心地只在云内部才取光照采样时，这个数字降到 3.34 ms。

**EN:**
In addition, we also made some optimizations before the ray-march even started. Lets exclude the geometry so that we can see the entire cloud layer.

**中:**
此外，我们还在 ray marching 开始之前就做了一些优化。让我们把几何体排除掉，这样就能看到整个云层。

## 第 98 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | Ray March 优化 / NUBIS | Ray-March Optimizations

> [游戏内渲染（PS4）] / in-game render [ PS4 ]

> 幻灯片文字：
> - Ray March 优化 / Ray-March Optimizations —— 3.34 ms
> - 剔除地平线以下 / Cull Below Horizon —— 1.81 ms
> - 深度剔除 / Depth Culling —— 1.2 ms

**EN:**
What we are looking at now is the raw result of the ray march and re-projection. You can see that the cloud sphere drops below the horizon and begins to tile noticeably.

**中:**
我们现在看到的是 ray marching 和重投影的原始结果。你可以看到云球体掉到了地平线以下，并且开始出现明显的平铺（tiling）。

**EN:**
Since we don't see anything below the vanishing point of our spherical cloud volume we can exclude the section in that area. This brings the render time down to 1.81 ms.

**中:**
既然在我们球状云体积的消失点以下什么都看不到，我们就可以把那块区域排除掉。这把渲染时间降到 1.81 ms。

**EN:**
Finally, we only start the ray march in areas of the frame where the sky is or has the potential to be un-occluded in the next frame.

**中:**
最后，我们只在画面中当前是天空、或者在下一帧有可能不再被遮挡的区域启动 ray marching。

**EN:**
However, thin occluders like trees could move across frame quickly enough to introduce reprojection artifacts. So, to prevent this we take a max() of a low lod sample of our depth channel. This ensures that we are conservative enough to prevent artifacts while reducing the number of ray-march steps. This brings the render time down to 1.2 ms

**中:**
不过，像树木这类很薄的遮挡物可能会以足够快的速度划过画面，从而引入重投影瑕疵。所以，为了防止这一点，我们对深度通道的一个低 lod 采样取 max()。这确保我们足够保守，能在减少 ray marching 步数的同时避免瑕疵。这把渲染时间降到 1.2 ms。

## 第 99 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片图示文字：创作 / 系统 / 云 / 密度模型 / 云光照模型 / Ray March / 后处理
> Authoring / System / Cloud / Density Model / Cloud Lighting Model / Ray March / Post Process

> 幻灯片文字：NUBIS | 后处理 / NUBIS | Post Processing

**EN:**
After we complete the ray march, we integrate its result into the frame using a post process shader.

**中:**
ray marching 完成之后，我们用一个后处理着色器把它的结果合成到画面中。

## 第 100 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 后处理 / NUBIS | Post Processing

> [游戏内渲染] / in-game render

> 幻灯片文字：
> - 红 = 直接光强度 / Red = Direct Light Intensity
> - 绿 = 大气混合因子 / Green = Atmospheric Blend Factor
> - 蓝 = 环境光强度 / Blue = Ambient Light Intensity
> - Alpha = Alpha

**EN:**
Back to our typical case…

**中:**
回到我们的典型场景……

**EN:**
• This is what comes out of our ray-march in the form of an RGBA buffer. Light intensity, Atmospheric haze blend factor, ambient light contribution and the alpha channel.

**中:**
• 这就是我们的 ray marching 以一个 RGBA 缓冲的形式输出的东西：光照强度、大气雾霾混合因子、环境光贡献，以及 alpha 通道。

**EN:**
• We have already discussed how we calculate our direct light intensity, but the atmospheric blend factor…

**中:**
• 我们已经讨论过直接光强度是怎么计算的，但大气混合因子……

## 第 101 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 后处理 / NUBIS | Post Processing

> [游戏内渲染] / in-game render

```
atmospheric_blend_factor = GetAtmosphere(depth, angle)
```

**EN:**
Is calculated in two steps.

**中:**
分两步计算。

**EN:**
• First, during the ray march, we create a depth value when the alpha channel has reached a value of .5.

**中:**
• 首先，在 ray marching 期间，当 alpha 通道达到 0.5 的值时，我们生成一个深度值。

**EN:**
Next, after the ray-march we sample the accumulated atmospheric scattering contribution at this depth.

**中:**
接着，在 ray marching 之后，我们在这个深度上采样累积的大气散射贡献。

**EN:**
We then use this value, which is stored in the Green channel of the cloud buffer,

**中:**
然后我们用这个值——它存储在云缓冲的 Green 通道中——

**EN:**
• as a blend factor between the color

**中:**
• 作为混合因子，在以下两者之间混合：

**EN:**
• of the clouds and the color of the sky.

**中:**
• 云的颜色与天空的颜色。

## 第 102 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 后处理 / NUBIS | Post Processing

> [游戏内渲染] / in-game render

**EN:**
To create the shafts of light that break through the clouds so dramatically in Bierstadt paintings, we referred to the work of Kenny Mitchell entitled, “Volumetric light scattering as a post process.”

**中:**
为了做出 Bierstadt 画作中那种极具戏剧性地穿透云层的光束，我们参考了 Kenny Mitchell 那篇题为《Volumetric light scattering as a post process》的工作。

## 第 103 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 后处理 / NUBIS | Post Processing

> [游戏内渲染] / in-game render

**EN:**
The fist step is to render a bright highlight around the sun where it is notoccluded by clouds. Then we offset this highlight radially away from the sun. Next we apply a radial blur on this image to create the light shafts intensity buffer.

**中:**
第一步是在太阳周围、未被云遮挡的地方渲染一个明亮的高光。然后我们把这个高光沿径向从太阳向外偏移。接着我们对这张图应用径向模糊，生成光束强度缓冲。

## 第 104 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 后处理 / NUBIS | Post Processing

> [游戏内渲染] / in-game render

**EN:**
Instead of adding this image directly to the scene like the original article suggests we use this intensity buffer as a mask when we apply the Mie scattering in our atmospheric scattering shader which is only applied a larger distances. This way the color and intensity of the light shafts will match with what you would expect from Mie scattering and the light shafts will not been drawn over close by scenery.

**中:**
我们没有像原文章建议的那样把这张图直接加到场景上，而是把这个强度缓冲当作一个遮罩，用在我们大气散射着色器里施加 Mie 散射的地方，而该散射只在较远的距离上施加。这样一来，光束的颜色和强度就会与你对 Mie 散射的预期相匹配，而且光束不会被画在近处的景物之上。

**EN:**
Additionally, the light shafts connect perfectly to our other volumetrics.

**中:**
此外，这些光束与我们其他的体积效果衔接得非常完美。

## 第 105 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 未来 / NUBIS | The Future

> [游戏内渲染] / in-game render

**EN:**
Hopefully what I have shared with you today has piqued your interest in rendering cloudscapes in real-time.

**中:**
希望我今天分享的内容，已经激起了你对实时渲染体积云景的兴趣。

**EN:**
When developing complex systems that mimic reality, we have to be bold like Howard was with his naming system and remember that eventually, on a long enough timeline, all obstacles will become features.

**中:**
在开发模仿现实的复杂系统时，我们必须像 Howard 给他的命名系统起名时那样大胆，并且记住：最终，在足够长的时间线上，所有障碍都会变成特性。

**EN:**
I had a saying while working on all of this:

**中:**
在做这一切的过程中，我有一句话：

**EN:**
Without care, you can make a procedural system that is excellent at generating ugly. The first time around, our goal should be to get to 80% not ugly. We feel like we got pretty close to this but there is still much to do.

**中:**
稍不留神，你就能做出一个非常擅长生成丑陋东西的程序化系统。第一轮，我们的目标应该是做到 80% 不丑。我们觉得自己已经相当接近这一点了，但还有很多事要做。

**EN:**
I feel good enough about where we are with a few of our tests to share some early experiments with you. Please remember that these do not reflect our idea of final quality and they ARE JUST experiments.

**中:**
我们对目前几个测试的进展感觉还不错，所以想和你们分享一些早期实验。请记住，这些并不代表我们心目中的最终品质，它们只是实验。

## 第 106 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 未来 / NUBIS | The Future

> [游戏内渲染] / in-game render

**EN:**
So rendering clouds in front of objects, close to the player with more detail, adding more distortion behaviors, and adding the remaining cloud layers… these are the things that really represent the next frontier for our work with Nubis and and we plan to present some of this to you next year.

**中:**
所以，在物体前方渲染云、在靠近玩家的地方用更多细节渲染云、加入更多扭曲行为（distortion behaviors），以及补上剩余的云层……这些才是我们 Nubis 工作真正要攻克的下一片前沿，我们计划明年向你们展示其中的一部分。

## 第 107 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：Rosa 和我们的孩子，以及家人。/ Rosa & our kids & and family.

**EN:**
I want to thank my wife and kids and my family we could be having dinner and a thought would pop into my head while I was looking at the mashed potatoes and I would bolt out of the room to dictate something into my phone. Thank you for tolerating me. Ik hou van jou.

**中:**
我要感谢我的妻子、孩子和我的家人。我们可能正在吃晚饭，我看着土豆泥的时候，脑子里突然冒出一个想法，然后我就会冲出房间，对着手机口述一些东西。谢谢你们包容我。Ik hou van jou。

## 第 108 页

> Advances in Real-Time Rendering, Siggraph 2017

> 幻灯片文字：NUBIS | 致谢与参考文献 / NUBIS | Thanks & References

> 幻灯片文字：感谢以下各位 / Thanks to:
> - Nathan Vos
> - Jan Bart van Beek
> - Marijn Giesbertz
> - Elco Vossers
> - Coen Klosters
> - Vlad Lopatin
> - Felix van den Bergh
> - Maarten van der Gaag
> - Hugh Malan
> - Giliam de Carpentier
> - Kevin Ortegren
> - Michal Valient
> - Michiel van der Leeuw
> - Hermen Hulst
> - Angie Smets
> - Kojima Productions

> 幻灯片文字：个人感谢 / Personal Thanks:
> - Trevor Thomson
> - Matthew Wilson
> - Matthew Roach
> - Carl Ludwig
> - Hugo Ayala
> - Donald Sajda & Jerry Ford
> - Joe Pasquale, Malcom Kesson, Clarke Stallworth
> - Tim McLaughlin
> - Natalya Tatarchuk
> - SideFX Software
> - Colleagues around the Game and VFX industry
> - The community

> 幻灯片文字：参考文献（按提及顺序）/ References: (in order of mention)
> - [Hamblyn, 2001] Richard Hamblyn, The Invention Of Clouds. New York: Picador Reprints., 2011.
> - [Peitgen & Richter, 1986] H.O. Peitgen & P.H. Richter, The Beauty of Fractals. Heidelberg: Springer-Verlag.,2011.
> - [Ludwig, 1990] Carl Ludwig, "Cumulus." http://www.blueskystudios.com., 1990.
> - [Simul, 2013] Simul, "TrueSKY." http://simul.co/truesky/. 2013.
> - [Reset, 2012] Theory Interactive Ltd., "Reset" http://reset-game.net/?p=284. 2012.
> - [Pretor-Pinney, 2007] Gavin Pretor-Pinney, The Cloudspotter's Guide. London: Sceptre., 2007.
> - [Schneider, 2015] A. Schneider. "The Real-Time Volumetric Cloudscapes Of Horizon: Zero Dawn". ACM SIGGRAPH. Los Angeles, CA: ACM SIGGRAPH, 2015. Web. 26 Aug. 2015.
> - [Hillaire, 2016] Sebastien Hillaire., "Tiling Volume Noise" https://github.com/sebh/TileableVolumeNoise. 2016.
> - [Clausse and Facy, 1961] R. Clausse and L. Facy, The Clouds. London: Evergreen Books LTD., 1961.
> - [Fiorani & Nova, 2013] Rfrancesca Fiorani & Alessandro Nova, Leonardo da Vinci and Optics. Venice: Marsilio Editori., 2013.
> - [Wrenninge, 2013] M. Wrenninge, Production Volume Rendering: Design and Implementation. CRC Press, 2013.
> - [Schneider 2016] Andrew Schneider, GPU Pro 7: Real Time Volumetric Cloudscapes. p.p. (97-128) CRC Press, 2016.
> - [Hillaire, 2016] Sebastien Hillaire., "Physically based Sky, Atmosphere and Cloud Rendering" https://www.ea.com/frostbite/news/physically-based-sky-atmosphere-and-cloud-rendering. 2016.
> - [Mitchell, 2007] Kenny Mitchell., "Volumetric Light Scattering as a Post Process", https://developer.nvidia.com/gpugems/GPUGems3/gpugems3_ch13.html. 2007.

**EN:**
• Thanks to my coworkers at Guerrilla and Kojima Productions,

**中:**
• 感谢我在 Guerrilla 和 Kojima Productions 的同事们，

**EN:**
• As well as others who have helped me over the years.

**中:**
• 以及这些年来帮助过我的其他人。

**EN:**
• Thanks to Natasha for allowing us to be part of the course again this year.

**中:**
• 感谢 Natasha 让我们今年再次参与这门课程。

**EN:**
Finally, thank you to members of the community. While we are pursuing a specific track with Nubis, the challenge of mastering clouds in general is a continuation of a very old human effort.

**中:**
最后，感谢社区里的各位。虽然我们在 Nubis 上走的是一条特定的路线，但总体上驾驭云这一挑战，是人类一项非常古老的努力的延续。

**EN:**
• Here are some of the references that I mentioned.

**中:**
• 这里是我提到过的一些参考文献。

**EN:**
• If you are interested reading more about clouds from a non-graphics perspective I recommend the references in bold.

**中:**
• 如果你有兴趣从非图形的角度更多地了解云，我推荐那些加粗的参考文献。

**EN:**
• If you are interested in the early ray-tracing work done by Carl Ludwig and others at Blue Sky, There is a panel happening down the hall this afternoon.

**中:**
• 如果你对 Carl Ludwig 和 Blue Sky 其他人早期做的光线追踪工作感兴趣，今天下午在走廊那头有一场专题讨论。

**EN:**
The slides for this should be online as soon as Natasha can upload them.

**中:**
这份讲座的幻灯片会在 Natasha 一上传后尽快放到网上。

**EN:**
Thank you for your time.

**中:**
感谢各位的时间。

**EN:**
I can take questions now.

**中:**
现在我可以接受提问了。
