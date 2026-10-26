const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const crypto=require('node:crypto');
const {Readable}=require('node:stream');
const {pipeline}=require('node:stream/promises');
const fingerprint=assets=>JSON.stringify(assets.map(a=>({id:a.id,name:a.name,size:a.size,digest:a.digest})).sort((a,b)=>a.name.localeCompare(b.name)));
const libraryAssets=assets=>assets.filter(a=>! /^(?:(?:latest|nightly|modular)-)?build-state-/.test(a.name));
const nightlyName=name=>name.replace(/_latest(?=[_.])/g,'_nightly');
function renameMetadata(bytes,name,names) {
    if(name.endsWith('.sha256')) {
        return Buffer.from(bytes.toString('utf8').split('\n').map(line=>line.replace(/^([a-f0-9]{64}\s+\*?)(.+)$/,(_,prefix,file)=>prefix+(names.get(file)||file))).join('\n'));
    }
    if(name.endsWith('.manifest.json')) {
        const walk=value=>typeof value==='string' ? names.get(value)||value : Array.isArray(value) ? value.map(walk) : value && typeof value==='object' ? Object.fromEntries(Object.entries(value).map(([k,v])=>[k,walk(v)])) : value;
        return Buffer.from(JSON.stringify(walk(JSON.parse(bytes)),null,2)+'\n');
    }
    return bytes;
}
async function checksum(file) {
    const h=crypto.createHash('sha256');
    for await (const chunk of fs.createReadStream(file))h.update(chunk);
    return 'sha256:'+h.digest('hex');
}
async function optionalRelease(github,repo,tag) {
    try{return (await github.rest.repos.getReleaseByTag({...repo,tag})).data;}
    catch(e){if(e.status===404)return null;throw e;}
}
const integrationPlatforms=Object.freeze(['linux','macos','ios','tvos','android','emscripten','windows']);
async function latestSha(github,repo) {
    const ref=(await github.rest.git.getRef({...repo,ref:'tags/latest'})).data.object;
    return ref.type==='tag' ? (await github.rest.git.getTag({...repo,tag_sha:ref.sha})).data.object.sha : ref.sha;
}
async function masterSha(github) {
    const sha=(await github.rest.repos.getCommit({owner:'openframeworks',repo:'openFrameworks',ref:'master'})).data.sha;
    if(!/^[a-f0-9]{40}$/.test(sha||''))throw Error('Cannot resolve openFrameworks master');
    return sha;
}
exports.plan=async({github,context})=>{
    const source=await optionalRelease(github,context.repo,'latest');
    if(!source||source.draft)throw Error('latest is missing or unpublished');
    const assets=libraryAssets(await github.paginate(github.rest.repos.listReleaseAssets,{...context.repo,release_id:source.id,per_page:100}));
    if(!assets.length)throw Error('latest has no library assets');
    for(const asset of assets)if(!/^[A-Za-z0-9_.+-]+$/.test(asset.name)||!/^sha256:[a-f0-9]{64}$/.test(asset.digest||''))throw Error(`Missing source digest or unsafe name: ${asset.name}`);
    return {schema:1,repository:`${context.repo.owner}/${context.repo.repo}`,releaseId:source.id,sourceSha:await latestSha(github,context.repo),
        openframeworksSha:await masterSha(github),platforms:[...integrationPlatforms],assets:assets.map(({id,name,size,digest})=>({id,name,size,digest}))};
};
exports.refresh=async(args)=>{
    if(args.dryRun)return copySnapshot(args);
    const {plan,buildResult,overrideBuildGate=false,github,context}=args;
    if(typeof overrideBuildGate!=='boolean')throw Error('Build-gate override must be a boolean');
    if(!plan||plan.schema!==1||plan.repository!==`${context.repo.owner}/${context.repo.repo}`||
       JSON.stringify(plan.platforms)!==JSON.stringify(integrationPlatforms)||!Array.isArray(plan.assets))throw Error('A complete frozen nightly validation plan is required');
    if(overrideBuildGate&&context.eventName!=='workflow_dispatch')throw Error('Build-gate override is only allowed on manual dispatch');
    if(!overrideBuildGate&&buildResult!=='success')throw Error(`openFrameworks master build gate did not pass (${buildResult||'missing'}); preserving nightly`);
    const runUrl=`https://github.com/${plan.repository}/actions/runs/${context.runId}`;
    const validationText=overrideBuildGate ? `Manual build-gate override by ${context.actor||'unknown'}: ${runUrl}.\nopenFrameworks master at planning: ${plan.openframeworksSha}. Compatibility checks were bypassed.` :
        `Validated against openFrameworks master ${plan.openframeworksSha} on ${plan.platforms.join(', ')}.\nValidation run: ${runUrl}.`;
    return copySnapshot({...args,validationText,validate:async({source,assets,sha})=>{
        if(source.id!==plan.releaseId||sha!==plan.sourceSha||fingerprint(assets)!==fingerprint(plan.assets))throw Error('latest changed since the validated plan; preserving nightly');
        if(await latestSha(github,context.repo)!==plan.sourceSha)throw Error('latest tag changed since validation; preserving nightly');
        if(!overrideBuildGate&&await masterSha(github)!==plan.openframeworksSha)throw Error('openFrameworks master changed since validation; preserving nightly');
    }});
};
async function copySnapshot({github,context,core,dryRun=false,now=new Date(),download,validate,validationText=''}) {
    const repo=context.repo;
    const list=release_id=>github.paginate(github.rest.repos.listReleaseAssets,{...repo,release_id,per_page:100});
    const source=await optionalRelease(github,repo,'latest');
    if(!source || source.draft)throw Error('latest is missing or unpublished');
    const assets=libraryAssets(await list(source.id));
    if(!assets.length)throw Error('latest has no library assets');
    for(const asset of assets)if(!/^[A-Za-z0-9_.+-]+$/.test(asset.name)||['.','..'].includes(asset.name)||!/^sha256:[a-f0-9]{64}$/.test(asset.digest||''))throw Error(`Unsafe name or missing source digest: ${asset.name}`);
    const names=new Map(assets.map(a=>[a.name,nightlyName(a.name)]));
    if(new Set(names.values()).size!==assets.length)throw Error('Nightly asset names collide');
    core.info(`Copy ${assets.length} assets (${(assets.reduce((n,a)=>n+a.size,0)/1024**3).toFixed(2)} GiB) from latest to nightly; no compilation`);
    if(dryRun){for(const [src,dst]of names)core.info(`${src} -> ${dst}`);return;}
    // Avoid replacing nightly while master platform workflows are publishing to it.
    async function masterIsBusy(){
        for(const status of ['queued','in_progress','waiting','pending']) {
            const runs=await github.paginate(github.rest.actions.listWorkflowRunsForRepo,{...repo,branch:'master',event:'push',status,per_page:100});
            if(runs.some(r=>/\/build-[^/]+\.yml$/.test(r.path||'')))return true;
        }
        return false;
    }
    if(await masterIsBusy()){core.notice('Master platform builds are active; preserving nightly. Retry after publication.');return;}
    const sha=await latestSha(github,repo);
    await validate({source,assets,sha});
    const date=now.toISOString().slice(0,10), stageTag=`nightly-staging-${context.runId}-${context.runAttempt||1}`;
    const temp=fs.mkdtempSync(path.join(os.tmpdir(),'nightly-snapshot-'));
    let staged,previous,previousMoved=false,published=false;
    try {
        const newest=assets.map(a=>a.updated_at||a.created_at).filter(Boolean).sort().at(-1)||'unknown';
        const body=`Daily snapshot copied from [latest](${source.html_url}) on ${date} (UTC).\n\nNo library compilation was performed. Library versions and original build metadata are unchanged.\n${validationText}\nSource tag commit: ${sha}. Most recent source asset update: ${newest}.\nTag-dependent filenames and checksum/manifest references are renamed from latest to nightly.\n`;
        staged=(await github.rest.repos.createRelease({...repo,tag_name:stageTag,target_commitish:sha,name:`Nightly ${date}`,body,draft:true,prerelease:true,make_latest:'false'})).data;
        for(const asset of assets) {
            const file=path.join(temp,'asset');
            for(let attempt=1; ; attempt++) {
                try {
                    if(download)await download(asset,file);
                    else {
                        const response=await fetch(`https://api.github.com/repos/${repo.owner}/${repo.repo}/releases/assets/${asset.id}`,{headers:{Accept:'application/octet-stream',Authorization:`Bearer ${process.env.GH_TOKEN}`}});
                        if(!response.ok)throw Error(`Download ${asset.name}: HTTP ${response.status}`);
                        await pipeline(Readable.fromWeb(response.body),fs.createWriteStream(file));
                    }
                    if(fs.statSync(file).size!==asset.size||await checksum(file)!==asset.digest)throw Error(`Source checksum mismatch: ${asset.name}`);
                    break;
                }catch(error){
                    if(attempt===3)throw error;
                    core.warning(`${asset.name}: ${error.message}; retry ${attempt}/2`);
                    if(!download)await new Promise(resolve=>setTimeout(resolve,attempt*1000));
                }
            }
            if(/\.(sha256|manifest\.json)$/.test(asset.name))fs.writeFileSync(file,renameMetadata(fs.readFileSync(file),asset.name,names));
            const digest=await checksum(file),size=fs.statSync(file).size;
            const uploaded=(await github.rest.repos.uploadReleaseAsset({...repo,release_id:staged.id,name:names.get(asset.name),data:fs.readFileSync(file),headers:{'content-type':asset.content_type||'application/octet-stream','content-length':size}})).data;
            if(uploaded.size!==size||uploaded.digest!==digest)throw Error(`Uploaded checksum mismatch: ${asset.name}`);
            fs.unlinkSync(file);
        }
        if(fingerprint(libraryAssets(await list(source.id)))!==fingerprint(assets))throw Error('latest changed while copying; nightly was not replaced');
        if(await masterIsBusy())throw Error('Master started publishing while copying; nightly was not replaced');
        await validate({source,assets,sha});
        previous=await optionalRelease(github,repo,'nightly');
        // Preserve the old release/assets until the fully staged snapshot is published.
        if(previous){
            await github.rest.repos.updateRelease({...repo,release_id:previous.id,tag_name:`nightly-previous-${context.runId}-${context.runAttempt||1}`,draft:true});
            previousMoved=true;
        }
        await github.rest.repos.updateRelease({...repo,release_id:staged.id,tag_name:'nightly',target_commitish:sha,draft:false,prerelease:true,make_latest:'false'});
        published=true;
        if(previous)await github.rest.repos.deleteRelease({...repo,release_id:previous.id});
        // Point the floating tag at the copied source, rather than an older master commit.
        try {await github.rest.git.updateRef({...repo,ref:'tags/nightly',sha,force:true});}
        catch(e){if(e.status!==422&&e.status!==404)throw e;await github.rest.git.createRef({...repo,ref:'refs/tags/nightly',sha});}
        core.info(`Published fresh nightly release for ${date}: ${assets.length} verified assets`);
    }catch(error){
        if(previousMoved&&!published){
            await github.rest.repos.updateRelease({...repo,release_id:previous.id,tag_name:'nightly',draft:false,prerelease:previous.prerelease,make_latest:'false'});
        }
        throw error;
    }finally{
        fs.rmSync(temp,{recursive:true,force:true});
        if(staged&&!published)await github.rest.repos.deleteRelease({...repo,release_id:staged.id});
        if(published)for(const tag of [stageTag,`nightly-previous-${context.runId}-${context.runAttempt||1}`]) {
            try {await github.rest.git.deleteRef({...repo,ref:`tags/${tag}`});}
            catch(e){if(e.status!==404&&e.status!==422)core.warning(`Temporary tag cleanup failed: ${tag}: ${e.message}`);}
        }
    }
}
exports.nightlyName=nightlyName;exports.renameMetadata=renameMetadata;
exports.integrationPlatforms=integrationPlatforms;
