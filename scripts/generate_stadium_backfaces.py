"""Generate only the uncovered rear faces of the repaired stadium.

The original render/collision mesh is left intact. Requires NumPy.
Usage: python generate_stadium_backfaces.py source.glb output.bin validation.glb
"""
import collections
import json
from pathlib import Path
import struct
import sys
import numpy as np

source, destination, validation = map(Path, sys.argv[1:4])
raw = source.read_bytes()
length, _ = struct.unpack_from('<II', raw, 12)
model = json.loads(raw[20:20+length])
binary = raw[28+length:]

def read(index):
    accessor=model['accessors'][index];view=model['bufferViews'][accessor['bufferView']]
    dtype={5126:'<f4',5125:'<u4',5123:'<u2'}[accessor['componentType']]
    width={'SCALAR':1,'VEC2':2,'VEC3':3}[accessor['type']]
    offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)
    stride=view.get('byteStride',np.dtype(dtype).itemsize*width)
    return np.ndarray((accessor['count'],width),dtype=dtype,buffer=binary,offset=offset,strides=(stride,np.dtype(dtype).itemsize)).astype(float)

def cross(a,b):return a[0]*b[1]-a[1]*b[0]
def area(poly):
    return abs(sum(cross(poly[i]-poly[0],poly[i+1]-poly[0]) for i in range(1,len(poly)-1)))*0.5 if len(poly)>2 else 0

def half(poly,start,edge,sign):
    if len(poly)<3:return []
    result=[];previous=poly[-1];pd=sign*cross(edge,previous-start)
    for current in poly:
        cd=sign*cross(edge,current-start)
        if (cd>=0)!=(pd>=0):result.append(previous+(current-previous)*(pd/(pd-cd)))
        if cd>=0:result.append(current)
        previous,pd=current,cd
    return result

def subtract(poly,cutter):
    sign=1 if cross(cutter[1]-cutter[0],cutter[2]-cutter[0])>0 else -1
    remaining=poly;outside=[]
    for j in range(3):
        start,end=cutter[j],cutter[(j+1)%3]
        part=half(remaining,start,end-start,-sign)
        if area(part)>1e-8:outside.append(part)
        remaining=half(remaining,start,end-start,sign)
        if area(remaining)<=1e-8:return outside
    return outside

primitive=model['meshes'][0]['primitives'][0]
pos=read(primitive['attributes']['POSITION']);normal=read(primitive['attributes']['NORMAL']);uv=read(primitive['attributes']['TEXCOORD_0'])
indices=read(primitive['indices']).astype(int).reshape(-1,3)
triangles=pos[indices]
normals=np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0]);sizes=np.linalg.norm(normals,axis=1)
groups=collections.defaultdict(list)
keys=[]
for i,triangle in enumerate(triangles):
    if sizes[i]<1e-10:keys.append(None);continue
    n=normals[i]/sizes[i];key=tuple(np.round(n,5))+(round(float(np.dot(n,triangle[0])),4),)
    keys.append(key);groups[key].append(i)
vertices=[];vertex_normals=[];vertex_uv=[]
for i,triangle in enumerate(triangles):
    key=keys[i]
    if key is None:continue
    n=normals[i]/sizes[i];axes=[j for j in range(3) if j!=int(np.argmax(np.abs(n)))]
    projected=triangle[:,axes];poly=list(projected[[0,2,1]])
    pieces=[poly]
    opposite=tuple(round(-float(v),5) for v in key[:3])+(round(-float(key[3]),4),)
    low,high=projected.min(axis=0),projected.max(axis=0)
    for other in groups.get(opposite,[]):
        cutter=triangles[other][:,axes]
        if np.any(cutter.min(axis=0)>=high-1e-6) or np.any(cutter.max(axis=0)<=low+1e-6):continue
        if np.max(np.abs((triangles[other]-triangle[0])@n))>5e-4:continue
        pieces=[fragment for piece in pieces for fragment in subtract(piece,cutter)]
        if not pieces:break
    inverse=np.linalg.inv(np.column_stack((projected[1]-projected[0],projected[2]-projected[0])))
    for piece in pieces:
        for j in range(1,len(piece)-1):
            points=[piece[0],piece[j],piece[j+1]]
            if area(points)<1e-8:continue
            for point in points:
                b,c=inverse@(point-projected[0]);weights=np.array([1-b-c,b,c])
                vertices.append(weights@triangle)
                interpolated=-(weights@normal[indices[i]])
                if np.dot(interpolated,-n)<0:interpolated=-interpolated
                vertex_normals.append(interpolated/max(np.linalg.norm(interpolated),1e-12))
                vertex_uv.append(weights@uv[indices[i]])
vertices=np.asarray(vertices,dtype='<f4');vertex_normals=np.asarray(vertex_normals,dtype='<f4');vertex_uv=np.asarray(vertex_uv,dtype='<f4')
tris=vertices.reshape(-1,3,3)
valid=np.linalg.norm(np.cross(tris[:,1]-tris[:,0],tris[:,2]-tris[:,0]),axis=1)>1e-9
keep=np.repeat(valid,3)
vertices,vertex_normals,vertex_uv=vertices[keep],vertex_normals[keep],vertex_uv[keep]
destination.write_bytes(struct.pack('<I',len(vertices))+vertices.tobytes()+vertex_normals.tobytes()+vertex_uv.tobytes())

# A combined geometry-only GLB allows the regular overlap audit to check both sides.
combined=np.concatenate((triangles.reshape(-1,3).astype('<f4'),vertices))
packed_positions=combined.tobytes();packed_indices=np.arange(len(combined),dtype='<u4').tobytes()
metadata={'asset':{'version':'2.0'},'buffers':[{'byteLength':len(packed_positions)+len(packed_indices)}],'bufferViews':[{'buffer':0,'byteOffset':0,'byteLength':len(packed_positions)},{'buffer':0,'byteOffset':len(packed_positions),'byteLength':len(packed_indices)}],'accessors':[{'bufferView':0,'componentType':5126,'count':len(combined),'type':'VEC3'},{'bufferView':1,'componentType':5125,'count':len(combined),'type':'SCALAR'}],'meshes':[{'primitives':[{'attributes':{'POSITION':0},'indices':1}]}]}
encoded=json.dumps(metadata,separators=(',',':')).encode();encoded+=b' '*(-len(encoded)%4);blob=packed_positions+packed_indices
validation.write_bytes(struct.pack('<III',0x46546C67,2,28+len(encoded)+len(blob))+struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(blob),0x004E4942)+blob)
print(json.dumps({'original_triangles':len(indices),'added_rear_triangles':len(vertices)//3,'collision_mesh_unchanged':True},indent=2))
