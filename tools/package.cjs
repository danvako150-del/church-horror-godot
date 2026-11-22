const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..');
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>{
 if(['.git','.godot','.source-cache','.before_retro'].includes(e.name))return [];
 const file=path.join(dir,e.name),rel=path.relative(root,file).replaceAll('\\','/');
 if(rel==='PROJECT_MANIFEST.json')return [];
 return e.isDirectory()?walk(file):[{path:rel,bytes:fs.statSync(file).size,sha256:crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex')}];
});}
const files=walk(root);fs.writeFileSync(path.join(root,'PROJECT_MANIFEST.json'),JSON.stringify({project:'Church Godot v29',files},null,2));
console.log('MANIFEST files='+files.length+' bytes='+files.reduce((n,f)=>n+f.bytes,0));
