const generatorHtml = r'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Aurora · Theme generator</title>
<style nonce="AURORA_NONCE">
:root{font-family:system-ui,sans-serif;color:#202630;background:#f5f6fa}*{box-sizing:border-box}body{margin:0}header,main{max-width:1240px;margin:auto;padding:28px}header{padding-bottom:0}h1{font-size:32px;margin:0}h2{font-size:20px}p{line-height:1.5;color:#59616f}main{display:grid;grid-template-columns:300px 1fr;gap:28px}form,.panel{background:white;border:1px solid #dde1e8;border-radius:16px;padding:22px}label{display:block;font-size:14px;font-weight:600;margin-bottom:16px}input,select{display:block;width:100%;padding:10px;margin-top:6px;border:1px solid #bdc4cf;border-radius:8px;font:inherit;background:white;color:#202630}button{padding:11px 16px;border:0;border-radius:8px;background:#354ec1;color:white;font:inherit;cursor:pointer}button:disabled{opacity:.45;cursor:default}button:focus-visible,a:focus-visible{outline:3px solid #d69700;outline-offset:3px}details{margin:20px 0}summary{cursor:pointer;font-size:14px}.actions{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0}.previews{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:16px}.preview{border-radius:14px;padding:24px;background:var(--surface);color:var(--onSurface);border:1px solid var(--outline)}.preview p{color:var(--onSurfaceVariant)}.preview h3{margin-top:0}.card{background:var(--surfaceContainer);padding:18px;border-radius:12px;margin:20px 0}.preview button{background:var(--primary);color:var(--onPrimary)}.chip{display:inline-block;border-radius:20px;padding:6px 12px;margin:8px 6px 0 0;background:var(--secondaryContainer);color:var(--onSecondaryContainer)}.status{display:block;padding:10px;margin-top:10px;border-radius:8px;background:var(--successContainer);color:var(--onSuccessContainer)}.warning{background:var(--warningContainer);color:var(--onWarningContainer)}.error{background:var(--errorContainer);color:var(--onErrorContainer)}.info{background:var(--infoContainer);color:var(--onInfoContainer)}.tokens{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:10px}.token{border:1px solid #dde1e8;border-radius:8px;overflow:hidden}.swatch{height:44px}.token span{display:block;padding:8px;font-size:12px;overflow-wrap:anywhere}.token code{display:block;padding:0 8px 8px}#message{min-height:24px}#message[data-error=true]{color:#a32020}#issues{font-size:13px;line-height:1.6}small{font-weight:400;color:#59616f}@media(max-width:760px){main{grid-template-columns:1fr;padding:18px}header{padding:18px}form{padding:18px}}
</style></head><body>
<style nonce="AURORA_NONCE">
.color-entry{display:flex;align-items:center;gap:8px}.color-entry input[type=color]{flex:0 0 46px;height:44px;padding:3px;cursor:pointer}.color-entry input[type=text]{min-width:0}.reset{background:#eef0f6;color:#35405b;padding:8px;font-size:12px;margin-top:6px}
.preview-actions{display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin:18px 0}.preview .secondary-action{background:var(--secondaryContainer);color:var(--onSecondaryContainer)}.preview .tertiary-action{background:var(--tertiaryContainer);color:var(--onTertiaryContainer)}
.mock-field{border:1px solid var(--outline);border-radius:8px;padding:12px;color:var(--onSurfaceVariant);background:var(--surfaceContainerLowest)}.mock-row{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px 0;border-bottom:1px solid var(--outlineVariant)}.progress{height:8px;border-radius:8px;background:var(--secondaryContainer);overflow:hidden;margin:12px 0}.progress-fill{width:65%;height:100%;background:var(--primary)}#project-status{font-size:13px;line-height:1.6;overflow-wrap:anywhere}
</style>
<header><h1>Aurora</h1><p>Build a theme from a few colors. Preview it in light and dark, then export its tokens.</p></header>
<main><form id="form"><h2>Theme inputs</h2>
<label>Name<input name="name" value="Wicked" required maxlength="100"></label>
<label>Theme ID<input name="id" value="wicked" required maxlength="100"></label>
<label>Primary seed<input name="primary" value="#246b35" placeholder="#246b35" required pattern="#[a-fA-F0-9]{6}" title="Six-digit hex color, for example #246b35"></label>
<label>Secondary seed <small>optional</small><input name="secondary" placeholder="Generated from primary" pattern="#[a-fA-F0-9]{6}"></label>
<label>Tertiary seed <small>optional</small><input name="tertiary" placeholder="Generated from primary" pattern="#[a-fA-F0-9]{6}"></label>
<label>Generate<select name="appearance"><option value="both">Light and dark</option><option value="light">Light only</option><option value="dark">Dark only</option></select></label>
<label>Scheme<select name="scheme"><option>tonalSpot</option><option>fidelity</option><option>vibrant</option><option>expressive</option><option>content</option><option>monochrome</option><option>neutral</option><option>rainbow</option><option>fruitSalad</option></select></label>
<details><summary>Status color seeds</summary><p>Leave blank to use Aurora's defaults.</p>
<label>Success<input name="success" placeholder="#146c2e" pattern="#[a-fA-F0-9]{6}"></label>
<label>Warning<input name="warning" placeholder="#805600" pattern="#[a-fA-F0-9]{6}"></label>
<label>Information<input name="info" placeholder="#0061a4" pattern="#[a-fA-F0-9]{6}"></label></details>
<button id="generate" type="submit">Generate theme</button><p><small>This tool generates the foundation's 58 tokens. App extensions are authored through Aurora's Dart API or agent recipes.</small></p></form>
<section class="panel" aria-label="Generated theme"><div id="message" role="status" aria-live="polite">Generate a theme to begin.</div>
<div class="actions"><button id="install" disabled>Add to project</button><button id="download" disabled>Download theme JSON</button><button id="light" disabled>Download light tokens</button><button id="dark" disabled>Download dark tokens</button></div>
<p id="project-status" role="status" aria-live="polite">Checking project target…</p>
<div id="previews" class="previews"></div><h2>Contrast diagnostics</h2><div id="issues">No theme generated yet.</div>
<h2>All tokens</h2><label>Appearance<select id="view" disabled></select></label><div id="tokens" class="tokens"></div>
</section></main>
<script nonce="AURORA_NONCE">
const $=id=>document.getElementById(id);let output=null;
let project=null;
// Pick visually or paste an exact hex. Optional fields remain automatic until chosen.
const defaults={primary:'#246b35',secondary:'#625b71',tertiary:'#805600',success:'#146c2e',warning:'#805600',info:'#0061a4'};
for(const [name,fallback] of Object.entries(defaults)){
  const hex=document.querySelector('input[name="'+name+'"]');
  hex.type='text';
  hex.setAttribute('aria-label',name+' hex value');
  const row=document.createElement('div');row.className='color-entry';
  hex.parentNode.insertBefore(row,hex);
  const picker=document.createElement('input');picker.type='color';
  picker.value=hex.value||fallback;picker.setAttribute('aria-label',name+' color picker');
  row.append(picker,hex);
  picker.addEventListener('input',()=>{hex.value=picker.value;});
  hex.addEventListener('input',()=>{if(/^#[a-fA-F0-9]{6}$/.test(hex.value))picker.value=hex.value;});
  if(name!=='primary'){
    const reset=document.createElement('button');reset.type='button';reset.className='reset';reset.textContent='Auto';
    reset.setAttribute('aria-label','Reset '+name+' to automatic');
    reset.addEventListener('click',()=>{hex.value='';picker.value=fallback;});row.append(reset);
  }
}
async function post(path,input){
  const response=await fetch(path,{method:'POST',headers:{'Content-Type':'application/json','X-Aurora-Token':'AURORA_NONCE'},body:JSON.stringify(input)});
  const data=await response.json();if(!response.ok)throw new Error(data.error||'Request failed');return data;
}
fetch('/project').then(response=>response.json()).then(data=>{
  project=data.path;
  $('project-status').textContent=project?'Project: '+project+'. Adds a theme bundle; existing files are preserved.':'Launch aurora generate --project PATH_TO_APP to enable Add to project.';
  $('install').disabled=!project||!output;
}).catch(()=>{$('project-status').textContent='Could not read project target.';});
$('install').addEventListener('click',async()=>{
  const snapshot=output;$('install').disabled=true;$('generate').disabled=true;
  try{
    const result=await post('/install',{generationId:snapshot.generationId});
    $('project-status').textContent='Added to '+result.directory+'. '+result.nextStep;
  }catch(error){$('project-status').textContent=error.message;$('install').disabled=!project||!output;}
  finally{$('generate').disabled=false;}
});
function element(tag,text,className){const e=document.createElement(tag);if(text!==undefined)e.textContent=text;if(className)e.className=className;return e;}
function tokenList(){const appearance=$('view').value;$('tokens').replaceChildren();for(const [path,hex] of Object.entries(output.colors[appearance])){const item=element('div',undefined,'token');item.title=output.roles[path];const swatch=element('div',undefined,'swatch');swatch.style.backgroundColor=hex;item.append(swatch,element('span',path),element('code',hex));$('tokens').append(item);}}
function render(){
  const manifest=output.manifest;
  $('previews').replaceChildren();$('view').replaceChildren();
  $('install').disabled=!project;
  for(const [appearance,colors] of Object.entries(output.colors)){
    const preview=element('article',undefined,'preview');
    preview.setAttribute('aria-label',appearance+' preview');
    for(const [path,hex] of Object.entries(colors))preview.style.setProperty('--'+path.split('.').pop(),hex);
    preview.append(element('h3',manifest.name+' · '+appearance),element('span','Tonight’s featured performance','chip'));
    const card=element('div',undefined,'card');
    card.append(element('strong','Your next great performance'),element('p','Discover stories, reserve your seat, and make an evening of it.'));
    const actions=element('div',undefined,'preview-actions');
    for(const [text,style] of [['Reserve seats',''],['View details','secondary-action']]){
      const action=element('button',text,style);action.type='button';actions.append(action);
    }
    card.append(actions);preview.append(card,element('div','Search performances…','mock-field'));
    const row=element('div',undefined,'mock-row');
    row.append(element('strong','Tonight at 7:30'),element('span','2 tickets','chip'));preview.append(row);
    preview.append(element('p','65% of seats reserved'));
    const progress=element('div',undefined,'progress');
    progress.setAttribute('aria-label','65 percent of seats reserved');
    progress.append(element('div',undefined,'progress-fill'));preview.append(progress);
    const explore=element('button','Explore more shows','tertiary-action');explore.type='button';preview.append(explore);
    for(const [kind,text] of [['success','Reservation confirmed'],['warning','Limited seats available'],['error','Payment needs attention'],['info','Doors open at 7:00']])preview.append(element('span',text,'status '+kind));
    $('previews').append(preview);
    const option=element('option',appearance);option.value=appearance;$('view').append(option);
  }
$('view').disabled=false;tokenList();$('download').disabled=false;for(const mode of ['light','dark'])$(mode).disabled=!manifest.variants[mode];const issues=manifest.contrast.filter(c=>c.status!=='pass');$('issues').replaceChildren();$('issues').append(element('p',issues.length?issues.length+' checks need attention.':'All declared contrast checks passed.'));for(const issue of issues)$('issues').append(element('div',issue.appearance+': '+issue.foreground+' / '+issue.background+' — '+issue.status+(issue.ratio==null?'':', '+issue.ratio.toFixed(2)+' (minimum '+issue.minimumRatio+')')));$('issues').append(element('p','These checks cover declared color pairs; review your actual text sizes, states, and layouts.'));}
$('form').addEventListener('submit',async event=>{event.preventDefault();$('generate').disabled=true;$('message').dataset.error='false';$('message').textContent='Generating…';try{const input=Object.fromEntries(new FormData($('form')));const response=await fetch('/generate',{method:'POST',headers:{'Content-Type':'application/json','X-Aurora-Token':'AURORA_NONCE'},body:JSON.stringify(input)});const data=await response.json();if(!response.ok)throw new Error(data.error||'Generation failed');output=data;render();$('message').textContent='Generated '+data.manifest.name+'. Seeds guide the palette; output colors may differ from the seeds.';}catch(error){$('message').dataset.error='true';$('message').textContent=error.message;}finally{$('generate').disabled=false;}});
$('view').addEventListener('change',tokenList);
function download(mode){if(!output)return;const data=mode?output.manifest.variants[mode]:output.manifest;const blob=new Blob([JSON.stringify(data,null,2)+'\n'],{type:'application/json'});const url=URL.createObjectURL(blob);const a=element('a');a.href=url;a.download=output.manifest.id.replace(/[^a-zA-Z0-9_-]/g,'_')+(mode?'.'+mode+'.tokens':'.theme')+'.json';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);}
$('download').addEventListener('click',()=>download());for(const mode of ['light','dark'])$(mode).addEventListener('click',()=>download(mode));
</script></body></html>''';
