"""Rig the supplied static skeleton archer and author run/draw/shoot in metres.
Run: blender -b --python tools/archer/tools/animate_archer.py
The preserved authoring source is tools/archer/assets/source/archer_static.blend.
"""
import bpy, math, json, bmesh
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
from math import sin, cos, pi, radians
ROOT=Path(__file__).resolve().parents[3]
ASSET=ROOT/'assets/models/monster__skeleton__archer__vari01_kings_raid.glb'
SOURCE=ROOT/'tools/archer/assets/source/archer_static.blend'
QA=ROOT/'build/archer';QA.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
bpy.context.preferences.filepaths.save_version=0
scene=bpy.context.scene;scene.render.fps=30
originals=sorted([o for o in scene.objects if o.type=='MESH'],key=lambda o:o.name)
for o in list(scene.objects):
 if o not in originals: bpy.data.objects.remove(o,do_unlink=True)
# Keep the original metres and orientation. Raise the original soles by 3.34 mm.
DZ=-min(v.co.z for o in originals for v in o.data.vertices)
def V(p): return Vector((p[0],p[1],p[2]+DZ))
def components(o):
 links=[[] for _ in o.data.vertices]
 for e in o.data.edges:
  a,b=e.vertices;links[a].append(b);links[b].append(a)
 seen=set();out=[]
 for v in o.data.vertices:
  if v.index in seen:continue
  stack=[v.index];seen.add(v.index);ids=[]
  while stack:
   a=stack.pop();ids.append(a)
   for b in links[a]:
    if b not in seen:seen.add(b);stack.append(b)
  out.append(ids)
 return out
comps=[components(o) for o in originals]
for o in originals:
 for v in o.data.vertices:v.co.z+=DZ
 o.data.update()
# Bone specifications use model-space coordinates, so rigid bone islands stay intact.
spec={}
def bone(name,h,t,parent=None,roll=None):spec[name]=(V(h),V(t),parent,roll)
bone('root',(0,0,0),(0,0,.18))
bone('hips',(0,-.025,.94),(0,-.025,1.10),'root')
bone('spine',(0,-.025,1.10),(0,-.03,1.25),'hips')
bone('chest',(0,-.03,1.25),(0,-.03,1.43),'spine')
bone('neck',(0,-.03,1.43),(0,-.055,1.55),'chest')
bone('head',(0,-.055,1.55),(0,-.055,1.77),'neck')
bone('jaw',(0,-.10,1.59),(0,-.17,1.55),'head')
bone('quiver',(-.02,.17,1.20),(-.19,.17,1.63),'chest')
bone('tabard_front',(0,-.12,.96),(0,-.14,.48),'hips')
bone('tabard_back',(0,.13,.96),(0,.17,.68),'hips')
for side,s in [('L',1),('R',-1)]:
 bone('clavicle.'+side,(s*.055,-.03,1.415),(s*.235,-.025,1.395),'chest')
 bone('upper_arm.'+side,(s*.235,-.025,1.395),(s*.490,-.02,1.207),'clavicle.'+side)
 bone('forearm.'+side,(s*.490,-.02,1.207),(s*.742,-.029,1.034),'upper_arm.'+side)
 bone('hand.'+side,(s*.742,-.029,1.034),(s*.840,-.045,.960),'forearm.'+side)
 bone('thigh.'+side,(s*.105,-.023,.895),(s*.158,-.003,.516),'hips')
 bone('shin.'+side,(s*.158,-.003,.516),(s*.197,.077,.203),'thigh.'+side)
 bone('foot.'+side,(s*.197,.077,.203),(s*.208,-.12,.060),'shin.'+side)
 bone('skirt.'+side,(s*.14,-.01,.96),(s*.24,-.01,.70),'hips')
# Separate finger chains permit the drawing hand to open at release.
fingers={'L':[[30,31,32],[34,38,42],[36,41,44],[35,39,43],[33,37,40]],
         'R':[[80,81,82],[84,88,92],[86,91,94],[85,89,93],[83,87,90]]}
finger_map={}
for side,chains in fingers.items():
 s=1 if side=='L' else -1
 for digit,ids in zip(['thumb','index','middle','ring','little'],chains):
  centers=[]
  for cid in ids:centers.append(sum((originals[0].data.vertices[i].co for i in comps[0][cid]),Vector())/len(comps[0][cid]))
  d=(centers[1]-centers[0]).normalized()
  heads=[centers[0]-d*.026,(centers[0]+centers[1])*.5,(centers[1]+centers[2])*.5]
  for j,cid in enumerate(ids):
   name=f'{digit}_{j+1:02}.{side}';parent='hand.'+side if j==0 else f'{digit}_{j:02}.{side}'
   spec[name]=(heads[j],heads[j+1] if j<2 else centers[2]+d*.012,parent,Vector((0,-1,0)))
   finger_map[cid]=name
GRIP=V((.795,-.063,.958))
NOCK0=V((.713,-.059,1.012))
TOP=V((.787,.542,1.036));BOTTOM=V((.640,-.659,.990))
ARROW_NOCK=V((-.775,-.055,.968))
ARROW_TIP=V((-1.620,-.137,.377))
ARROW_DIR=(ARROW_TIP-ARROW_NOCK).normalized()
spec['bow']=(GRIP,GRIP+Vector((0,.20,0)),'hand.L',None)
spec['bow_upper']=(GRIP+Vector((0,.18,0)),TOP,'bow',None)
spec['bow_lower']=(GRIP+Vector((0,-.18,0)),BOTTOM,'bow',None)
for n,p in [('string_top',TOP),('string_bottom',BOTTOM),('string_nock',NOCK0)]:spec[n]=(p,p+Vector((0,0,.055)),'bow',None)
spec['arrow']=(ARROW_NOCK,ARROW_NOCK+ARROW_DIR*.3,'hand.R',None)
armdata=bpy.data.armatures.new('skeleton_archer_rig');rig=bpy.data.objects.new('skeleton_archer',armdata);scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
for n,(h,t,p,roll) in spec.items():
 b=armdata.edit_bones.new(n);b.head=h;b.tail=t
 if p:b.parent=armdata.edit_bones[p]
 if roll is not None:b.align_roll(roll)
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True
for pb in rig.pose.bones:pb.rotation_mode='QUATERNION'
rest={b.name:b.matrix_local.copy() for b in armdata.bones}
# Direct component weights preserve rigid humeri, tibiae, skull, equipment and fingers.
def body_weights(mesh_i,cid,p):
 x,y,z=p;z-=DZ
 if mesh_i==0:
  if cid in finger_map:return {finger_map[cid]:1}
  hard={1:'head',2:'head',11:'jaw',15:'head',12:'hips',49:'hips',
        16:'thigh.L',18:'shin.L',19:'shin.L',17:'foot.L',20:'foot.L',
        52:'thigh.R',61:'shin.R',62:'shin.R',58:'foot.R',63:'foot.R',
        22:'upper_arm.L',23:'forearm.L',24:'forearm.L',25:'forearm.L',26:'forearm.L',29:'hand.L',
        74:'upper_arm.R',75:'forearm.R',76:'forearm.R',77:'forearm.R',78:'forearm.R',79:'hand.R'}
  if cid in hard:return {hard[cid]:1}
  if cid in [5,21,46,51,53,54,55,56,57,59,60,64,65,66,67,68,69,70,71,72,73]:return {'quiver':1}
  if cid==3:return skirt_weights(p)
  if cid==9:
   if z>1.50:return {'neck':1}
   return torso_weights(z)
  if cid in [6,7,8,10,13,14,45,47,48,50]:return {'chest':1}
  if cid in [0,4]:
   w=torso_weights(z)
   if abs(x)>.17 and z>1.34:
    side='L' if x>0 else 'R';t=min(.34,(abs(x)-.17)*2.5)
    w={k:v*(1-t) for k,v in w.items()};w['clavicle.'+side]=t
   return w
 if mesh_i==1:
  if cid in [0,2,10]:return {'hips':1}
  if cid==1:return skirt_weights(p)
  if cid==3:return {'chest':1}
  if cid in [4,5,6,7]:return {'clavicle.L':1}
 return torso_weights(z)
def torso_weights(z):
 if z<=1.04:return {'hips':1}
 if z<1.19:
  t=(z-1.04)/.15;return {'hips':1-t,'spine':t}
 if z<1.30:
  t=(z-1.19)/.11;return {'spine':1-t,'chest':t}
 return {'chest':1}
def skirt_weights(p):
 x,y,z=p;z-=DZ
 w=max(0,min(1,(.97-z)/.26))
 if abs(x)<.08 and y<-.075:n='tabard_front'
 elif y>.09 and abs(x)<.17:n='tabard_back'
 else:n='skirt.L' if x>=0 else 'skirt.R'
 return {'hips':1-w,n:w}
objects=[]
def extract(name,items,weight_fn):
 # Copy per-corner UV and normals instead of regenerating the supplied texture.
 verts=[];faces=[];uvs=[];normals=[];weights=[]
 for mi,ids in items:
  src=originals[mi].data;chosen=set();cids={}
  for cid in ids:
   for vi in comps[mi][cid]:chosen.add(vi);cids[vi]=cid
  mapping={}
  for vi in sorted(chosen):
   mapping[vi]=len(verts);p=src.vertices[vi].co;verts.append(tuple(p));weights.append(weight_fn(mi,cids[vi],p))
  for poly in src.polygons:
   if all(i in chosen for i in poly.vertices):
    faces.append([mapping[i] for i in poly.vertices])
    uvs.extend([tuple(src.uv_layers.active.data[l].uv) for l in poly.loop_indices])
    normals.extend([tuple(src.corner_normals[l].vector) for l in poly.loop_indices])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 uv=mesh.uv_layers.new(name='UVMap')
 for i,v in enumerate(uvs):uv.data[i].uv=v
 for f in mesh.polygons:f.use_smooth=True
 mesh.normals_split_custom_set(normals)
 mesh.materials.append(originals[0].data.materials[0])
 ob=bpy.data.objects.new(name,mesh);scene.collection.objects.link(ob);objects.append(ob)
 skin(ob,weights);return ob
def skin(ob,weights):
 for n in spec:ob.vertex_groups.new(name=n)
 for vi,w in enumerate(weights):
  total=sum(w.values())
  for n,v in w.items():
   if v>1e-7:ob.vertex_groups[n].add([vi],v/total,'REPLACE')
 ob.parent=rig;mod=ob.modifiers.new('Armature','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=False
bow0={27};bow1={8,9};arrow0={95,96};arrow1={11,12,13,14,15}
body=extract('skeleton_body',[(0,[i for i in range(len(comps[0])) if i not in bow0|arrow0|{28}]),(1,[i for i in range(len(comps[1])) if i not in bow1|arrow1])],body_weights)
def bow_weights(mi,cid,p):
 d=p.y-GRIP.y;t=max(0,min(1,(abs(d)-.14)/.34));t=t*t*(3-2*t)
 return {'bow':1-t,('bow_upper' if d>0 else 'bow_lower'):t}
bow_ob=extract('bow',[(0,sorted(bow0)),(1,sorted(bow1))],bow_weights)
arrow=extract('arrow',[(0,sorted(arrow0)),(1,sorted(arrow1))],lambda *args:{'arrow':1})
# A genuinely skinned, round string. The shared centre follows the drawing fingers.
verts=[];faces=[];weights=[]
for endpoint,name in [(TOP,'string_top'),(BOTTOM,'string_bottom')]:
 axis=(NOCK0-endpoint).normalized();u=axis.cross(Vector((0,0,1))).normalized();v=axis.cross(u).normalized();base=len(verts)
 for pos,bn in [(endpoint,name),(NOCK0,'string_nock')]:
  for k in range(6):
   verts.append(tuple(pos+.0023*(cos(k*pi/3)*u+sin(k*pi/3)*v)));weights.append({bn:1})
 for k in range(6):faces.append((base+k,base+(k+1)%6,base+6+(k+1)%6,base+6+k))
mesh=bpy.data.meshes.new('bowstring');mesh.from_pydata(verts,[],faces);mesh.update()
ob=bpy.data.objects.new('bowstring',mesh);scene.collection.objects.link(ob);objects.append(ob)
mat=bpy.data.materials.new('bowstring_linen');mat.diffuse_color=(.26,.19,.105,1);mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.26,.19,.105,1);bs.inputs['Roughness'].default_value=.8
mesh.materials.append(mat);skin(ob,weights)
for o in originals:bpy.data.objects.remove(o,do_unlink=True)
# Pose with analytic 2-bone IK, then bake local transforms; exported GLB has no constraints.
def RX(a):return Matrix.Rotation(a,3,'X')
def RY(a):return Matrix.Rotation(a,3,'Y')
def RZ(a):return Matrix.Rotation(a,3,'Z')
def deg(a):return radians(a)
def update():bpy.context.view_layer.update()
def set_world(n,h,R,scale=1):
 m=(R@rest[n].to_3x3()).to_4x4();m.translation=h
 if scale!=1:
  for i in range(3):
   for j in range(3):m[i][j]*=scale
 rig.pose.bones[n].matrix=m;update()
def transform(n):return rig.pose.bones[n].matrix@rest[n].inverted()
def transformed_head(n):
 b=armdata.bones[n]
 return transform(b.parent.name)@b.head_local if b.parent else b.head_local.copy()
def delta(n,R):set_world(n,transformed_head(n),R)
def child_rotation(n,angles):
 pb=rig.pose.bones[n];pb.rotation_quaternion=(RX(angles[0])@RY(angles[1])@RZ(angles[2])).to_quaternion();update()
errors=[]
def limb(upper,lower,end,goal,pole,end_R,match_wrist_roll=False):
 start=transformed_head(upper);a=armdata.bones[upper].length;b=armdata.bones[lower].length
 dvec=goal-start;raw=dvec.length;d=max(abs(a-b)+.002,min(a+b-.003,raw));f=dvec.normalized()
 pv=Vector(pole)-start;pv=(pv-f*pv.dot(f)).normalized()
 dist=(a*a-b*b+d*d)/(2*d);height=math.sqrt(max(.00001,a*a-dist*dist));joint=start+f*dist+pv*height;actual=start+f*d
 for n,h,t in [(upper,start,joint),(lower,joint,actual)]:
  direction=armdata.bones[n].tail_local-armdata.bones[n].head_local
  R=direction.rotation_difference(t-h).to_matrix()
  if n==lower and match_wrist_roll:
   axis=(t-h).normalized()
   current=R@Vector((0,-1,0));current=(current-axis*current.dot(axis)).normalized()
   desired=end_R@Vector((0,-1,0));desired=(desired-axis*desired.dot(axis)).normalized()
   angle=math.atan2(axis.dot(current.cross(desired)),current.dot(desired))
   R=Matrix.Rotation(angle,3,axis)@R
  set_world(n,h,R)
 set_world(end,actual,end_R)
 errors.append({'frame':scene.frame_current,'limb':upper,'error':max(0,raw-d)})
 return actual
RSHOOT=Matrix(((0,0,-1),(-1,0,0),(0,1,0)))
left_wrist=armdata.bones['hand.L'].head_local.copy()
right_wrist=armdata.bones['hand.R'].head_local.copy()
R_ARROW=ARROW_DIR.rotation_difference(Vector((0,-1,0))).to_matrix()
foot_points={}
for side in ['L','R']:
 group=body.vertex_groups['foot.'+side].index
 foot_points[side]=[v.co-armdata.bones['foot.'+side].head_local for v in body.data.vertices if any(g.group==group and g.weight>.99 for g in v.groups)]
def ankle_target(side,x,y,lift,R):return Vector((x,y,-min((R@p).z for p in foot_points[side])+lift))
def pose_body(yaw,lean,bob,sway=0,twist=0,head_pitch=0,head_yaw=0,roll=0,secondary=0):
 set_world('root',armdata.bones['root'].head_local,Matrix.Identity(3))
 set_world('hips',armdata.bones['hips'].head_local+Vector((sway,0,bob)),RZ(deg(yaw*.68))@RX(deg(lean*.5))@RY(deg(roll)))
 delta('spine',RZ(deg(yaw*.85))@RX(deg(lean*.8))@RY(deg(roll*.5)))
 delta('chest',RZ(deg(yaw+twist))@RX(deg(lean)))
 delta('neck',RZ(deg(head_yaw))@RX(deg(head_pitch*.6)))
 delta('head',RZ(deg(head_yaw))@RX(deg(head_pitch)))
 child_rotation('jaw',(deg(1+secondary*.7),0,0))
 child_rotation('quiver',(deg(secondary*1.4),deg(secondary*.8),deg(secondary*.7)))
 for side in ['L','R']:child_rotation('clavicle.'+side,(0,0,0))
def set_fingers(curl,release=0,right_curl=None):
 for side in ['L','R']:
  for digit in ['thumb','index','middle','ring','little']:
   for j in range(1,4):
    amount=([48,65,35][j-1] if side=='L' else [16,38,28][j-1])*curl
    if side=='R':amount*=1-release
    if side=='R' and right_curl is not None:amount=[32,50,25][j-1]*right_curl
    if digit=='thumb':amount*=.7
    child_rotation(f'{digit}_{j:02}.{side}',(deg(amount),0,0))
def bow_and_string(grip,R,drawpoint,tension):
 set_world('bow',grip,R)
 a=deg(9*tension)
 for n,s in [('bow_upper',1),('bow_lower',-1)]:
  set_world(n,transformed_head(n),R@RZ(a*s))
 top=transform('bow_upper')@TOP;bottom=transform('bow_lower')@BOTTOM
 set_world('string_top',top,R);set_world('string_bottom',bottom,R);set_world('string_nock',drawpoint,R)
 return top,bottom

def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def mix(a,b,t):return a+(b-a)*t
# Archer poses specify grip and nock; IK supplies wrists, elbows and planted feet.
READY={'grip':(.17,-.50,1.19),'nock':(-.16,-.34,1.23),'yaw':-24,'lean':5,'bob':-.025,'cant':-18,'tension':.20}
FULL={'grip':(-.16,-.745,1.50),'nock':(-.18,-.235,1.50),'yaw':-58,'lean':3,'bob':-.047,'cant':-4,'tension':1.0}
FOLLOW=(-.33,-.19,1.55)
PICKUP=(-.29,.10,1.73)
RH_DRAW=RX(deg(-36))@RZ(deg(90))
def arc_path(t,points):
 """Cubic Bezier control points keep the return path outside the torso."""
 a,b,c,d=[Vector(p) for p in points]
 return tuple((1-t)**3*a+3*(1-t)**2*t*b+3*(1-t)*t*t*c+t**3*d)
def blend_pose(a,b,t):
 p={}
 for k in a:
  if isinstance(a[k],tuple):p[k]=tuple(mix(x,y,t) for x,y in zip(a[k],b[k]))
  else:p[k]=mix(a[k],b[k],t)
 return p
def archery(p,flutter=0,release=0,arrow_visible=1,free_hand=None,flight=0,carry_direction=None):
 grip=V(p['grip']);nock=V(p['nock'])
 pose_body(p['yaw'],p['lean'],p['bob'],twist=0,head_pitch=-1.5,head_yaw=-2,secondary=flutter)
 # Same targets throughout draw/shoot; knees absorb the weight transfer.
 for side,x,y in [('L',.205,-.045),('R',-.22,.145)]:
  footR=RZ(deg(-16 if side=='L' else 23))
  goal=ankle_target(side,x,y,0,footR)
  limb('thigh.'+side,'shin.'+side,'foot.'+side,goal,(x,-1,.55),footR)
  child_rotation('skirt.'+side,(deg(flutter*.7),deg((-1 if side=='L' else 1)*2),0))
 child_rotation('tabard_front',(deg(2+flutter*2),0,0));child_rotation('tabard_back',(deg(-2+flutter*2),0,0))
 # Rotate the original bow's long axis into the vertical shooting plane.
 RB=RY(deg(p['cant']))@RSHOOT
 Lgoal=grip-RB@(GRIP-left_wrist)
 limb('upper_arm.L','forearm.L','hand.L',Lgoal,(.32,-.24,1.04),RB)
 grip=transform('hand.L')@GRIP
 # The arrow remains horizontal at full draw and follows the nocking fingers.
 direction=(grip-nock).normalized()
 RA=ARROW_DIR.rotation_difference(direction).to_matrix()
 # Move the right palm onto the nock, retaining a consistent grip orientation.
 handpoint=nock if free_hand is None else V(free_hand)
 RR=RH_DRAW
 Rgoal=handpoint-RR@(ARROW_NOCK-right_wrist)
 limb('upper_arm.R','forearm.R','hand.R',Rgoal,(-.70,.40,1.36),RR,match_wrist_roll=True)
 actualhand=transform('hand.R')@ARROW_NOCK
 if free_hand is None:nock=actualhand
 # At release, drawpoint springs toward the bow while the hand follows through.
 if release>0:
  neutral=grip+RB@(NOCK0-GRIP)
  stringpoint=neutral+(nock-neutral)*(1-release)
 else:stringpoint=nock
 bow_and_string(grip,RB,stringpoint,p['tension'])
 if free_hand is not None:
  nock=actualhand
 if carry_direction is not None:
  direction=Vector(carry_direction).normalized()
  RA=ARROW_DIR.rotation_difference(direction).to_matrix()
 set_world('arrow',nock+direction*flight,RA,arrow_visible)
 set_fingers(1,release)

def run_pose(f):
 theta=2*pi*f/24
 pose_body(0,11+1.6*cos(theta*2),-.078+.033*cos(theta*2),sway=.017*sin(theta),twist=6*sin(theta),head_pitch=3,head_yaw=-2*sin(theta),roll=2*sin(theta),secondary=sin(theta-.5))
 for side,offset,s in [('L',0,1),('R',.5,-1)]:
  u=(f/24+offset)%1
  if u<.46:
   t=u/.46;y=mix(-.29,.29,t);lift=0
   pitch=mix(-7,0,smooth(t/.22)) if t<.60 else mix(0,18,smooth((t-.60)/.40))
  else:
   t=(u-.46)/.54;y=mix(.29,-.29,smooth(t));lift=.285*sin(pi*t)**1.15;pitch=mix(28,-7,smooth(t))
  footR=RZ(deg(-s*3))@RX(deg(pitch))
  goal=ankle_target(side,s*(.175+.014*sin(theta+offset*2*pi)),y+.06,lift,footR)
  limb('thigh.'+side,'shin.'+side,'foot.'+side,goal,(s*.19,-1,.55),footR)
  child_rotation('skirt.'+side,(deg(13*sin(theta+offset*2*pi-.35)),deg(s*(-3-6*max(0,sin(theta+offset*2*pi)))),deg(s*2)))
 child_rotation('tabard_front',(deg(12+9*sin(theta*2-.7)),0,deg(4*sin(theta-.5))))
 child_rotation('tabard_back',(deg(12+11*sin(theta*2-.9)),0,deg(4*sin(theta-.7))))
 RB=RY(deg(-17+4*sin(theta-.35)))@RZ(deg(5*sin(theta)))@RSHOOT
 grip=V((.48,-.20+.105*cos(theta),1.075+.025*sin(theta-.2)))
 # Carry with thumb up and palm toward the torso; the bow stays upright.
 RH=RX(deg(-8+5*sin(theta-.2)))@RZ(deg(-90))
 limb('upper_arm.L','forearm.L','hand.L',grip-RH@(GRIP-left_wrist),(.25,.50,.73),RH,match_wrist_roll=True)
 grip=transform('hand.L')@GRIP
 bow_and_string(grip,RB,grip+RB@(NOCK0-GRIP),0)
 RR=RX(deg(-12+12*cos(theta)))@RZ(deg(90))
 wrist=V((-.35-.0075*(1-cos(theta)),-.28-.12*cos(theta),1.16+.07*cos(theta)))
 limb('upper_arm.R','forearm.R','hand.R',wrist,(-.62,.50,.75),RR,match_wrist_roll=True)
 # Park the spare arrow inside the quiver for the entire run; right hand is empty.
 set_world('arrow',transform('quiver')@armdata.bones['quiver'].head_local,Matrix.Identity(3),.0001)
 set_fingers(.95,right_curl=.7)

def draw_pose(f):
 if f<6:
  p=dict(READY);t=sin(pi*f/6)**2;p['bob']-=.017*t;p['grip']=tuple(Vector(READY['grip'])+Vector((0,.015,-.028))*t)
 elif f<28:
  t=(f-6)/22
  p=blend_pose(READY,FULL,smooth(t))
  p['nock']=tuple(Vector(p['nock'])+Vector((-.035,-.03,0))*sin(pi*t)**2)
 else:
  p=dict(FULL);settle=sin((f-28)*pi/8)*math.exp(-(f-28)*.2);p['grip']=tuple(Vector(FULL['grip'])+Vector((.002,-.004,.006))*settle)
 archery(p,flutter=sin(pi*f/36)*1.2)

def shoot_pose(f):
 if f<=4:
  p=dict(FULL);p['bob']-=.003*sin(pi*f/4);archery(p,flutter=.2*sin(pi*f/4))
 elif f<11:
  t=(f-4)/7;p=dict(FULL)
  # High tension -> snap -> overshoot -> damped bow flex.
  p['tension']=math.exp(-(f-4)*.65)*cos((f-4)*1.7)
  p['grip']=tuple(Vector(FULL['grip'])+Vector((.012,.020,-.012))*sin(pi*t))
  p['nock']=tuple(Vector(FULL['nock']).lerp(Vector(FOLLOW),smooth(t)))
  release=smooth(min(1,(f-4)/1.5))
  visible=1 if f<=5 else (.001 if f>=7 else .15)
  archery(p,flutter=2*sin(pi*t),release=release,arrow_visible=visible,flight=min(.95,(f-4)*.46))
  launch=(Vector(FULL['grip'])-Vector(FULL['nock'])).normalized()
  set_world('arrow',V(FULL['nock'])+launch*min(.95,(f-4)*.46),ARROW_DIR.rotation_difference(launch).to_matrix(),visible)
 elif f<19:
  t=smooth((f-11)/8);p=blend_pose(FULL,READY,t*.65);p['tension']=0
  reach=arc_path(t,[FOLLOW,(-.43,-.15,1.66),(-.43,.03,1.80),PICKUP])
  archery(p,flutter=1.4*sin(pi*t),release=1,arrow_visible=.001,free_hand=reach)
 else:
  t=smooth((f-19)/11);p=blend_pose(blend_pose(FULL,READY,.65),READY,t);p['tension']=.20*t
  reach=arc_path(t,[PICKUP,(-.52,.02,1.75),(-.40,-.54,1.32),READY['nock']])
  # A replacement arrow comes from the quiver as the right hand returns to nock.
  carry=Vector((0,.05,-1)).lerp(Vector((-.4,-.9,-.1)),smooth(min(1,t/.45)))
  aimed=(Vector(p['grip'])-Vector(reach)).normalized()
  carry=carry.normalized().lerp(aimed,smooth(max(0,(t-.45)/.55)))
  archery(p,flutter=.8*sin(pi*t),release=1-t,arrow_visible=1,free_hand=reach if f<30 else None,carry_direction=carry if f<30 else None)

# Every frame carries local bone transforms, allowing engine-independent playback.
actions={}
previous={}
for name,end,func in [('run',24,run_pose),('draw',36,draw_pose),('shoot',30,shoot_pose)]:
 rig.animation_data_create();rig.animation_data.action=None
 for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action;previous={}
 for f in range(end+1):
  scene.frame_set(f);func(f)
  for pb in rig.pose.bones:
   q=pb.rotation_quaternion
   if pb.name in previous and q.dot(previous[pb.name])<0:pb.rotation_quaternion.negate()
   previous[pb.name]=pb.rotation_quaternion.copy()
   pb.keyframe_insert('location',frame=f,group=pb.name);pb.keyframe_insert('rotation_quaternion',frame=f,group=pb.name);pb.keyframe_insert('scale',frame=f,group=pb.name)
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for fc in bag.fcurves:
     for k in fc.keyframe_points:k.interpolation='BEZIER';k.handle_left_type='AUTO_CLAMPED';k.handle_right_type='AUTO_CLAMPED'
 action['loop']=name=='run';action['fps']=30;action['duration_seconds']=end/30
 if name=='shoot':action['release_frame']=4;action['release_seconds']=4/30
 actions[name]=action
 print('AUTHORED',name,end/30,flush=True)
# NLA tracks explicitly associate all actions with this armature for glTF export.
rig.animation_data.action=None
for name,action in actions.items():
 track=rig.animation_data.nla_tracks.new();track.name=name;strip=track.strips.new(name,0,action);strip.action_frame_start=0;strip.action_frame_end={'run':24,'draw':36,'shoot':30}[name];track.mute=True
rig.animation_data.action=actions['draw'];scene.frame_start=0;scene.frame_end=36;scene.frame_set(0)
rig['asset']='monster__skeleton__archer__vari01_kings_raid';rig['forward_axis']='Source orientation preserved: Blender -Y / glTF +Z';rig['motion_notes']='run loops 0..24 at 30fps; draw holds its last frame; shoot begins at draw end and reloads to draw start.'
rig['license']='CC-BY-4.0';rig['original_author']='ilyakardailskiy';rig['source_title']="Monster_ Skeleton_ Archer_ Vari01 King's raid"
scene['release_time_seconds']=4/30
# A reproducible authoring source, without studio cameras or ground in the export.
for o in scene.objects:o.select_set(o in objects or o==rig)
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/archer/assets/source/archer_animated.blend'))
props={p.identifier for p in bpy.ops.export_scene.gltf.get_rna_type().properties}
kwargs=dict(filepath=str(ASSET),export_format='GLB',export_apply=True,export_yup=True,export_skins=True,export_animations=True,export_extras=True,use_selection=True)
for k,v in {'export_animation_mode':'ACTIONS','export_frame_range':False,'export_force_sampling':True,'export_sampling_interpolation_fallback':'LINEAR','export_def_bones':False,'export_current_frame':False,'export_reset_pose_bones':True}.items():
 if k in props:kwargs[k]=v
bpy.ops.export_scene.gltf(**kwargs)
QA.mkdir(exist_ok=True)
summary={'bone_count':len(spec),'unweighted':sum(not v.groups for ob in objects for v in ob.data.vertices),'max_influences':max(len(v.groups) for ob in objects for v in ob.data.vertices),'triangles':sum(sum(len(p.vertices)-2 for p in ob.data.polygons) for ob in objects),'vertices':sum(len(ob.data.vertices) for ob in objects),'animations':[{'name':n,'frames':[0,e],'duration':e/30,'loop':n=='run'} for n,e in [('run',24),('draw',36),('shoot',30)]] ,'ik_clamp_max':max(e['error'] for e in errors),'ik_clamps':[e for e in errors if e['error']>.012],'bones':list(spec)}
(QA/'authoring_report.json').write_text(json.dumps(summary,indent=2))
print('DONE',json.dumps({k:v for k,v in summary.items() if k not in ['bones','ik_clamps']}),flush=True)
import runpy
runpy.run_path(str(ROOT/'tools/archer/tools/finalize_archer.py'),run_name='__main__')
