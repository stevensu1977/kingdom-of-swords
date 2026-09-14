"""Preserve source attribution, expose clip events, and refresh the public asset manifest."""
from pathlib import Path
from datetime import datetime,timezone
import json,struct,hashlib
ROOT=Path(__file__).resolve().parents[3]
PATH=ROOT/'assets/models/monster__skeleton__archer__vari01_kings_raid.glb'
raw=PATH.read_bytes();chunks=[];offset=12
while offset<len(raw):
 size,kind=struct.unpack_from('<II',raw,offset);chunks.append((kind,raw[offset+8:offset+8+size]));offset+=8+size
assert chunks[0][0]==0x4e4f534a
g=json.loads(chunks[0][1])
g['asset']['extras']={
 'author':'ilyakardailskiy (https://sketchfab.com/ilyakardailskiy)',
 'license':'CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)',
 'source':'https://sketchfab.com/3d-models/monster--skeleton--archer--vari01-kings-raid-ee436bf2d7774afab117f7e9108d34fe',
 'title':"Monster_ Skeleton_ Archer_ Vari01 King's raid",
 'modifications':'Fitted 63-bone skin; run, draw and shoot actions; skinned bow limbs and replacement bowstring. Original geometry, palette, UVs, texture and orientation retained.'}
events={'run':[{'name':'footstep_left','time':0.0},{'name':'footstep_right','time':.4}],
        'draw':[{'name':'aim_ready','time':1.2}],
        'shoot':[{'name':'arrow_release','time':4/30},{'name':'reload_pickup','time':19/30}]}
clips=[]
for a in g['animations']:
 duration=max(g['accessors'][s['input']]['max'][0] for s in a['samplers'])
 a.setdefault('extras',{}).update({'loop':a['name']=='run','events':events[a['name']]})
 if a['name']=='run':a['extras'].update({'right_hand':'empty','left_bow_grip':'palm_inward_thumb_up'})
 clips.append({'name':a['name'],'duration':duration,'loop':a['name']=='run','fps':30,'events':events[a['name']]})
js=json.dumps(g,separators=(',',':'),ensure_ascii=False).encode();js+=b' '*((-len(js))%4)
chunks[0]=(0x4e4f534a,js)
payload=b''.join(struct.pack('<II',len(data),kind)+data for kind,data in chunks)
raw=struct.pack('<III',0x46546c67,2,12+len(payload))+payload;PATH.write_bytes(raw)
ledger=ROOT/'assets/manifest.json';m=json.loads(ledger.read_text());entry=next(e for e in m['models'] if e['path']==str(PATH.relative_to(ROOT)))
prims=[p for mesh in g['meshes'] for p in mesh['primitives']]
position=[g['accessors'][p['attributes']['POSITION']] for p in prims]
lo=[min(p['min'][i] for p in position) for i in range(3)];hi=[max(p['max'][i] for p in position) for i in range(3)]
now=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
entry.update({'triangles':sum(g['accessors'][p['indices']]['count']//3 for p in prims),
 'vertices':sum(p['count'] for p in position),'bounds':[round(b-a,4) for a,b in zip(lo,hi)],
 'materials':len(g['materials']),'textures':len(g.get('images',[])),'bytes':len(raw),'fileHash':hashlib.sha256(raw).hexdigest(),
 'updatedAt':now,'animationClips':clips})
sourcefiles=['tools/archer/assets/source/archer_static.blend','tools/archer/assets/source/archer_animated.blend']+[str(p.relative_to(ROOT)) for p in sorted((ROOT/'tools/archer/tools').glob('*.py'))]
entry['sourceFiles']=list(dict.fromkeys(entry.get('sourceFiles',[])+sourcefiles))
inspect=entry.setdefault('inspect',{})
inspect.update({'meshes':len(g['meshes']),'uvMeshes':sum(any('TEXCOORD_0' in p['attributes'] for p in mesh['primitives']) for mesh in g['meshes']),
 'bones':len(g['skins'][0]['joints']),'boneNames':[g['nodes'][i]['name'] for i in g['skins'][0]['joints']],
 'skinnedMeshes':sum('skin' in n for n in g['nodes']),'animations':[c['name'] for c in clips],
 'materials':[{'name':mat['name'],'baseColor':'baseColorTexture' in mat.get('pbrMetallicRoughness',{}),'normal':'normalTexture' in mat,'roughness':'metallicRoughnessTexture' in mat.get('pbrMetallicRoughness',{}),'emissive':'emissiveTexture' in mat} for mat in g['materials']]})
m['updatedAt']=now;ledger.write_text(json.dumps(m,indent=2,ensure_ascii=False)+'\n')
print('LEDGER',json.dumps({k:entry[k] for k in ['triangles','vertices','bounds','bytes']}))
