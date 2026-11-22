const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..'),level=JSON.parse(fs.readFileSync(path.join(root,'assets/map/level.json')));
for(const p of level.props.filter(p=>!/tree|pole|bench/.test(p.source))){
 const g=JSON.parse(fs.readFileSync(path.join(root,p.path))),b=fs.readFileSync(path.join(path.dirname(path.join(root,p.path)),g.buffers[0].uri));
 const positions=[];for(const m of g.meshes)for(const prim of m.primitives){let a=g.accessors[prim.attributes.POSITION],v=g.bufferViews[a.bufferView];for(let i=0;i<a.count;i++)positions.push([0,1,2].map(k=>b.readFloatLE(v.byteOffset+(i*3+k)*4)));}
 const min=Math.min(...positions.map(p=>p[1])),low=positions.filter(p=>p[1]<min+.04),clusters=[];
 for(let v of low){let c=clusters.find(c=>Math.hypot(c.x/c.n-v[0],c.z/c.n-v[2])<.7);if(!c){c={x:0,z:0,n:0};clusters.push(c);}c.x+=v[0];c.z+=v[2];c.n++;}
 console.log(JSON.stringify({id:p.id,source:p.source,min,contacts:clusters.map(c=>[c.x/c.n,min,c.z/c.n]),materials:g.materials.map(m=>({name:m.name,texture:m.pbrMetallicRoughness.baseColorTexture?g.images[g.textures[m.pbrMetallicRoughness.baseColorTexture.index].source].uri:null}))}));
}
