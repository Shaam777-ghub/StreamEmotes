(function(root){
'use strict';
const mediaHosts=['cdn.7tv.app','cdn.7tv.io','cdn.betterttv.net','static-cdn.jtvnw.net','static-cdn.jtvnw.net'];
function safeImage(value){try{const u=new URL(String(value).startsWith('//')?'https:'+value:value);return u.protocol==='https:'&&mediaHosts.includes(u.hostname)?u.href:'';}catch{return '';}}
function rgba(c){if(typeof c==='number'){let n=c>>>0;return `rgba(${n>>>24},${(n>>>16)&255},${(n>>>8)&255},${(n&255)/255})`;}if(c&&['r','g','b','a'].every(k=>Number.isFinite(c[k])))return `rgba(${c.r},${c.g},${c.b},${c.a/255})`;return '#bf94ff';}
function unescapeTag(v){return v.replace(/\\([s:nr\\])/g,(_,c)=>({'s':' ',':':';',n:'\n',r:'\r','\\':'\\'}[c]));}
function parseIRC(line){let rest=line,tags={},prefix='';if(rest.startsWith('@')){const i=rest.indexOf(' ');if(i<0)return null;for(const t of rest.slice(1,i).split(';')){const p=t.indexOf('=');tags[p<0?t:t.slice(0,p)]=p<0?'':unescapeTag(t.slice(p+1));}rest=rest.slice(i+1);}if(rest.startsWith(':')){const i=rest.indexOf(' ');if(i<0)return null;prefix=rest.slice(1,i);rest=rest.slice(i+1);}const i=rest.indexOf(' :');const trailing=i<0?'':rest.slice(i+2);const parts=(i<0?rest:rest.slice(0,i)).split(' ');return{tags,prefix,command:parts.shift(),params:parts,text:trailing};}
function tokenize(text,tag,emotes){
 const chars=Array.from(text),ranges=[];
 for(const item of (tag||'').split('/')){const [id,positions]=item.split(':');if(!/^\d+$/.test(id)||!positions)continue;for(const p of positions.split(',')){const [a,b]=p.split('-').map(Number);if(Number.isInteger(a)&&Number.isInteger(b)&&a>=0&&b>=a&&b<chars.length)ranges.push({a,b,id});}}
 ranges.sort((a,b)=>a.a-b.a);const result=[];let at=0;
 const plain=t=>{for(const part of t.split(/(\s+)/)){if(!part)continue;const e=emotes.get(part);result.push(e?{kind:'emote',text:part,...e}:{kind:'text',text:part});}};
 for(const r of ranges){if(r.a<at)continue;plain(chars.slice(at,r.a).join(''));result.push({kind:'emote',text:chars.slice(r.a,r.b+1).join(''),url:`https://static-cdn.jtvnw.net/emoticons/v2/${r.id}/default/dark/2.0`});at=r.b+1;}plain(chars.slice(at).join(''));return result;
}
function paintStyle(p){
 const backgrounds=[],shadows=[];
 for(const l of p?.data?.layers||[]){const t=l.ty;const opacity=Math.max(0,Math.min(1,l.opacity??1));const color=c=>rgba({...c,a:Math.round(c.a*opacity)});let v='';
  if(t.__typename==='PaintLayerTypeSingleColor')v=`linear-gradient(${color(t.color)},${color(t.color)})`;
  if(t.__typename==='PaintLayerTypeImage'){const u=safeImage((t.images.find(x=>x.mime==='image/webp')||t.images[0])?.url);if(u)v=`url("${u.replace(/"/g,'%22')}")`;}
  if(t.__typename==='PaintLayerTypeLinearGradient'||t.__typename==='PaintLayerTypeRadialGradient'){const stops=(t.stops||[]).map(s=>`${color(s.color)} ${s.at*100}%`).join(',');if(stops)v=`${t.repeating?'repeating-':''}${t.__typename==='PaintLayerTypeLinearGradient'?'linear-gradient('+Number(t.angle)+'deg':'radial-gradient('+(t.shape==='CIRCLE'?'circle':'ellipse')},${stops})`;}
  if(v)backgrounds.push(v);
 }
 for(const s of p?.data?.shadows||[])shadows.push(`${Number(s.offsetX)}px ${Number(s.offsetY)}px ${Math.max(0,Number(s.blur))}px ${rgba(s.color)}`);
 return{backgroundImage:backgrounds.join(','),textShadow:shadows.join(',')};
}
const api={safeImage,rgba,parseIRC,tokenize,paintStyle};if(typeof module!=='undefined')module.exports=api;else root.Core=api;
})(globalThis);
