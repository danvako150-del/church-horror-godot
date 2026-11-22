const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const root=path.resolve(__dirname,'..'),report=JSON.parse(fs.readFileSync(path.join(root,'reports/conversion.json'))),placements=JSON.parse(fs.readFileSync(path.join(root,'reports/transport_placement.json')));
const results=[];
for(const model of report.models){
 const file=path.join(root,model.path),g=JSON.parse(fs.readFileSync(file)),bin=fs.readFileSync(path.join(path.dirname(file),g.buffers[0].uri));let positive=0,negative=0;
 for(const mesh of g.meshes)for(const p of mesh.primitives){
  const read=id=>{let a=g.accessors[id],v=g.bufferViews[a.bufferView];return Array.from({length:a.count*3},(_,i)=>bin.readFloatLE(v.byteOffset+i*4));};
  const a=read(p.attributes.POSITION),n=read(p.attributes.NORMAL);
  for(let i=0;i<a.length;i+=9){const u=[0,1,2].map(k=>a[i+3+k]-a[i+k]),v=[0,1,2].map(k=>a[i+6+k]-a[i+k]),c=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]],d=c.reduce((s,x,k)=>s+x*(n[i+k]+n[i+3+k]+n[i+6+k]),0);if(d>1e-8)positive++;if(d< -1e-8)negative++;}
 }
 assert(positive/(positive+negative)>.95,'Inside-out model: '+model.source);
 results.push('Outward surfaces: '+model.source);
 for(const mat of g.materials)assert(mat.pbrMetallicRoughness.baseColorTexture,'Untextured material: '+mat.name);
}
assert.equal(report.missing.length,0,'Unresolved import dependencies');results.push('No missing materials or models');
assert.equal(placements.length,12);
for(const p of placements){assert.equal(p.wheel_clearance_m.length,4);assert(p.wheel_clearance_m.every(c=>c>=-.0001&&c<=.025),'Floating/embedded wheel: '+p.id);assert(Math.abs(p.position[0]-p.old_position[0])<.0001&&Math.abs(p.position[2]-p.old_position[2])<.0001,'Blockade moved horizontally');results.push('Four grounded wheels and preserved street position: '+p.id);}
assert(placements.filter(p=>p.model.includes('bus')).every(p=>p.position[1]<p.old_position[1]-.08));results.push('Both buses lowered to their wheel support plane');
fs.writeFileSync(path.join(root,'reports/transport_tests.json'),JSON.stringify({passed:results,failed:[]},null,2));console.log('TRANSPORT_TESTS passed='+results.length+' failed=0');
