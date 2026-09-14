"""Sample the exported skin, detecting right forearm/finger crossings of torso and hood."""
import bpy,json,sys
from pathlib import Path
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[3]
(ROOT/'build/archer').mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/monster__skeleton__archer__vari01_kings_raid.glb'))
scene=bpy.context.scene;rig=next(o for o in scene.objects if o.type=='ARMATURE');body=next(o for o in scene.objects if o.name.startswith('skeleton_body') and o.type=='MESH')
arrow=next(o for o in scene.objects if o.name=='arrow' and o.type=='MESH')
for t in rig.animation_data.nla_tracks:t.mute=True
moving={'forearm.R','hand.R'}|{b.name for b in rig.data.bones if b.name.endswith('.R') and any(b.name.startswith(s) for s in ['thumb','index','middle','ring','little'])}
obstacles={'hips','spine','chest','neck','head','jaw','clavicle.L','clavicle.R','skirt.L','skirt.R','tabard_front','tabard_back'}
groups={v.index:{body.vertex_groups[g.group].name for g in v.groups if g.weight>.001} for v in body.data.vertices}
polys=list(body.data.polygons)
arm_faces=[tuple(p.vertices) for p in polys if any(groups[i]&moving for i in p.vertices)]
body_faces=[tuple(p.vertices) for p in polys if any(groups[i]&obstacles for i in p.vertices) and not any(groups[i]&moving for i in p.vertices)]
arm_vids=sorted({i for p in arm_faces for i in p})
report={}
for clip,end in [('run',24),('draw',36),('shoot',30)]:
 active_moving=moving|{n[:-1]+'L' for n in moving} if clip=='run' else moving
 arm_faces=[tuple(p.vertices) for p in polys if any(groups[i]&active_moving for i in p.vertices)]
 body_faces=[tuple(p.vertices) for p in polys if any(groups[i]&obstacles for i in p.vertices) and not any(groups[i]&active_moving for i in p.vertices)]
 arm_vids=sorted({i for p in arm_faces for i in p})
 a=bpy.data.actions[clip];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0];hits=[];nearest=1e9;nearest_frame=0;headpaths=[];arrow_extent=0
 for step in range(end*2+1):
  f=step/2;scene.frame_set(int(f),subframe=f%1);dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);me=ev.to_mesh();points=[v.co.copy() for v in me.vertices]
  ba=BVHTree.FromPolygons(points,arm_faces,all_triangles=False);bb=BVHTree.FromPolygons(points,body_faces,all_triangles=False)
  crossing=ba.overlap(bb)
  if crossing:
   names=sorted({n for _,pi in crossing for vi in body_faces[pi] for n in groups[vi]})
   moving_regions=sorted({n for pi,_ in crossing for vi in arm_faces[pi] for n in groups[vi]})
   hits.append({'frame':f,'pairs':len(crossing),'body_regions':names,'moving_regions':moving_regions})
  for i in arm_vids:
   result=bb.find_nearest(points[i])
   if result[3] is not None and result[3]<nearest:nearest=result[3];nearest_frame=f
  headpaths.append({'frame':f,'wrist':[round(x,5) for x in rig.pose.bones['hand.R'].head],'elbow':[round(x,5) for x in rig.pose.bones['forearm.R'].head]})
  if clip=='run':
   arrow_ev=arrow.evaluated_get(dg);arrow_mesh=arrow_ev.to_mesh()
   extent=max(max(v.co[i] for v in arrow_mesh.vertices)-min(v.co[i] for v in arrow_mesh.vertices) for i in range(3))
   arrow_extent=max(arrow_extent,extent);arrow_ev.to_mesh_clear()
  ev.to_mesh_clear()
 report[clip]={'intersection_samples':len(hits),'intersections':hits,'min_surface_distance':nearest,'nearest_frame':nearest_frame,'wrist_elbow_path':headpaths}
 if clip=='run':report[clip]['max_arrow_extent_m']=arrow_extent
 print(clip,report[clip]['intersection_samples'],'intersection samples; min distance',round(nearest,6),'m at',nearest_frame,flush=True)
report['sampling_fps']=60;report['scope']='Right forearm, bracer, palm and fingers during draw/shoot, and both forearms/hands during run, versus torso clothing, armor, rib cage, neck and hood. Quiver pickup contact is intentionally excluded.'
label=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'clearance_report'
report['checks_passed']=all(report[c]['intersection_samples']==0 for c in ['run','draw','shoot']) and report['run']['max_arrow_extent_m']<.0002
(ROOT/'build/archer'/f'{label}.json').write_text(json.dumps(report,indent=2))
if label!='clearance_before':assert report['checks_passed'], 'Arm/torso crossing or visible arrow during run'
