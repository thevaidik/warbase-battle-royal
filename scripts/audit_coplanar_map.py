"""Measure same-facing coplanar triangle overlaps in a GLB (requires NumPy).
Usage: python audit_coplanar_map.py input.glb report.json
"""
import json,struct,collections,time,sys
from pathlib import Path
import numpy as np
f=open(sys.argv[1] if len(sys.argv)>1 else 'warbase-godot/client/assets/maps/football.glb','rb');f.read(12);n,_=struct.unpack('<II',f.read(8));m=json.loads(f.read(n));f.read(8);b=f.read()
def read(i):
 a=m['accessors'][i];v=m['bufferViews'][a['bufferView']];fmt={5126:'f',5125:'I',5123:'H'}[a['componentType']];c={'SCALAR':1,'VEC3':3}[a['type']];sz=struct.calcsize(fmt)*c;off=v.get('byteOffset',0)+a.get('byteOffset',0)
 return np.array([struct.unpack_from('<'+fmt*c,b,off+j*v.get('byteStride',sz)) for j in range(a['count'])])
p=m['meshes'][0]['primitives'][0];pos=read(p['attributes']['POSITION']);ids=read(p['indices']).reshape(-1).astype(int);tri=pos[ids].reshape(-1,3,3);norm=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0]);length=np.linalg.norm(norm,axis=1);groups=collections.defaultdict(list)
for i in range(len(tri)):
 if length[i]<1e-8:continue
 normal=norm[i]/length[i];d=np.dot(normal,tri[i,0]);key=tuple(np.round(normal,5))+(round(float(d),4),);groups[key].append(i)
def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def intersect_area(a,b):
 poly=[p for p in a];orientation=1 if cross(b[1]-b[0],b[2]-b[0])>0 else -1
 for j in range(3):
  start,end=b[j],b[(j+1)%3];edge=end-start;output=[]
  if len(poly)<3:return 0
  prev=poly[-1];pd=orientation*cross(edge,prev-start)
  for cur in poly:
   cd=orientation*cross(edge,cur-start)
   if (cd>=-1e-8)!=(pd>=-1e-8):output.append(prev+(cur-prev)*(pd/(pd-cd)))
   if cd>=-1e-8:output.append(cur)
   prev,pd=cur,cd
  poly=output
 if len(poly)<3:return 0
 return abs(sum(cross(poly[i],poly[(i+1)%len(poly)]) for i in range(len(poly))))*.5
pairs=[];area=0;tests=0
for key,indices in groups.items():
 if len(indices)<2:continue
 drop=int(np.argmax(np.abs(key[:3])));axes=[x for x in range(3) if x!=drop];polys=tri[indices][:,:,axes];low=polys.min(axis=1);high=polys.max(axis=1)
 for local,i in enumerate(indices):
  candidates=np.flatnonzero((low[:,0]<high[local,0]-1e-5)&(high[:,0]>low[local,0]+1e-5)&(low[:,1]<high[local,1]-1e-5)&(high[:,1]>low[local,1]+1e-5)&(np.arange(len(indices))>local))
  for other in candidates:
   tests+=1;overlap=intersect_area(polys[local],polys[other])
   if overlap>1e-5:
    area+=overlap;pairs.append({'a':i,'b':indices[other],'area':round(overlap,6),'center':tri[i].mean(axis=0).round(3).tolist(),'plane_deviation':float(np.max(np.abs((tri[indices[other]]-tri[i,0])@(norm[i]/length[i]))))})
result={'triangles':len(tri),'plane_groups':len(groups),'tested_pairs':tests,'positive_overlap_pairs':len(pairs),'projected_overlap_area':area,'examples':sorted(pairs,key=lambda x:-x['area'])[:30]}
Path(sys.argv[2] if len(sys.argv)>2 else 'audit/stadium-edge-analysis/coplanar-overlaps.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='examples'},indent=2))
