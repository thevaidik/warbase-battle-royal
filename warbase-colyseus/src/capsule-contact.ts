import type { Vec3 } from './world-geometry.js';
// Closest features of a line segment and triangle (Voronoi-region tests).
// Feet-origin capsule: the sphere centres are radius above/below its ends.
const add = (a: Vec3,b: Vec3): Vec3 => [a[0]+b[0],a[1]+b[1],a[2]+b[2]];
const sub = (a: Vec3,b: Vec3): Vec3 => [a[0]-b[0],a[1]-b[1],a[2]-b[2]];
const mul = (a: Vec3,s: number): Vec3 => [a[0]*s,a[1]*s,a[2]*s];
const dot = (a: Vec3,b: Vec3) => a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const cross = (a: Vec3,b: Vec3): Vec3 => [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const clamp = (s: number) => Math.max(0,Math.min(1,s));
function pointTriangle(p: Vec3,a: Vec3,b: Vec3,c: Vec3): Vec3 {
 const ab=sub(b,a), ac=sub(c,a), ap=sub(p,a), d1=dot(ab,ap), d2=dot(ac,ap);
 if(d1<=0&&d2<=0)return a;
 const bp=sub(p,b),d3=dot(ab,bp),d4=dot(ac,bp);
 if(d3>=0&&d4<=d3)return b;
 const vc=d1*d4-d3*d2;
 if(vc<=0&&d1>=0&&d3<=0)return add(a,mul(ab,d1/(d1-d3)));
 const cp=sub(p,c),d5=dot(ab,cp),d6=dot(ac,cp);
 if(d6>=0&&d5<=d6)return c;
 const vb=d5*d2-d1*d6;
 if(vb<=0&&d2>=0&&d6<=0)return add(a,mul(ac,d2/(d2-d6)));
 const va=d3*d6-d5*d4;
 if(va<=0&&d4-d3>=0&&d5-d6>=0)return add(b,mul(sub(c,b),(d4-d3)/((d4-d3)+(d5-d6))));
 const inv=1/(va+vb+vc);
 return add(a,add(mul(ab,vb*inv),mul(ac,vc*inv)));
}
function segments(p: Vec3,q: Vec3,a: Vec3,b: Vec3): [Vec3,Vec3] {
 const d1=sub(q,p),d2=sub(b,a),r=sub(p,a),aa=dot(d1,d1),ee=dot(d2,d2),f=dot(d2,r);
 let s=0,t=0;
 if(aa<=1e-12&&ee<=1e-12)return[p,a];
 if(aa<=1e-12)t=clamp(f/ee);
 else {const c=dot(d1,r);if(ee<=1e-12)s=clamp(-c/aa);
 else {const bb=dot(d1,d2),den=aa*ee-bb*bb;s=den>1e-12?clamp((bb*f-c*ee)/den):0;t=(bb*s+f)/ee;
 if(t<0){t=0;s=clamp(-c/aa);}else if(t>1){t=1;s=clamp((bb-c)/aa);}}}
 return[add(p,mul(d1,s)),add(a,mul(d2,t))];
}
export type CapsuleContact = { normal: Vec3; depth: number; surfaceNormalY: number };
export function capsuleTriangle(feet: Vec3,radius: number,height: number,vertices: Float32Array,index: number,margin=0): CapsuleContact|null {
 const i=index*9,extent=radius+margin;
 if(Math.max(vertices[i],vertices[i+3],vertices[i+6])<feet[0]-extent || Math.min(vertices[i],vertices[i+3],vertices[i+6])>feet[0]+extent
 || Math.max(vertices[i+1],vertices[i+4],vertices[i+7])<feet[1]-margin || Math.min(vertices[i+1],vertices[i+4],vertices[i+7])>feet[1]+height+margin
 || Math.max(vertices[i+2],vertices[i+5],vertices[i+8])<feet[2]-extent || Math.min(vertices[i+2],vertices[i+5],vertices[i+8])>feet[2]+extent)return null;
 const a: Vec3=[vertices[i],vertices[i+1],vertices[i+2]],b: Vec3=[vertices[i+3],vertices[i+4],vertices[i+5]],c: Vec3=[vertices[i+6],vertices[i+7],vertices[i+8]];
 const p: Vec3=[feet[0],feet[1]+radius,feet[2]],q: Vec3=[feet[0],feet[1]+height-radius,feet[2]];
 let trianglePoint=pointTriangle(p,a,b,c),axisPoint=p,best=dot(sub(p,trianglePoint),sub(p,trianglePoint));
 const consider=(u: Vec3,v: Vec3)=>{const d=sub(u,v),sq=dot(d,d);if(sq<best){best=sq;axisPoint=u;trianglePoint=v;}};
 consider(q,pointTriangle(q,a,b,c));
 for(const [u,v] of [[a,b],[b,c],[c,a]]){const pair=segments(p,q,u,v);consider(pair[0],pair[1]);}
 const n=cross(sub(b,a),sub(c,a)),nLen=Math.sqrt(dot(n,n));
 if(nLen<1e-10)return null;
 const direction=sub(q,p),den=dot(n,direction);
 if(Math.abs(den)>1e-10){const t=dot(n,sub(a,p))/den;if(t>=0&&t<=1){const on=add(p,mul(direction,t)),closest=pointTriangle(on,a,b,c);if(dot(sub(on,closest),sub(on,closest))<1e-12){axisPoint=on;trianglePoint=on;best=0;}}}
 if(best>=extent*extent)return null;
 const distance=Math.sqrt(best);
 let normal: Vec3;
 if(distance>1e-7)normal=mul(sub(axisPoint,trianglePoint),1/distance);
 else {normal=mul(n,1/nLen);const middle=mul(add(p,q),.5);if(dot(normal,sub(middle,a))<0)normal=mul(normal,-1);}
 return {normal,depth:extent-distance,surfaceNormalY:n[1]/nLen};
}
