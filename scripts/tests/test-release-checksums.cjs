const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const {sync, hashAsset} = require('../release-checksums.cjs');
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const context = {repo:{owner:'openframeworks',repo:'apothecary'},sha:'a'.repeat(40),runId:123};
const core = {info(){},warning(){}};

function fixture() {
    let nextId = 100, hashes = 0;
    const events = [], blobs = new Map(), releases = new Map();
    const latest = {id:1,tag_name:'latest',assets:[]}, modular = {id:2,tag_name:'latest-modular',assets:[]};
    releases.set('latest',latest); releases.set('latest-modular',modular);
    const add = (release,name,text,digest=true) => {
        const bytes = Buffer.from(text), asset={id:nextId++,name,size:bytes.length,state:'uploaded',updated_at:'2026-10-28T00:00:00Z',digest:digest ? 'sha256:'+hash(bytes) : null};
        release.assets.push(asset);blobs.set(asset.id,bytes);return asset;
    };
    const current=add(latest,'openFrameworksLibs_latest_linux_64_gcc10.tar.bz2','current');
    const legacy=add(latest,'openFrameworksLibs_latest_vs_2019_64_1.zip','legacy',false);
    const sidecar=add(latest,current.name+'.sha256',`${hash('current')}  ${current.name}\n`);
    const manifest=add(latest,current.name+'.manifest.json','{"schema":1}');
    const module=add(modular,'oF_brotli_msys2_clangarm64.zip','modular');
    const lookup=id=>[...releases.values()].flatMap(r=>r.assets).find(a=>a.id===id);
    const repos={
        async getReleaseByTag({tag}) {if(!releases.has(tag))throw Object.assign(Error('Not Found'),{status:404});return {data:releases.get(tag)};},
        listReleaseAssets:'assets',
        async createRelease(args) {assert.equal(args.make_latest,'false');assert.equal(args.prerelease,true);const release={id:nextId++,tag_name:args.tag_name,assets:[]};releases.set(args.tag_name,release);events.push(['create',args.tag_name]);return {data:release};},
        async getReleaseAsset({asset_id}) {return {data:blobs.get(asset_id)};},
        async uploadReleaseAsset({release_id,name,data}) {events.push(['upload',name]);return {data:add([...releases.values()].find(r=>r.id===release_id),name,data)};},
        async updateReleaseAsset({asset_id,name}) {events.push(['rename',name]);lookup(asset_id).name=name;return {data:lookup(asset_id)};},
        async deleteReleaseAsset({asset_id}) {const a=lookup(asset_id);events.push(['delete',a.name]);for(const r of releases.values())r.assets=r.assets.filter(a=>a.id!==asset_id);}
    };
    const github={rest:{repos},async paginate(_,args){return [...releases.values()].find(r=>r.id===args.release_id).assets.map(a=>({...a}));}};
    const digestAsset=async asset=>{hashes++;return hash(blobs.get(asset.id));};
    return {github,digestAsset,events,blobs,releases,latest,modular,current,legacy,sidecar,manifest,module,add,get hashes(){return hashes;}};
}
const run=(f,extra={})=>sync({github:f.github,digestAsset:f.digestAsset,context,core,...extra});
const text=(f,name)=>f.blobs.get(f.releases.get('sha256').assets.find(a=>a.name===name).id).toString();

(async()=>{
    const f=fixture(), archiveIDs=[f.current.id,f.legacy.id,f.module.id];
    const preview=await run(f,{dryRun:true});
    assert.deepEqual(preview.map(r=>r.archives),[2,1]);
    assert.deepEqual(f.events,[],'dry-run never mutates releases');
    await run(f);
    assert.equal(text(f,'latest.SHA256SUMS'),`${hash('current')}  ${f.current.name}\n${hash('legacy')}  ${f.legacy.name}\n`);
    assert.equal(text(f,'latest-modular.SHA256SUMS'),`${hash('modular')}  ${f.module.name}\n`);
    assert(!f.latest.assets.some(a=>a.id===f.sidecar.id));
    assert(f.latest.assets.some(a=>a.id===f.manifest.id),'package descriptors are outside the checksum migration');
    assert.deepEqual([...f.latest.assets,...f.modular.assets].filter(a=>archiveIDs.includes(a.id)).map(a=>a.id),archiveIDs,'library assets keep IDs and URLs');
    assert(f.events.findIndex(e=>e[0]==='rename'&&e[1]==='latest.sha256.json')<f.events.findIndex(e=>e[0]==='delete'&&e[1]===f.sidecar.name),'verify both destination files before source cleanup');
    const events=f.events.length,hashes=f.hashes;
    await run(f);
    assert.equal(f.events.length,events,'unchanged checksums retain their asset IDs');
    assert.equal(f.hashes,hashes,'legacy hashes are cached against exact source identity');
    f.legacy.updated_at='2026-10-29T00:00:00Z';
    await run(f);
    assert.equal(f.hashes,hashes+1,'changed legacy identity must be rehashed');

    const mismatch=fixture();mismatch.blobs.set(mismatch.sidecar.id,Buffer.from('0'.repeat(64)+'  '+mismatch.current.name+'\n'));
    mismatch.sidecar.size=mismatch.blobs.get(mismatch.sidecar.id).length;mismatch.sidecar.digest='sha256:'+hash(mismatch.blobs.get(mismatch.sidecar.id));
    await assert.rejects(run(mismatch),/Existing checksum differs/);
    assert.deepEqual(mismatch.events,[],'inconsistent sidecars cannot be silently discarded');

    const failed=fixture();
    failed.github.rest.repos.uploadReleaseAsset=async()=>{throw Error('upload failed');};
    await assert.rejects(run(failed),/upload failed/);
    assert(failed.latest.assets.some(a=>a.id===failed.sidecar.id),'failed destination upload retains source sidecar');

    const corrupt=fixture(), upload=corrupt.github.rest.repos.uploadReleaseAsset;
    corrupt.github.rest.repos.uploadReleaseAsset=async args=>{const result=await upload(args);corrupt.blobs.set(result.data.id,Buffer.from('wrong'));return result;};
    await assert.rejects(run(corrupt),/Metadata size differs/);
    assert(corrupt.latest.assets.some(a=>a.id===corrupt.sidecar.id));

    const moving=fixture(), paginate=moving.github.paginate;let listings=0;
    moving.github.paginate=async(...args)=>{const result=await paginate(...args);if(args[1].release_id===1&&++listings===2)result.find(a=>a.id===moving.current.id).id+=1000;return result;};
    await assert.rejects(run(moving),/moved while/);
    assert.deepEqual(moving.events,[],'source movement stops publication before cleanup');

    const post=fixture(), rename=post.github.rest.repos.updateReleaseAsset;
    post.github.rest.repos.updateReleaseAsset=async args=>{const result=await rename(args);if(args.name==='latest.sha256.json')post.current.updated_at='changed';return result;};
    await assert.rejects(run(post),/moved during publication/);
    assert(post.latest.assets.some(a=>a.id===post.sidecar.id));

    const invalid=fixture();invalid.current.digest='md5:unsupported';
    await assert.rejects(run(invalid),/Invalid published digest/);
    assert.deepEqual(invalid.events,[]);
    const unavailable=fixture();unavailable.digestAsset=async()=>{throw Error('download unavailable');};
    await assert.rejects(run(unavailable),/download unavailable/);
    assert.deepEqual(unavailable.events,[]);

    const originalFetch=global.fetch;
    try {
        global.fetch=async url=>{assert.equal(url,'https://github.com/openframeworks/apothecary/releases/download/latest/legacy.zip');return {ok:true,body:(async function*(){yield Buffer.from('leg');yield Buffer.from('acy');})()};};
        assert.equal(await hashAsset({name:'legacy.zip',size:6},'latest',context.repo),hash('legacy'));
        await assert.rejects(hashAsset({name:'legacy.zip',size:7},'latest',context.repo),/size changed/);
    } finally {global.fetch=originalFetch;}
    console.log('Release checksums: all-platform coverage, verified relocation, dry-run, idempotency, legacy hashing/cache, source movement and publication failures passed');
})().catch(error=>{console.error(error);process.exitCode=1;});
