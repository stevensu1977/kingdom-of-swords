import bpy, json, os
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
QA=ROOT/'build/archer'
QA.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
p=ROOT/'assets/models/monster__skeleton__archer__vari01_kings_raid.glb'
source=(Path(__file__).resolve().parents[1]/'assets/source/archer_static.blend')
if source.exists():
 bpy.ops.wm.open_mainfile(filepath=str(source.resolve()))
else:
 bpy.ops.import_scene.gltf(filepath=str(p.resolve()), merge_vertices=True)
 if any(o.type=='ARMATURE' for o in bpy.data.objects):
  raise RuntimeError('The original static authoring source is required; do not replace it with an animated export.')
bpy.context.preferences.filepaths.save_version=0
print('BLENDER',bpy.app.version_string)
meshes=[]
for o in list(bpy.data.objects):
 if o.type=='MESH':
  mw=o.matrix_world.copy(); o.parent=None; o.matrix_world=mw
  bpy.context.view_layer.objects.active=o; o.select_set(True)
  bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
  o.select_set(False); meshes.append(o)
for o in list(bpy.data.objects):
 if o.type=='EMPTY': bpy.data.objects.remove(o,do_unlink=True)
report={}
for o in meshes:
 vs=o.data.vertices
 lo=[min(v.co[i] for v in vs) for i in range(3)]; hi=[max(v.co[i] for v in vs) for i in range(3)]
 links={v.index:[] for v in vs}
 for e in o.data.edges:
  a,b=e.vertices; links[a].append(b); links[b].append(a)
 comps=[]; seen=set()
 for v in vs:
  if v.index in seen: continue
  stack=[v.index]; seen.add(v.index); ids=[]
  while stack:
   u=stack.pop();ids.append(u)
   for nb in links[u]:
    if nb not in seen: seen.add(nb);stack.append(nb)
  points=[vs[i].co for i in ids]
  comps.append({'id':len(comps),'n':len(ids),'lo':[round(min(v[i] for v in points),5) for i in range(3)],'hi':[round(max(v[i] for v in points),5) for i in range(3)],'center':[round(sum(v[i] for v in points)/len(points),5) for i in range(3)],'vertices':ids})
 report[o.name]={'bounds':[lo,hi],'components':comps,'vertices':[[round(x,6) for x in v.co] for v in vs]}
 print('OBJECT',o.name,len(vs),lo,hi)
 for c in comps: print({k:v for k,v in c.items() if k!='vertices'})
(Path(__file__).resolve().parents[3]/'build/archer/geometry.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str((Path(__file__).resolve().parents[1]/'assets/source/archer_static.blend').resolve()))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.world=bpy.data.worlds.new('Studio');scene.world.color=(.28,.28,.28)
scene.render.resolution_x=950;scene.render.resolution_y=950;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
for name,loc,power,size in [('Key',(3,-4,5),420,5),('Fill',(-3,1,3),250,4),('Rim',(1,4,4),320,3)]:
 d=bpy.data.lights.new(name,'AREA');o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;d.energy=power;d.shape='DISK';d.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
for name,pos in [('front',(0,-6,1)),('back',(0,6,1)),('side',(6,0,1)),('quarter',(3,-5,2.5))]:
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=2.9;scene.camera=o
 scene.render.filepath=str((Path(__file__).resolve().parents[3]/'build/archer'/('static_'+name+'.png')).resolve());bpy.ops.render.render(write_still=True)
