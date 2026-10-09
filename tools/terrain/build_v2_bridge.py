"""从整平后的第二版无桥路网生成跨海桥。
在 Blender 中打开 source_art/terrain/超大地形v2_路网.blend 后运行。
保留无桥基线，另存完整桥梁源文件，导出游戏使用的桥梁路网模型和验收数据。
"""
import bpy, bmesh, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path("E:/GodotProjects/play-ground")
assert bpy.context.mode == 'OBJECT'
assert Path(bpy.data.filepath).name == "超大地形v2_路网.blend", "请从不含桥梁的整平路网源文件运行"
assert not bpy.data.collections.get("跨海桥"), "桥梁已存在，停止以免重复生成"
COL=bpy.data.collections.new("跨海桥")
bpy.context.scene.collection.children.link(COL)
terrain=bpy.data.objects["地形_整平-col"]
terrain.data=terrain.data.copy()
bvh=BVHTree.FromObject(terrain,bpy.context.evaluated_depsgraph_get())
def ground(x,y):
    p=bvh.ray_cast(Vector((float(x),float(y),1500)),Vector((0,0,-1)))[0]
    assert p is not None
    return p.z
def ease(t):
    t=max(0.,min(1.,t))
    return t*t*(3.-2.*t)
guide=bpy.data.objects["路线_08-noimp"].data.splines[0].points
anchor=min(guide,key=lambda p:(Vector(p.co[:2])-Vector((870,170))).length)
P=Vector(anchor.co[:3])
D=Vector((2100-P.x,-630-P.y,0))
L=D.length;D.normalize();N=Vector((-D.y,D.x,0))
B0,B1,DECK=360.,1180.,45.
Z0=P.z+.025
Z1=ground(2100,-630)+.14
def height(s):
    if s < B0: return Z0+(DECK-Z0)*ease((s-20)/(B0-20))
    if s <= B1: return DECK
    return DECK+(Z1-DECK)*ease((s-B1)/(L-B1-20))
def point(s,o=0,z=None):
    p=P+D*s+N*o;p.z=height(s) if z is None else z
    return tuple(p)
def mat(name,color,metal=0.,rough=.8):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bs.inputs["Base Color"].default_value=(*color,1)
    bs.inputs["Metallic"].default_value=metal;bs.inputs["Roughness"].default_value=rough
    return m
concrete=mat("桥梁_浅灰混凝土",(.34,.32,.27))
steel=mat("桥梁_深灰金属",(.10,.13,.14),.65,.45)
pavement=mat("桥梁_混凝土桥面",(.27,.255,.22))
marking=mat("桥梁_浅色边线",(.68,.62,.39))
roadmat=bpy.data.objects["道路_08-col"].data.materials[0]
shouldermat=bpy.data.objects["道路_08-col"].data.materials[1]
def mesh(name,verts,faces,mats,indices=None):
    m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update()
    for material in mats:m.materials.append(material)
    if indices:
        for p,i in zip(m.polygons,indices):p.material_index=i
    bm=bmesh.new();bm.from_mesh(m)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    bm.to_mesh(m);bm.free()
    obj=bpy.data.objects.new(name,m);COL.objects.link(obj)
    return obj
# 合并箱体网格，限制绘制调用和碰撞对象数量。
batches={}
def box(batch,s0,s1,o0,o1,z0,z1,material):
    v,f,ma=batches.setdefault(batch,([],[],material))
    k=len(v)
    v.extend([point(s,o,z) for z in (z0,z1) for s,o in ((s0,o0),(s1,o0),(s1,o1),(s0,o1))])
    f.extend([tuple(k+i for i in q) for q in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]])
def ribbon(name,s0,s1,width,materials):
    ss=np.linspace(s0,s1,math.ceil((s1-s0)/2)+1)
    offsets=[-width/2-1.6,-width/2,0,width/2,width/2+1.6]
    v=[];f=[];mi=[]
    for i,s in enumerate(ss):
        for j,o in enumerate(offsets):v.append(point(float(s),o,height(float(s))-(.05 if j in (0,4) else 0)))
        if i:
            for j in range(4):
                a=(i-1)*5+j;b=i*5+j
                f.extend([(a,b+1,a+1),(a,b,b+1)]);mi.extend([1 if j in (0,3) else 0]*2)
    return mesh(name,v,f,materials,mi)
ribbon("桥梁_主岛引道-col",0,B0,12,[roadmat,shouldermat])
ribbon("桥梁_副岛引道-col",B1,L,12,[roadmat,shouldermat])
# 连续桥面包含 12 米车道，两侧各预留 2 米边缘。
box("桥梁_桥面-col",B0,B1,-8,8,DECK-.65,DECK,pavement)
for o in (-4.8,0,4.8):
    box("桥梁_纵梁-col",B0,B1,o-.5,o+.5,DECK-3.6,DECK-.65,concrete)
pier_stations=np.linspace(B0,B1,13)
pier_report=[]
for s in pier_stations:
    for o in (-4.8,4.8):
        p=point(float(s),o);base=ground(p[0],p[1])-2.
        box("桥梁_桥墩-col",s-1.4,s+1.4,o-1.35,o+1.35,base,DECK-4.8,concrete)
        box("桥梁_基础-col",s-3.5,s+3.5,o-3.0,o+3.0,base-1.5,base+1.2,concrete)
    box("桥梁_盖梁-col",s-2.0,s+2.0,-7.6,7.6,DECK-5.8,DECK-3.6,concrete)
    pier_report.append({"station":float(s),"point":list(point(float(s))),"ground":ground(*point(float(s))[:2])})
# 桥台支撑抬高的引道路堤，并保留海峡通水空间。
for s in (B0,B1):
    base=min(ground(*point(s,o)[:2]) for o in (-9,0,9))-2.
    box("桥梁_桥台-col",s-2,s+2,-9,9,base,DECK-.65,concrete)
    for o in (-8.6,8.6):
        box("桥梁_桥台-col",s-10,s+10,o-.4,o+.4,base,DECK-.1,concrete)
# 连续实体护栏配合钢制扶手，避免玩家从间隙坠落。
for sign in (-1,1):
    o=sign*7.65
    box("桥梁_护栏-col",B0,B1,o-.23,o+.23,DECK,DECK+.85,concrete)
    box("桥梁_扶手-col",B0,B1,o-.12,o+.12,DECK+1.08,DECK+1.23,steel)
    for s in np.arange(B0+1,B1,8):
        box("桥梁_栏杆立柱-col",s-.10,s+.10,o-.10,o+.10,DECK+.85,DECK+1.15,steel)
    box("桥梁_边线",B0+3,B1-3,sign*6-.07,sign*6+.07,DECK+.012,DECK+.018,marking)
for s in pier_stations[1:-1]:
    box("桥梁_伸缩缝",s-.06,s+.06,-7.4,7.4,DECK+.006,DECK+.012,steel)
for name,(v,f,m) in batches.items():mesh(name,v,f,[m])
# 在副岛端生成小型平整落地点，并整平周围地形。
v=[point(L,0,Z1)]
for i in range(64):
    a=i*math.tau/64
    v.append(point(L+16*math.cos(a),16*math.sin(a),Z1))
mesh("桥梁_副岛落地点-col",v,[(0,1+i,1+(i+1)%64) for i in range(64)],[roadmat])

print("BRIDGE: grade approach terrain",flush=True)
def field(x,y,z):
    delta=Vector((x-P.x,y-P.y,0));s=delta.dot(D);o=abs(delta.dot(N))
    # 保持原路走廊，不移动任何已有道路。
    if s<12 or s>L+60 or (B0+2<s<B1-2):return z
    s0=max(0.,min(L,s))
    distance=math.hypot(o,max(0.,s-L))
    bench=8.8
    # 圆形落地点与原岛地形之间平滑过渡。
    end_distance=math.hypot(o,s-L)
    if s>L-25 and end_distance<60:
        distance=min(distance,max(0.,end_distance-7.2))
    target=height(s0)-.14
    if end_distance<16:target=Z1-.14
    blend=max(20.,abs(z-target)*1.8+8)
    w=(1-ease((distance-bench)/blend))*ease((s-12)/14)
    return z+(target-z)*w
# 只细分引道走廊；跨海桥身不改变海床。
bm=bmesh.new();bm.from_mesh(terrain.data)
edges=[]
for e in bm.edges:
    mid=(e.verts[0].co+e.verts[1].co)*.5
    delta=Vector((mid.x-P.x,mid.y-P.y,0));s=delta.dot(D);o=abs(delta.dot(N))
    if 8<s<L+70 and (s<B0+20 or s>B1-20) and o<85 and e.calc_length()>3:
        edges.append(e)
bmesh.ops.subdivide_edges(bm,edges=edges,cuts=6,use_grid_fill=True)
changed=0;cut=0.;fill=0.
for v in bm.verts:
    z=field(v.co.x,v.co.y,v.co.z)
    if abs(z-v.co.z)>.00001:
        changed+=1;cut=max(cut,v.co.z-z);fill=max(fill,z-v.co.z);v.co.z=z
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bmesh.ops.reverse_faces(bm,faces=[f for f in bm.faces if f.normal.z<0])
bm.to_mesh(terrain.data);bm.free();terrain.data.update()
for p in terrain.data.polygons:p.use_smooth=True
# 保存可编辑中心线及使用 Godot 坐标的紧凑验收数据。
curve=bpy.data.curves.new("跨海桥中心线",'CURVE');curve.dimensions='3D'
spline=curve.splines.new('POLY');samples=np.linspace(0,L,math.ceil(L/2)+1)
spline.points.add(len(samples)-1)
for p,s in zip(spline.points,samples):p.co=(*point(float(s)),1)
obj=bpy.data.objects.new("桥梁_中心线-noimp",curve);COL.objects.link(obj);obj.hide_render=True;obj.hide_set(True)
def godot(p):return [float(p[0]),float(p[2]),float(-p[1])]
report={"sea_level":15,"width":12,"deck_width":16,"length_m":L,"bridge_length_m":B1-B0,
        "bridge_stations":[B0,B1],"deck_height":DECK,"soffit_clearance_m":DECK-3.6-15,
        "max_grade":max(abs(height(float(b))-height(float(a)))/(b-a) for a,b in zip(samples,samples[1:])),
        "start":godot(point(0)),"end":godot(point(L)),"direction":[D.x,0,-D.y],
        "cross_direction":[N.x,0,-N.y],"max_cut":cut,"max_fill":fill,"graded_vertices":changed,
        "pier_count":len(pier_report),"samples":[{"station":float(s),"center":godot(point(float(s))),
          "left":godot(point(float(s),-5.4)),"right":godot(point(float(s),5.4))} for s in np.arange(1,L,4.17)]}
(ROOT/"source_art/terrain/桥梁数据.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.object.select_all(action='DESELECT')
for collection in (bpy.data.collections["路网"],COL):
    for o in collection.objects:
        if o.type=='MESH':o.hide_set(False);o.select_set(True)
bpy.context.view_layer.objects.active=terrain
print("BRIDGE: export combined roads, bridge and graded terrain",flush=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/"assets/models/terrain/超大地形v2_路网桥梁.glb"),
                        export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"source_art/terrain/超大地形v2_路网桥梁.blend"))
print("BRIDGE_COMPLETE "+json.dumps({k:v for k,v in report.items() if k!='samples'}),flush=True)
