const assert=require('node:assert/strict');
const fs=require('node:fs');
const crypto=require('node:crypto');
const helper=require('../nightly-snapshot.cjs');
const digest=b=>'sha256:'+crypto.createHash('sha256').update(b).digest('hex');
async function scenario({dryRun=false,corrupt=false,changed=false,publishFail=false,busy=false}={}) {
    const archive=Buffer.from('original library bytes');
    const data=new Map([[1,archive],[2,Buffer.from(digest(archive).slice(7)+'  openFrameworksLibs_latest_osx.tar.bz2\n')],[3,Buffer.from(JSON.stringify({file:'openFrameworksLibs_latest_osx.tar.bz2',buildTime:'2026-01-01'}))]]);
    const assets=[{id:1,name:'openFrameworksLibs_latest_osx.tar.bz2'},{id:2,name:'openFrameworksLibs_latest_osx.tar.bz2.sha256'},{id:3,name:'openFrameworksLibs_latest_osx.tar.bz2.manifest.json'}].map(a=>({...a,size:data.get(a.id).length,digest:digest(data.get(a.id)),updated_at:'2026-10-14'}));
    assets.push({id:4,name:'latest-build-state-test.json',size:2,digest:digest(Buffer.from('{}'))});
    let listings=0,rolledBack=false,published=false;const deleted=[],uploads=[],updates=[];
    const github={paginate:async(endpoint,args)=>{
        if(endpoint==='runs')return busy ? [{path:'.github/workflows/build-macos.yml'}] : [];
        listings++;return changed&&listings>1 ? assets.slice(1) : assets;
    },rest:{actions:{listWorkflowRunsForRepo:'runs'},git:{getRef:async()=>({data:{object:{type:'commit',sha:'a'.repeat(40)}}}),updateRef:async()=>{},deleteRef:async()=>{}},repos:{
        listReleaseAssets:'assets',getReleaseByTag:async({tag})=>({data:{id:tag==='latest'?10:20,tag_name:tag,html_url:'https://example.invalid/latest',prerelease:true}}),
        createRelease:async args=>{assert.equal(args.draft,true);assert.match(args.body,/No compilation/);return {data:{id:30}};},
        uploadReleaseAsset:async args=>{assert.equal(args.release_id,30);uploads.push({name:args.name,bytes:Buffer.from(args.data)});return {data:{size:args.data.length,digest:digest(args.data)}};},
        updateRelease:async args=>{updates.push(args);if(args.release_id===30&&args.draft===false){if(publishFail)throw Error('publish refused');published=true;}if(args.release_id===20&&args.tag_name==='nightly')rolledBack=true;return {data:args};},
        deleteRelease:async args=>{deleted.push(args.release_id);}
    }}};
    let failure;
    try {await helper.refresh({github,context:{repo:{owner:'owner',repo:'repo'},runId:123},core:{info(){},notice(){},warning(){}},dryRun,now:new Date('2026-10-15T03:17:00Z'),download:async(asset,file)=>fs.writeFileSync(file,corrupt?Buffer.from('corrupt'):data.get(asset.id))});}
    catch(e){failure=e;}
    return {failure,published,rolledBack,uploads,deleted,updates};
}
(async()=>{
    const ok=await scenario();assert(!ok.failure);assert(ok.published);assert.deepEqual(ok.deleted,[20]);assert.equal(ok.uploads.length,3,'state JSON excluded');
    assert.equal(ok.uploads[0].name,'openFrameworksLibs_nightly_osx.tar.bz2');assert.equal(ok.uploads[0].bytes.toString(),'original library bytes');
    assert.match(ok.uploads[1].bytes.toString(),/openFrameworksLibs_nightly_osx/);
    const manifest=JSON.parse(ok.uploads[2].bytes);assert.equal(manifest.file,'openFrameworksLibs_nightly_osx.tar.bz2');assert.equal(manifest.buildTime,'2026-01-01');
    const corrupt=await scenario({corrupt:true});assert.match(corrupt.failure.message,/checksum mismatch/);assert.deepEqual(corrupt.deleted,[30]);assert.equal(corrupt.updates.length,0,'old nightly untouched on staging failure');
    const changed=await scenario({changed:true});assert.match(changed.failure.message,/latest changed/);assert.equal(changed.updates.length,0);
    const rollback=await scenario({publishFail:true});assert(rollback.rolledBack);assert.deepEqual(rollback.deleted,[30],'old release is retained on failed switch');
    const dry=await scenario({dryRun:true});assert.equal(dry.uploads.length,0);assert.equal(dry.updates.length,0);
    const busy=await scenario({busy:true});assert.equal(busy.uploads.length,0);
    console.log('Nightly snapshots: verified staging, original bytes/timestamps, filename mapping, state exclusion, source changes, rollback and dry-run passed');
})().catch(e=>{console.error(e);process.exitCode=1;});
