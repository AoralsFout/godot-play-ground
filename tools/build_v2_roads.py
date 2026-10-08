"""Build a connected, terrain-conforming road overlay for the current v2 island.
Run in Blender with the original v2 scene open. Coordinates are Blender XY / Z-up.
"""
import bpy, math, heapq, json
from pathlib import Path
from mathutils import Vector, Quaternion
from mathutils.bvhtree import BVHTree

ROOT = Path("E:/GodotProjects/play-ground")
SOURCE = ROOT / "source_art/terrain/超大地形v2_路网.blend"
EXPORT = ROOT / "assets/models/超大地形v2_路网.glb"
REPORT = ROOT / "source_art/terrain/路网数据.json"
assert bpy.context.mode == 'OBJECT'
assert not bpy.data.collections.get("路网"), "Road network already exists; undo/remove the generated collection before rebuilding."
terrain = bpy.data.objects["地形-col"]
bvh = BVHTree.FromObject(terrain, bpy.context.evaluated_depsgraph_get())
def height(x, y):
    p = bvh.ray_cast(Vector((x,y,1500)), Vector((0,0,-1)))[0]
    return p.z if p is not None else -1000.0

# Block landmarks and placed vegetation, including particle instances.
obstacles = []
for inst in bpy.context.evaluated_depsgraph_get().object_instances:
    obj = inst.object
    if not (obj.name.startswith(("塔_", "巨构肋柱_", "树木", "石头"))):
        continue
    points = [inst.matrix_world @ Vector(v) for v in obj.bound_box]
    lo = [min(p[i] for p in points) for i in range(3)]
    hi = [max(p[i] for p in points) for i in range(3)]
    if hi[2] < 15: continue
    obstacles.append((lo[0], hi[0], lo[1], hi[1]))
def blocked(x,y, margin=20):
    return any(a-margin<x<b+margin and c-margin<y<d+margin for a,b,c,d in obstacles)

STEP = 25.0
cache = {}
def sample(cell):
    if cell not in cache:
        x,y = cell[0]*STEP, cell[1]*STEP
        h = height(x,y)
        valid = abs(x)<3600 and abs(y)<3600 and h>22 and not blocked(x,y)
        if valid:
            hs = [height(x+dx,y+dy) for dx,dy in [(8,0),(-8,0),(0,8),(0,-8)]]
            valid = min(hs)>20 and max(abs(z-h) for z in hs)<4.0
        cache[cell]=(h,valid)
    return cache[cell]
def snap(x,y):
    center=(round(x/STEP),round(y/STEP))
    choices=[(center[0]+i,center[1]+j) for i in range(-8,9) for j in range(-8,9)]
    choices.sort(key=lambda p:(p[0]*STEP-x)**2+(p[1]*STEP-y)**2)
    return next(c for c in choices if sample(c)[1])
def route(a,b):
    queue=[(0,a)]
    costs={a:0.0}; came={}
    while queue:
        _,p=heapq.heappop(queue)
        if p==b:
            path=[p]
            while p in came:
                p=came[p]; path.append(p)
            return list(reversed(path))
        h=sample(p)[0]
        for dx,dy in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(1,-1),(-1,1),(-1,-1)]:
            n=(p[0]+dx,p[1]+dy)
            z,valid=sample(n)
            if not valid: continue
            dist=STEP*math.hypot(dx,dy)
            grade=abs(z-h)/dist
            if grade>0.25: continue
            # Check halfway too: do not jump a narrow inlet or a steep ridge.
            mx,my=(p[0]+n[0])*STEP/2,(p[1]+n[1])*STEP/2
            mh=height(mx,my)
            if mh<21 or abs(mh-(h+z)/2)>2.0 or blocked(mx,my): continue
            cost=costs[p]+dist*(1+35*grade*grade+max(0,z-200)/220)
            if cost < costs.get(n,math.inf):
                costs[n]=cost; came[n]=p
                heapq.heappush(queue,(cost+STEP*math.hypot(n[0]-b[0],n[1]-b[1]),n))
    raise RuntimeError("No dry low-gradient path: "+str((a,b)))

anchors = {
 "遗迹入口":snap(-500,-900), "西南高地":snap(-1400,-2400),
 "西岸":snap(-2450,-1300), "西北山麓":snap(-1750,350),
 "北部山麓":snap(0,1550), "东岸":snap(1000,750),
 "东南缓坡":snap(500,-300), "北部半岛":snap(-1400,2700),
 "南端":snap(-700,-2800), "塔群入口":snap(-400,-910),
}
ring=["遗迹入口","西南高地","西岸","西北山麓","北部山麓","东岸","东南缓坡","遗迹入口"]
requests=[(ring[i],ring[i+1],12.0) for i in range(len(ring)-1)]
requests += [("西北山麓","北部半岛",8.0),("西南高地","南端",8.0),("遗迹入口","塔群入口",7.0)]
# Merge shared A* edges, so routes never stack duplicate surfaces.
edges={}
for a,b,w in requests:
    path=route(anchors[a],anchors[b])
    for p,q in zip(path,path[1:]):
        edge=tuple(sorted((p,q)))
        edges[edge]=max(w,edges.get(edge,0))
adj={}
for (p,q),w in edges.items():
    adj.setdefault(p,[]).append(q); adj.setdefault(q,[]).append(p)
# Split at real junctions / changes in width, then soften each continuous run.
breaks={p for p,ns in adj.items() if len(ns)!=2 or len({edges[tuple(sorted((p,n)))] for n in ns})>1}
seen=set(); chains=[]
for start in sorted(breaks):
    for nxt in adj[start]:
        edge=tuple(sorted((start,nxt)))
        if edge in seen: continue
        seen.add(edge); chain=[start,nxt]; prev,cur=start,nxt
        while cur not in breaks:
            n=next(n for n in adj[cur] if n!=prev)
            seen.add(tuple(sorted((cur,n)))); chain.append(n); prev,cur=cur,n
        chains.append((chain,edges[edge]))

collection=bpy.data.collections.new("路网")
bpy.context.scene.collection.children.link(collection)
def material(name,color,roughness=0.9):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1)
    m.use_nodes=True
    bsdf=next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value=(*color,1)
    bsdf.inputs["Roughness"].default_value=roughness
    return m
road_mat=material("路网_风化砂石",(0.32,0.255,0.16))
shoulder_mat=material("路网_压实路肩",(0.23,0.20,0.13))
def make_mesh(name,vertices,faces,mats,indices):
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(vertices,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); collection.objects.link(obj)
    for mat in mats: mesh.materials.append(mat)
    for poly,idx in zip(mesh.polygons,indices): poly.material_index=idx
    return obj

total_length=0; max_grade=0; min_height=999; routes=[]
for number,(cells,width) in enumerate(chains,1):
    points=[Vector((p[0]*STEP,p[1]*STEP)) for p in cells]
    # Corner cutting keeps endpoints fixed and replaces grid stair-steps by broad bends.
    for _ in range(3):
        smooth=[points[0]]
        for a,b in zip(points,points[1:]):
            smooth.extend([a.lerp(b,.25),a.lerp(b,.75)])
        smooth.append(points[-1]); points=smooth
    # Resample at <= 2 m, following the actual evaluated terrain on every cross-section.
    samples=[points[0]]
    cumulative=0.0
    next_distance=2.0
    for a,b in zip(points,points[1:]):
        length=(b-a).length
        if length<1e-6: continue
        while next_distance<=cumulative+length:
            samples.append(a.lerp(b,(next_distance-cumulative)/length))
            next_distance+=2.0
        cumulative+=length
    if (samples[-1]-points[-1]).length<0.5:
        samples[-1]=points[-1]
    else:
        samples.append(points[-1])
    verts=[]; faces=[]; indices=[]
    # The outer edge sinks into the terrain; inner road sits only 20 cm above it.
    offsets=[-width/2-1.6]+[-width/2+width*j/8 for j in range(9)]+[width/2+1.6]
    distances=[0]
    for i,p in enumerate(samples):
        tangent=(samples[min(i+1,len(samples)-1)]-samples[max(0,i-1)]).normalized()
        normal=Vector((-tangent.y,tangent.x))
        h=height(p.x,p.y); min_height=min(min_height,h)
        if i:
            d=(p-samples[i-1]).length
            if d>1e-5:
                max_grade=max(max_grade,abs(h-height(samples[i-1].x,samples[i-1].y))/d)
                distances.append(distances[-1]+d)
            else: distances.append(distances[-1])
        for j,offset in enumerate(offsets):
            q=p+normal*offset
            z=height(q.x,q.y)+(0.015 if j in (0,len(offsets)-1) else .20)
            assert z>15.5, "Road touches sea"
            assert not blocked(q.x,q.y,0.5), "Road intersects a landmark"
            verts.append((q.x,q.y,z))
        if i:
            for j in range(len(offsets)-1):
                a=(i-1)*len(offsets)+j; b=i*len(offsets)+j
                # Up-facing triangles in Blender; terrain-conforming center rows reduce clipping.
                faces.extend([(a,b,b+1),(a,b+1,a+1)])
                indices.extend([1 if j in (0,len(offsets)-2) else 0]*2)
    name="道路_%02d-col"%number
    obj=make_mesh(name,verts,faces,[road_mat,shoulder_mat],indices)
    obj["路宽"]=width; obj["生成方式"]="地形采样 / 连通路网"
    # Store editable centerline guides without importing them into the engine.
    curve=bpy.data.curves.new("路线_%02d"%number,'CURVE'); curve.dimensions='3D'
    spline=curve.splines.new('POLY'); spline.points.add(len(samples)-1)
    for v,p in zip(spline.points,samples): v.co=(p.x,p.y,height(p.x,p.y)+.3,1)
    guide=bpy.data.objects.new("路线_%02d-noimp"%number,curve); collection.objects.link(guide)
    guide.hide_render=True; guide.hide_set(True)
    total_length+=distances[-1]
    routes.append({"name":name,"width":width,"length":round(distances[-1],2),
                   "samples":[[round(p.x,3),round(height(p.x,p.y)+.20,3),round(-p.y,3)] for p in samples[::max(1,len(samples)//25)]]})

# Fill branch junctions; they sit two cm above road surfaces, avoiding coplanar flicker.
for number,p in enumerate(sorted(breaks),1):
    if len(adj[p])<2: continue
    x,y=p[0]*STEP,p[1]*STEP
    radius=max(edges[tuple(sorted((p,n)))] for n in adj[p])/2+1.6
    verts=[(x,y,height(x,y)+.22)]
    for ring in range(1,9):
        for i in range(32):
            a=2*math.pi*i/32
            xx,yy=x+radius*ring/8*math.cos(a),y+radius*ring/8*math.sin(a)
            verts.append((xx,yy,height(xx,yy)+.22))
    faces=[(0,i+1,(i+1)%32+1) for i in range(32)]
    for ring in range(7):
        for i in range(32):
            a=1+ring*32+i; b=1+ring*32+(i+1)%32
            faces.extend([(a,a+32,b+32),(a,b+32,b)])
    make_mesh("道路_路口_%02d-col"%number,verts,faces,[road_mat],[0]*len(faces))

# Normals should face up regardless of path direction.
for obj in collection.objects:
    if obj.type=='MESH':
        import bmesh
        bm=bmesh.new(); bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        downward=[f for f in bm.faces if f.normal.z<0]
        if downward: bmesh.ops.reverse_faces(bm,faces=downward)
        bm.to_mesh(obj.data); bm.free()

report={"sea_level":15,"length_m":round(total_length,2),"max_center_grade":round(max_grade,4),
        "min_center_height":round(min_height,3),"route_count":len(routes),
        "anchors":{name:[p[0]*STEP,sample(p)[0],-p[1]*STEP] for name,p in anchors.items()},
        "routes":routes}
REPORT.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.object.select_all(action='DESELECT')
for obj in collection.objects:
    if obj.type=='MESH': obj.select_set(True)
bpy.context.view_layer.objects.active=next(o for o in collection.objects if o.type=='MESH')
bpy.ops.export_scene.gltf(filepath=str(EXPORT),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
result={k:v for k,v in report.items() if k not in ['routes','anchors']}
result['source']=str(SOURCE);result['export']=str(EXPORT)
