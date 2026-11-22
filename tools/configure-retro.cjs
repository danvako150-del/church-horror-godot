// Texture import settings only; retain original PNGs for future art changes.
const fs=require('fs'),path=require('path'),root=path.resolve(__dirname,'..');
let changed=0;
for(const name of fs.readdirSync(path.join(root,'assets/textures')).filter(n=>n.endsWith('.png.import'))){
 const file=path.join(root,'assets/textures',name),original=fs.readFileSync(file,'utf8');let text=original;
 const settings={'compress/mode':'2','compress/high_quality':'false','mipmaps/generate':'true','process/size_limit':'256','detect_3d/compress_to':'0'};
 for(const [key,value] of Object.entries(settings)){const escaped=key.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),regex=new RegExp('^'+escaped+'=.*$','m');text=regex.test(text)?text.replace(regex,key+'='+value):text+'\n'+key+'='+value+'\n';}
 if(text!==original){fs.writeFileSync(file,text);changed++;}
}
console.log('RETRO_TEXTURE_IMPORTS '+changed+' textures: BC compression, 256px limit, mipmaps');
