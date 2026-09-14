"""Round-trip, render and measure the exported animation clips (not authoring curves)."""
import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3];QA=ROOT/'build/archer';QA.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/monster__skeleton__archer__vari01_kings_raid.glb'))
scene=bpy.context.scene;scene.render.fps=30
rig=next(o for o in scene.objects if o.type=='ARMATURE')
for t in rig.animation_data.nla_tracks:t.mute=True
acts={a.name.split('|')[0]:a for a in bpy.data.actions}
print('IMPORTED ACTIONS',list(acts),flush=True)
def action(name):
 a=next(a for a in bpy.data.actions if a.name==name or a.name.startswith(name+'_') or a.name.startswith(name+'|'))
 rig.animation_data.action=a
 if len(a.slots):rig.animation_data.action_slot=a.slots[0]
 return a
def snapshot(name,frame):
 action(name);scene.frame_set(frame);bpy.context.view_layer.update()
 return {pb.name:[float(v) for row in pb.matrix for v in row] for pb in rig.pose.bones}
def difference(a,b):return max(abs(x-y) for k in a for x,y in zip(a[k],b[k]))
report={'run_loop_max_matrix_delta':difference(snapshot('run',0),snapshot('run',24)),
        'draw_to_shoot_max_matrix_delta':difference(snapshot('draw',36),snapshot('shoot',0)),
        'shoot_to_draw_max_matrix_delta':difference(snapshot('shoot',30),snapshot('draw',0)),
        'actions':{a.name:[float(x) for x in a.frame_range] for a in bpy.data.actions},'bones':len(rig.data.bones),'foot_min_z':{}}
body=next(o for o in scene.objects if o.type=='MESH' and o.name.startswith('skeleton_body'))
for name,end in [('run',24),('draw',36),('shoot',30)]:
 action(name);mins=[]
 ids={}
 for side in ['L','R']:
  idx=body.vertex_groups['foot.'+side].index
  ids[side]=[v.index for v in body.data.vertices if any(g.group==idx and g.weight>.99 for g in v.groups)]
 for f in range(end+1):
  scene.frame_set(f);dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
  mins.append({s:min((body.matrix_world@mesh.vertices[i].co).z for i in ids[s]) for s in ids})
  ev.to_mesh_clear()
 report['foot_min_z'][name]={'min':min(min(m.values()) for m in mins),'frames':mins}
assert report['run_loop_max_matrix_delta']<1e-5, 'Run loop seam'
assert report['draw_to_shoot_max_matrix_delta']<1e-5, 'Draw/shoot transition'
assert report['shoot_to_draw_max_matrix_delta']<1e-5, 'Shoot/draw transition'
assert all(v['min']>-.0001 for v in report['foot_min_z'].values()), 'A foot penetrates the ground'
report['checks_passed']=True
(QA/'roundtrip_report.json').write_text(json.dumps(report,indent=2));print('ROUNDTRIP',json.dumps({k:v for k,v in report.items() if k!='foot_min_z'}),flush=True)
scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.render.resolution_x=480;scene.render.resolution_y=560;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
world=bpy.data.worlds.new('Studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.21,.29,1);world.node_tree.nodes['Background'].inputs[1].default_value=.55;scene.world=world
for n,p,power,size in [('Key',(2,-4,5),540,4),('Fill',(-3,-2,3),330,4),('Rim',(1,3,4),650,3)]:
 d=bpy.data.lights.new(n,'AREA');o=bpy.data.objects.new(n,d);scene.collection.objects.link(o);o.location=p;d.energy=power;d.shape='DISK';d.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012));floor=bpy.context.object;floor.name='review_ground';m=bpy.data.materials.new('review_ground');m.diffuse_color=(.055,.071,.092,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=m.diffuse_color;m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;floor.data.materials.append(m)
d=bpy.data.cameras.new('Review');cam=bpy.data.objects.new('Review',d);scene.collection.objects.link(cam);cam.location=(3,-4,2.45);cam.rotation_euler=(Vector((0,-.19,1.07))-cam.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=2.7;scene.camera=cam
mode=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'stills'
frames={'run':[0,3,6,9,12,15,18,21],'draw':[0,6,12,18,24,36],'shoot':[0,4,5,7,12,18,24,30]}
if mode in {'motion','run_motion'}:
 scene.render.resolution_x=320;scene.render.resolution_y=400;scene.cycles.samples=8
 cam.location=(-3,-4,2.5);cam.rotation_euler=(Vector((0,-.19,1.07))-cam.location).to_track_quat('-Z','Y').to_euler()
 frames={'run':list(range(24)),'draw':list(range(37)),'shoot':list(range(31))}
 if mode=='run_motion':frames={'run':list(range(24))}
if mode=='detail':
 scene.render.resolution_x=700;scene.render.resolution_y=760
 cam.location=(-3,-4,2.5);cam.rotation_euler=(Vector((0,-.19,1.07))-cam.location).to_track_quat('-Z','Y').to_euler()
 frames={'draw':[36],'shoot':[7,18]}
if mode=='correction':
 scene.render.resolution_x=520;scene.render.resolution_y=600
 cam.location=(-3,-4,2.5);cam.rotation_euler=(Vector((0,-.19,1.07))-cam.location).to_track_quat('-Z','Y').to_euler()
 frames={'run':[0,6,12,18],'draw':[0,15,24,36],'shoot':[7,16,19,22,25,28,30]}
for name,fs in frames.items():
 action(name)
 for f in fs:
  prefix='motion' if mode=='run_motion' else mode
  scene.frame_set(f);scene.render.filepath=str(QA/f'{prefix}_{name}_{f:03}.png');bpy.ops.render.render(write_still=True)
print('REVIEW DONE',flush=True)
