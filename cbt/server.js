const http=require('http'),fs=require('fs'),path=require('path');
const root=__dirname, data=path.join(root,'data','questions.json'), pub=path.join(root,'public');
const port=Number(process.env.PORT||3000);
function send(res,status,body,type='application/json; charset=utf-8'){res.writeHead(status,{'Content-Type':type,'Cache-Control':'no-store'});res.end(body)}
function validate(db){
 if(!db||typeof db.title!=='string'||!Array.isArray(db.questions))throw Error('title과 questions 배열이 필요합니다.');
 const ids=new Set();db.questions.forEach((q,i)=>{if(!q||typeof q.id!=='string'||!q.id.trim()||ids.has(q.id))throw Error(`${i+1}번 문항 ID가 없거나 중복됩니다.`);ids.add(q.id);if(typeof q.stem!=='string'||!q.stem.trim()||!Array.isArray(q.choices)||q.choices.length<2||q.choices.some(v=>typeof v!=='string'||!v.trim()))throw Error(`${i+1}번 문항의 문제/선택지를 확인하세요.`);if(q.answer!=null&&(!Number.isInteger(q.answer)||q.answer<1||q.answer>q.choices.length))throw Error(`${i+1}번 정답은 1부터 선택지 수까지여야 합니다.`);if(q.images!=null&&(!Array.isArray(q.images)||q.images.some(v=>typeof v!=='string'||!/^\/images\/[\w.-]+\.(png|jpg|jpeg|webp)$/i.test(v))))throw Error(`${i+1}번 이미지 경로를 확인하세요.`)});
}
http.createServer((req,res)=>{
 const url=new URL(req.url,'http://localhost');
 if(url.pathname==='/api/questions'){
  if(req.method==='GET')return fs.readFile(data,(e,b)=>e?send(res,500,JSON.stringify({error:e.message})):send(res,200,b));
  if(req.method==='PUT'){let chunks=[],size=0;req.on('data',c=>{size+=c.length;if(size>5e6){req.destroy();return}chunks.push(c)});req.on('end',()=>{try{const db=JSON.parse(Buffer.concat(chunks).toString('utf8'));validate(db);const temp=data+'.tmp';fs.writeFileSync(temp,JSON.stringify(db,null,2)+'\n');fs.renameSync(temp,data);fs.copyFileSync(data,path.join(pub,'questions.json'));send(res,200,JSON.stringify({ok:true,count:db.questions.length}))}catch(e){send(res,400,JSON.stringify({error:e.message}))}});return}
  return send(res,405,JSON.stringify({error:'Method not allowed'}));
 }
 const name=decodeURIComponent(url.pathname==='/'?'/index.html':url.pathname);const target=path.resolve(pub,'.'+name);
 if(!target.startsWith(pub+path.sep))return send(res,403,'Forbidden','text/plain');
 fs.readFile(target,(e,b)=>{if(e)return send(res,404,'Not found','text/plain');const ext=path.extname(target);send(res,200,b,({'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.png':'image/png','.jpg':'image/jpeg','.webp':'image/webp'}[ext]||'application/octet-stream'))});
}).listen(port,'127.0.0.1',()=>console.log(`CBT: http://localhost:${port}`));
