// Godot-only adaptation of the source VMF. Keep the Source checkout unchanged.
module.exports=function fixChurchDoors(map,report){
 const stats={removed_south_door_brushes:0,removed_south_steps:0,embedded_north_door_brushes:0,notched_north_plinth_brushes:0,extended_north_steps:0,north_translation_source_units:[0,-36,0],wall_north_y:1050,door_center_north_y:1048,threshold_z:24};
 let generatedId=90000000;
 const sides=s=>s.c.filter(c=>c.k==='side').map(c=>c.v);
 const numbers=s=>(s.match(/[-+]?(?:\d*\.)?\d+/g)||[]).map(Number);
 function bounds(s){const points=sides(s).flatMap(side=>{let n=numbers(side.p.plane);return [n.slice(0,3),n.slice(3,6),n.slice(6,9)];});return [0,1,2].map(i=>[Math.min(...points.map(p=>p[i])),Math.max(...points.map(p=>p[i]))]);}
 const near=(a,b)=>Math.abs(a-b)<.001;
 function resizedBox(s,original,target){let copy=JSON.parse(JSON.stringify(s));copy.p.id=String(generatedId++);for(const side of sides(copy)){side.p.id=String(generatedId++);side.p.plane=side.p.plane.replace(/\(([^)]+)\)/g,(_,p)=>{let v=p.split(/\s+/).map(Number);return '('+v.map((x,i)=>target[i][0]+(x-original[i][0])/(original[i][1]-original[i][0])*(target[i][1]-target[i][0])).join(' ')+')';});}return copy;}
 function process(s){let b=bounds(s);
  // Open the projecting stone base around the retained door. The old base
  // was a solid block and would otherwise hide the lower part of the leaf.
  if(['289','10806'].includes(s.p.id)){
   stats.notched_north_plinth_brushes++;let pieces=[[[b[0][0],-1802],b[1],b[2]],[[-1598,b[0][1]],b[1],b[2]]];
   if(s.p.id==='289')pieces.push([[-1802,-1598],[b[1][0],1038],b[2]]);
   return pieces.map(p=>resizedBox(s,b,p));
  }
  if(['1891','1899'].includes(s.p.id)){
   stats.extended_north_steps++;
   if(s.p.id==='1899')return false;
   stats.north_treads=4;
   stats.ramp_source_vertices=[[-1824,1132,0],[-1576,1132,0],[-1812,1084,24],[-1588,1084,24],[-1812,1032,24],[-1588,1032,24],[-1812,1032,0],[-1588,1032,0]];
   return [0,1,2,3].map(i=>{let half=124-i*4,step=resizedBox(s,b,[[-1700-half,-1700+half],[1032,1120-i*12],[i*6,(i+1)*6]]);step.p.church_entry_step='1';return step;});
  }
  let isChurch=b[0][0]>=-1821&&b[0][1]<=-1579;
  if(!isChurch)return true;
  let door=sides(s).some(side=>/^church\/door_/i.test(side.p.material));
  if(door&&b[1][0]>-1110&&b[1][1]<-1060){stats.removed_south_door_brushes++;return false;}
  if(door&&b[1][0]>1060&&b[1][1]<1110){for(const side of sides(s))side.p.plane=side.p.plane.replace(/\(([^)]+)\)/g,(_,p)=>{let v=p.split(/\s+/).map(Number);v[1]-=36;return '('+v.join(' ')+')';});stats.embedded_north_door_brushes++;return true;}
  let lower=near(b[0][0],-1820)&&near(b[0][1],-1580)&&near(b[1][0],-1074)&&near(b[1][1],-1026)&&near(b[2][0],0)&&near(b[2][1],12);
  let upper=near(b[0][0],-1800)&&near(b[0][1],-1600)&&near(b[1][0],-1068)&&near(b[1][1],-1032)&&near(b[2][0],12)&&near(b[2][1],24);
  if(lower||upper){stats.removed_south_steps++;return false;}return true;
 }
 for(const entry of map.c){if(!['world','entity'].includes(entry.k))continue;entry.v.c=entry.v.c.flatMap(c=>{if(c.k!=='solid')return[c];let result=process(c.v);return result===true?[c]:result===false?[]:result.map(v=>({k:'solid',v}));});}
 map.c=map.c.filter(c=>c.k!=='entity'||c.v.p.classname!=='func_detail'||c.v.c.some(x=>x.k==='solid'));
 if(stats.removed_south_door_brushes<20||stats.embedded_north_door_brushes<20||stats.removed_south_steps!==2||stats.notched_north_plinth_brushes!==2||stats.extended_north_steps!==2)throw Error('Unexpected church entrance layout: '+JSON.stringify(stats));
 report.church_doors=stats;
};
