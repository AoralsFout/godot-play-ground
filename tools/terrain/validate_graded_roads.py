"""在 Blender 中检查实际路网网格的横向等高、纵坡和路口平整度。
需打开包含「路网」集合及对应中心线参考的源文件；只读取网格并输出验收结果。
"""
import bpy, math, json
from mathutils import Vector
maximum_cross_height=0.;maximum_grade=0.;maximum_grade_change=0.;sections=0
for obj in bpy.data.collections["路网"].objects:
    if obj.type!="MESH" or not obj.name.startswith("道路_"):continue
    if obj.name.startswith("道路_路口"):
        z=[v.co.z for v in obj.data.vertices]
        assert max(z)-min(z)<.001, obj.name+" junction not level"
        continue
    guide=bpy.data.objects[obj.name.replace("道路_","路线_").replace("-col","-noimp")]
    count=len(guide.data.splines[0].points)
    points=[Vector(p.co[:2]) for p in guide.data.splines[0].points]
    for i in range(1,len(points)-1):
        a=points[i]-points[i-1];b=points[i+1]-points[i]
        angle=a.angle(b,0)
        if angle>1e-5:
            radius=(a.length+b.length)*.5/angle
            assert radius>float(obj["路宽"])*.5+1.6, (obj.name,"road ribbon folds",radius)
    columns=len(obj.data.vertices)//count
    previous=None;previous_grade=None
    for i in range(count):
        row=obj.data.vertices[i*columns:(i+1)*columns]
        road_z=[v.co.z for v in row[1:-1]]
        maximum_cross_height=max(maximum_cross_height,max(road_z)-min(road_z))
        center=row[columns//2].co
        if previous is not None:
            distance=math.hypot(center.x-previous.x,center.y-previous.y)
            grade=(center.z-previous.z)/max(distance,1e-6)
            maximum_grade=max(maximum_grade,abs(grade))
            if previous_grade is not None:maximum_grade_change=max(maximum_grade_change,abs(grade-previous_grade))
            previous_grade=grade
        previous=center.copy();sections+=1
result={"sections":sections,"max_cross_height_m":maximum_cross_height,"max_longitudinal_grade":maximum_grade,"max_grade_change":maximum_grade_change}
assert maximum_cross_height<.001, result
assert maximum_grade<.1202, result
print("FLAT_ROAD_MESH_CHECK "+json.dumps(result),flush=True)
