// Controlled OAuth responses; never authenticates a real user or sends chat messages.
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES+'/playwright':'playwright');
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict');
(async()=>{
const root=path.resolve(__dirname,'../App/Web');
const server=http.createServer((req,res)=>{const name=req.url==='/'?'index.html':req.url.slice(1);if(!['index.html','style.css','app.js','core.js'].includes(name)){res.writeHead(404).end();return;}res.setHeader('Content-Type',name.endsWith('.js')?'text/javascript':name.endsWith('.css')?'text/css':'text/html');res.end(fs.readFileSync(path.join(root,name)));});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
let browser;
try{browser=await chromium.launch({headless:true,args:['--no-sandbox']});const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.route('https://**/*',r=>r.abort());await page.addInitScript(()=>{
localStorage.setItem('config',JSON.stringify({clientId:'testclient'}));window.fixture={refresh:0,deleted:0,saved:'',mode:'ok',api:0};
window.webkit={messageHandlers:{native:{postMessage:m=>{const f=window.fixture;let result=true,status=200,data={};if(m.method==='readToken')result='';if(m.method==='deleteToken'){f.deleted++;f.saved='';}if(m.method==='writeToken')f.saved=m.value;if(m.method==='http'){
if(m.url.endsWith('/device'))data={device_code:'device',user_code:'CODE',verification_uri:'https://www.twitch.tv/activate',expires_in:600,interval:5};
else if(m.url.endsWith('/token')){if(m.body.includes('refresh_token')){f.refresh++;if(f.mode==='network'){status=503;data={message:'Temporary outage'};}else if(f.mode==='revoked'){status=400;data={message:'Invalid refresh token'};}else data={access_token:'renewed',refresh_token:'rotated',expires_in:3600};}else data={access_token:'login',refresh_token:'refresh',expires_in:3600};}
else if(m.url.endsWith('/validate'))data={client_id:'testclient',user_id:'1',login:'tester',expires_in:3600};
else if(m.url.includes('/helix/')){f.api++;if(f.mode==='401'&&m.headers.Authorization==='Bearer old'){status=401;data={message:'Invalid token'};}else data={data:[]};}
result={status,text:JSON.stringify(data)};}setTimeout(()=>window.nativeReply({id:m.id,result}),10);}}}};
});
await page.goto('http://127.0.0.1:'+server.address().port);await page.getByText('Весь Twitch. Более живой чат.').waitFor();
const seed=()=>page.evaluate(()=>{auth={access_token:'old',refresh_token:'refresh',expiresAt:0};me={id:'1',login:'tester'};});
await seed();await page.evaluate(()=>Promise.all([ensureAuth(),ensureAuth(),ensureAuth()]));assert.equal(await page.evaluate(()=>fixture.refresh),1);assert.equal(await page.evaluate(()=>JSON.parse(fixture.saved).refresh_token),'rotated');
await seed();await page.evaluate(()=>fixture.mode='network');assert.equal(await page.evaluate(async()=>{try{await ensureAuth();return false;}catch{return !!auth;}}),true);assert.equal(await page.evaluate(()=>fixture.deleted),0);
await page.evaluate(()=>{fixture.mode='401';auth.expiresAt=Date.now()+4000000;});assert.deepEqual(await page.evaluate(()=>helix('streams')),{data:[]});assert.equal(await page.evaluate(()=>auth.access_token),'renewed');
await seed();await page.evaluate(()=>fixture.mode='revoked');await page.evaluate(()=>ensureAuth().catch(()=>{}));assert.equal(await page.evaluate(()=>auth),null);assert.equal(await page.evaluate(()=>fixture.saved),'');
await page.evaluate(()=>{fixture.mode='ok';showLogin();});await page.locator('#startLogin').click();await page.locator('#userCode').filter({hasText:'CODE'}).waitFor();await page.locator('[data-close=login]').click();await page.waitForTimeout(5500);assert.equal(await page.evaluate(()=>auth),null);
await page.evaluate(()=>showLogin());await page.locator('#startLogin').click();await page.waitForFunction(()=>document.getElementById('profile').textContent==='tester');assert.equal(await page.evaluate(()=>JSON.parse(fixture.saved).access_token),'login');await page.waitForFunction(()=>!document.getElementById('login').open);assert.equal(await page.locator('#login').evaluate(e=>e.open),false);
assert.deepEqual(errors,[]);console.log('OAuth passed: refresh single-flight, token rotation, temporary outage, 401 retry, revoked session, cancellation, device login. Mocked responses only.');
}finally{await browser?.close();server.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
