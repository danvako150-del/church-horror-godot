const fs=require('fs'),path=require('path'),vm=require('vm');
const source=fs.readFileSync(path.join(__dirname,'convert-source.cjs'),'utf8'),context={};vm.createContext(context);vm.runInContext(source.slice(source.indexOf('function kv(text)'),source.indexOf('const children=')),context);
const bundled=path.join(__dirname,'../source_data/maps/church_block.vmf');
const map=context.kv(fs.readFileSync(fs.existsSync(bundled)?bundled:path.join(__dirname,'../../full_project/maps/church_block.vmf'),'utf8'));
for(const root of map.c.filter(c=>['world','entity'].includes(c.k)))for(const entry of root.v.c.filter(c=>c.k==='solid')){
 const s=entry.v,sides=s.c.filter(c=>c.k==='side').map(c=>c.v),points=sides.flatMap(side=>[...side.p.plane.matchAll(/\(([^)]+)\)/g)].map(m=>m[1].split(/\s+/).map(Number))),b=[0,1,2].map(i=>[Math.min(...points.map(p=>p[i])),Math.max(...points.map(p=>p[i]))]);
 if(b[0][0]<-1598&&b[0][1]>-1802&&b[1][0]<1080&&b[1][1]>1030&&b[2][0]<100&&!sides.some(x=>/door_/i.test(x.p.material)))console.log(JSON.stringify({id:s.p.id,b,materials:[...new Set(sides.map(x=>x.p.material))]}));
}
