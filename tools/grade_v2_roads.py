"""Grade the existing v2 roads and rebuild cut/fill terrain.
Run in Blender with 超大地形v2_路网.blend open. Reruns use the preserved original terrain.
"""
import bpy, bmesh, math, json
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT=Path("E:/GodotProjects/play-ground")
SOURCE=ROOT/"source_art/terrain/超大地形v2_路网.blend"
COL=bpy.data.collections["路网"]
assert bpy.context.mode=='OBJECT'
assert not bpy.data.collections.get('跨海桥'), '请先在无桥路网基线中整平道路，再运行 build_v2_bridge.py 重建桥头'
original=bpy.data.objects.get("地形_路网原始-noimp") or bpy.data.objects["地形-col"]
assert all(abs(original.matrix_world[i][j]-(1 if i==j else 0))<1e-5 for i in range(4) for j in range(4))
original.hide_set(False)
bvh=BVHTree.FromObject(original,bpy.context.evaluated_depsgraph_get())
def ground(x,y):
    p=bvh.ray_cast(Vector((x,y,1500)),Vector((0,0,-1)))[0]
    assert p is not None
    return p.z
def ease(t):
    t=max(0.,min(1.,t))
    return t*t*(3-2*t)

# Preserve the existing XY alignment. Collapse the first/last 12 m into a flat
# shared junction plateau. Shared endpoints have a single elevation variable.
print("GRADING: read centerlines",flush=True)
baseline=json.loads((ROOT/"source_art/terrain/路网数据.json").read_text(encoding="utf-8"))
baseline_xy=baseline.get("original_alignment_xy",{})
roads=[]
for obj in sorted(COL.objects,key=lambda o:o.name):
    if obj.type!='MESH' or obj.name.startswith("道路_路口") or not obj.name.startswith("道路_"): continue
    guide=bpy.data.objects[obj.name.replace("道路_","路线_").replace("-col","-noimp")]
    if obj.name not in baseline_xy:
        baseline_xy[obj.name]=[[float(p.co.x),float(p.co.y)] for p in guide.data.splines[0].points]
    xy=np.array(baseline_xy[obj.name],dtype=float)
    raw_distance=np.r_[0.,np.cumsum(np.linalg.norm(np.diff(xy,axis=0),axis=1))]
    # Broaden the old grid-route hairpins so a 12 m ribbon cannot fold over itself.
    kernel=np.exp(-.5*(np.arange(-72,73)/20.)**2);kernel/=kernel.sum()
    smoothed=np.column_stack([np.convolve(np.pad(xy[:,k],(72,72),mode="edge"),kernel,mode="valid") for k in range(2)])
    blend=np.array([ease(d/35.)*ease((raw_distance[-1]-d)/35.) for d in raw_distance])
    candidate=xy+(smoothed-xy)*blend[:,None]
    delta=np.diff(candidate,axis=0);segment_length=np.linalg.norm(delta,axis=1)
    angles=np.arccos(np.clip(np.sum(delta[:-1]*delta[1:],axis=1)/np.maximum(segment_length[:-1]*segment_length[1:],1e-12),-1.,1.))
    radius=(segment_length[:-1]+segment_length[1:])*.5/np.maximum(angles,1e-9)
    if min(radius)<float(obj["路宽"])*.5+2.:
        # An anchor-side U-turn can fold a wide ribbon. Correct endpoints of the
        # fair curve smoothly instead of mixing the tight original turn back in.
        t=raw_distance/raw_distance[-1];w=t*t*(3-2*t)
        candidate=smoothed+(xy[0]-smoothed[0])*(1-w[:,None])+(xy[-1]-smoothed[-1])*w[:,None]
    xy=candidate
    pts=[Vector(p) for p in xy]
    dist=[0.]
    for a,b in zip(pts,pts[1:]): dist.append(dist[-1]+(b-a).length)
    roads.append(dict(obj=obj,guide=guide,pts=pts,dist=dist,width=float(obj["路宽"])))
coords=[]; raw=[]; keys={}; rawsum=[]; rawcount=[]
for r in roads:
    ids=[]
    for i,p in enumerate(r["pts"]):
        if r["dist"][i]<12:
            key=("junction",round(r["pts"][0].x,3),round(r["pts"][0].y,3))
        elif r["dist"][-1]-r["dist"][i]<12:
            key=("junction",round(r["pts"][-1].x,3),round(r["pts"][-1].y,3))
        else: key=(r["obj"].name,i)
        if key not in keys:
            keys[key]=len(coords);coords.append(p);rawsum.append(0.);rawcount.append(0)
        idx=keys[key];ids.append(idx)
        rawsum[idx]+=ground(p.x,p.y)+.25;rawcount[idx]+=1
    r["ids"]=ids
raw=np.array(rawsum)/np.array(rawcount)
pairs={}
for r in roads:
    for i in range(1,len(r["ids"])):
        a,b=r["ids"][i-1:i+1]
        if a==b: continue
        edge=tuple(sorted((a,b)))
        pairs[edge]=max(.1,r["dist"][i]-r["dist"][i-1])
aa=np.array([p[0] for p in pairs],dtype=np.int32)
bb=np.array([p[1] for p in pairs],dtype=np.int32)
length=np.array(list(pairs.values()))
degree=np.bincount(np.r_[aa,bb],minlength=len(raw))
h=raw.copy()
# A weak data term preserves regional elevation while suppressing short bumps.
for _ in range(2400):
    sums=np.bincount(aa,weights=h[bb],minlength=len(h))+np.bincount(bb,weights=h[aa],minlength=len(h))
    h=(sums+.001*raw)/(degree+.001)
# Graph distance envelopes reserve headroom for smooth vertical curves (final cap 12%).
import heapq
neighbors=[[] for _ in h]
for a,b,d in zip(aa,bb,length):
    neighbors[a].append((int(b),float(d)*.07))
    neighbors[b].append((int(a),float(d)*.07))
def envelope(values):
    out=values.copy()
    queue=[(float(z),i) for i,z in enumerate(out)]
    heapq.heapify(queue)
    while queue:
        z,i=heapq.heappop(queue)
        if z>out[i]+1e-10:continue
        for j,cost in neighbors[i]:
            if out[j]>z+cost+1e-10:
                out[j]=z+cost;heapq.heappush(queue,(float(out[j]),j))
    return out
for cycle in range(4):
    h=(envelope(h)-envelope(-h))*.5
    if cycle<3:
        for _ in range(150):
            sums=np.bincount(aa,weights=h[bb],minlength=len(h))+np.bincount(bb,weights=h[aa],minlength=len(h))
            h=.5*h+.5*sums/degree
assert float(np.max(np.abs(h[bb]-h[aa])/length))<.0701
assert min(h)>17
print("GRADING: vertical profile solved",flush=True)
for r in roads:
    values=np.array([float(h[i]) for i in r["ids"]])
    distance=np.array(r["dist"])
    end=distance[-1]
    plateau=min(12.,end*.2)
    knot_s=np.linspace(plateau,end-plateau,max(1,round((end-2*plateau)/45.))+1)
    knot_z=np.interp(knot_s,distance,values)
    knot_z[0]=values[0];knot_z[-1]=values[-1]
    slope=np.diff(knot_z)/np.diff(knot_s)
    tangent=np.zeros(len(knot_s))
    for i in range(1,len(knot_s)-1):
        a,b=slope[i-1:i+1]
        if a*b>0:tangent[i]=2*a*b/(a+b)
    prof=[]
    for d in distance:
        if d<=plateau:z=values[0]
        elif d>=end-plateau:z=values[-1]
        else:
            i=min(len(knot_s)-2,max(0,int(np.searchsorted(knot_s,d)-1)))
            length=knot_s[i+1]-knot_s[i];t=(d-knot_s[i])/length
            z=(2*t**3-3*t*t+1)*knot_z[i]+(t**3-2*t*t+t)*length*tangent[i]+(-2*t**3+3*t*t)*knot_z[i+1]+(t**3-t*t)*length*tangent[i+1]
        prof.append(float(z))
    r["z"]=prof
    assert max(abs(prof[i+1]-prof[i])/(distance[i+1]-distance[i]) for i in range(len(prof)-1))<.1201, (r["obj"].name, max(abs(prof[i+1]-prof[i])/(distance[i+1]-distance[i]) for i in range(len(prof)-1)))


def replace_mesh(obj,verts,faces,material_indices=None):
    mats=list(obj.data.materials)
    mesh=bpy.data.meshes.new(obj.name+"_平整")
    mesh.from_pydata(verts,[],faces);mesh.update()
    for m in mats: mesh.materials.append(m)
    for i,p in enumerate(mesh.polygons):
        p.material_index=material_indices[i] if material_indices else 0
        p.use_smooth=True
    bm=bmesh.new();bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    down=[f for f in bm.faces if f.normal.z<0]
    if down: bmesh.ops.reverse_faces(bm,faces=down)
    bm.to_mesh(mesh);bm.free()
    old=obj.data;obj.data=mesh
    if old.users==0: bpy.data.meshes.remove(old)
    return mesh

# Flat cross-sections. Road shoulders drop 5 cm, never follow the hillside.
for r in roads:
    verts=[];faces=[];indices=[]
    w=r["width"]; offsets=[-w/2-1.6]+[-w/2+w*j/8 for j in range(9)]+[w/2+1.6]
    for i,p in enumerate(r["pts"]):
        tangent=(r["pts"][min(i+1,len(r["pts"])-1)]-r["pts"][max(i-1,0)]).normalized()
        normal=Vector((-tangent.y,tangent.x))
        for j,offset in enumerate(offsets):
            q=p+normal*offset
            verts.append((q.x,q.y,r["z"][i]-(.05 if j in (0,10) else 0)))
        if i:
            for j in range(10):
                a=(i-1)*11+j;b=i*11+j
                faces.extend([(a,b,b+1),(a,b+1,a+1)])
                indices.extend([1 if j in (0,9) else 0]*2)
    replace_mesh(r["obj"],verts,faces,indices)
    r["obj"]["生成方式"]="横向等高 / 纵向限坡 / 削坡填方"
    for p,z,control in zip(r["pts"],r["z"],r["guide"].data.splines[0].points):
        control.co=(p.x,p.y,z,1)

for obj in COL.objects:
    if obj.type!='MESH' or not obj.name.startswith("道路_路口"): continue
    center=obj.data.vertices[0].co
    key=min((k for k in keys if k[0]=="junction"),key=lambda k:(k[1]-center.x)**2+(k[2]-center.y)**2)
    z=float(h[keys[key]])+.015
    verts=[(v.co.x,v.co.y,z) for v in obj.data.vertices]
    faces=[tuple(p.vertices) for p in obj.data.polygons]
    replace_mesh(obj,verts,faces)

# A spatial road surface field controls both the roadbed and its cut/fill slopes.
entries=[]
for ri,r in enumerate(roads):
    for i,p in enumerate(r["pts"]): entries.append((ri,i,p))
tree=KDTree(len(entries))
for idx,(_,_,p) in enumerate(entries):tree.insert((p.x,p.y,0),idx)
tree.balance()
def field(x,y,original_z):
    _,idx,d=tree.find((x,y,0))
    if d>100: return original_z,0.
    candidates={}
    for _,idx,_ in tree.find_n((x,y,0),6):
        ri,i,_=entries[idx];r=roads[ri]
        for k in (i-1,i):
            if k<0 or k>=len(r["pts"])-1 or (ri,k) in candidates:continue
            a,b=r["pts"][k:k+2];dx=b.x-a.x;dy=b.y-a.y
            t=max(0.,min(1.,((x-a.x)*dx+(y-a.y)*dy)/max(dx*dx+dy*dy,1e-12)))
            distance=math.hypot(x-a.x-t*dx,y-a.y-t*dy)
            z=r["z"][k]*(1-t)+r["z"][k+1]*t-.14
            bench=r["width"]/2+2.5
            blend=max(18.,abs(original_z-z)*2.0+8.)
            weight=1.-ease((distance-bench)/blend)
            candidates[ri,k]=(distance,z,weight,bench)
    nearest_by_road={}
    for (ri,_),c in candidates.items():
        if ri not in nearest_by_road or c[0]<nearest_by_road[ri][0]:
            nearest_by_road[ri]=c
    active=[c for c in nearest_by_road.values() if c[2]>0]
    if not active:return original_z,0.
    # Where branch roadbeds overlap, the lowest pavement wins to prevent clipping.
    inside=[c for c in active if c[0]<=c[3]]
    if inside:return min(c[1] for c in inside),1.
    weights=[c[2]/max(1e-8,1-c[2]) for c in active]
    z=(original_z+sum(c[1]*w for c,w in zip(active,weights)))/(1+sum(weights))
    return z,max(c[2] for c in active)

# Rebuild from the immutable source, not from last run's cut/fill surface.
print("GRADING: rebuild roadbed terrain",flush=True)
existing=bpy.data.objects.get("地形_整平-col")
if existing:
    old=existing.data;bpy.data.objects.remove(existing,do_unlink=True)
    if old.users==0:bpy.data.meshes.remove(old)
evaluated=original.evaluated_get(bpy.context.evaluated_depsgraph_get())
mesh=bpy.data.meshes.new_from_object(evaluated,preserve_all_data_layers=True,depsgraph=bpy.context.evaluated_depsgraph_get())
graded=bpy.data.objects.new("地形_整平-col",mesh);COL.objects.link(graded)
bm=bmesh.new();bm.from_mesh(mesh)
influence={}
for v in bm.verts:
    _,influence[v]=field(v.co.x,v.co.y,v.co.z)
selected=[edge for edge in bm.edges if any(influence[v]>0 for v in edge.verts)]
# Local ~2 m tessellation is necessary: the original ~13 m terrain cells are wider
# than a lane and can otherwise poke through an analytically flattened roadbed.
print("GRADING: subdividing %d edges"%len(selected),flush=True)
bmesh.ops.subdivide_edges(bm,edges=selected,cuts=6,use_grid_fill=True)
print("GRADING: sampling %d terrain vertices"%len(bm.verts),flush=True)
changed=0;max_cut=0.;max_fill=0.
for v in bm.verts:
    z,weight=field(v.co.x,v.co.y,v.co.z)
    if weight>0:
        max_cut=max(max_cut,v.co.z-z);max_fill=max(max_fill,z-v.co.z)
        v.co.z=z;changed+=1
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bmesh.ops.reverse_faces(bm,faces=[f for f in bm.faces if f.normal.z<0])
bm.to_mesh(mesh);bm.free();mesh.update()
for poly in mesh.polygons:poly.use_smooth=True
original.name="地形_路网原始-noimp";original.hide_render=True;original.hide_set(True)
graded["生成方式"]="路基等高平台 / 两侧平滑削坡填方"
# Keep materials and original data in the editable scene. Only roads + graded
# terrain are exported; Godot disables the superseded base terrain and collision.
bpy.ops.object.select_all(action='DESELECT')
for obj in COL.objects:
    if obj.type=='MESH':obj.select_set(True)
bpy.context.view_layer.objects.active=graded
print("GRADING: export",flush=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/"assets/models/超大地形v2_路网.glb"),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
report=json.loads((ROOT/"source_art/terrain/路网数据.json").read_text(encoding='utf-8'))
report["original_alignment_xy"]=baseline_xy
report["length_m"]=sum(r["dist"][-1] for r in roads)
report.update(surface_mode="graded",max_center_grade=max(abs(r["z"][i+1]-r["z"][i])/(r["dist"][i+1]-r["dist"][i]) for r in roads for i in range(len(r["z"])-1)),max_cross_height=0.,
              min_center_height=float(min(h)),max_cut_m=max_cut,max_fill_m=max_fill,graded_vertices=changed)
for route,r in zip(report["routes"],roads):
    route["length"]=r["dist"][-1]
    route["samples"]=[[float(p.x),z,float(-p.y)] for p,z in zip(r["pts"][::max(1,len(r["pts"])//25)],r["z"][::max(1,len(r["pts"])//25)])]
    route["cross_sections"]=[]
    for i in range(1,len(r["pts"])-1,max(1,len(r["pts"])//40)):
        p=r["pts"][i]; tangent=(r["pts"][min(i+1,len(r["pts"])-1)]-r["pts"][max(0,i-1)]).normalized()
        n=Vector((-tangent.y,tangent.x));a=p-n*(r["width"]*.45);b=p+n*(r["width"]*.45)
        route["cross_sections"].append([[float(a.x),r["z"][i],float(-a.y)],[float(b.x),r["z"][i],float(-b.y)]])
(ROOT/"source_art/terrain/路网数据.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
bpy.ops.object.select_all(action='DESELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
result={k:report[k] for k in ["surface_mode","max_center_grade","max_cross_height","min_center_height","max_cut_m","max_fill_m","graded_vertices"]}

print("GRADING_COMPLETE "+json.dumps(result),flush=True)
