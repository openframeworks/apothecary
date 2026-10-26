const assert=require('node:assert/strict');
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {install,selectAssets,required}=require('../install-nightly-candidate.cjs');
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'nightly-candidate-test-'));
const digest=bytes=>'sha256:'+crypto.createHash('sha256').update(bytes).digest('hex');
const assetNames=[
    'openFrameworksLibs_latest_linux_64_gcc10.tar.bz2',
    ...['osx','macos'].flatMap(target=>[1,2,3].map(i=>`openFrameworksLibs_latest_${target}_${i}.tar.bz2`)),
    ...['armv7','arm64','x86_64'].map(arch=>`openFrameworksLibs_latest_android_${arch}.tar.bz2`),
    ...[32,64].map(arch=>`openFrameworksLibs_latest_emscripten_${arch}.tar.bz2`),
    ...[1,2].map(i=>`openFrameworksLibs_latest_vs_64_${i}.zip`)
];
const plan={schema:1,repository:'owner/repo',sourceSha:'a'.repeat(40),openframeworksSha:'b'.repeat(40),
    platforms:Object.keys(required),assets:assetNames.map((name,index)=>({id:index+1,name,size:1,digest:digest(Buffer.from('x'))}))};
(async()=>{try {
    assert.equal(selectAssets(plan,'linux').length,1);
    assert.equal(selectAssets(plan,'windows').length,2);
    for(const platform of ['macos','ios','tvos','android'])assert.equal(selectAssets(plan,platform).length,3);
    assert.equal(selectAssets(plan,'emscripten').length,2);
    assert.throws(()=>selectAssets({...plan,assets:[]},'windows'),/missing/);
    const staging=path.join(temp,'staging');fs.mkdirSync(staging);
    for(const name of [...required.linux,'libxml2','svgtiny']) {
        fs.mkdirSync(path.join(staging,name,'include'),{recursive:true});
        fs.writeFileSync(path.join(staging,name,'include','fixture.h'),`candidate ${name}`);
    }
    fs.symlinkSync('fixture.h',path.join(staging,'freetype','include','alias.h'));
    const archive=path.join(temp,'candidate.tar.bz2');
    execFileSync('tar',['-cjf',archive,...fs.readdirSync(staging)],{cwd:staging});
    const bytes=fs.readFileSync(archive),linux=selectAssets(plan,'linux')[0];
    linux.size=bytes.length;linux.digest=digest(bytes);
    const ofRoot=path.join(temp,'openFrameworks');fs.mkdirSync(ofRoot);
    fs.mkdirSync(path.join(ofRoot,'libs','freetype'),{recursive:true});
    fs.writeFileSync(path.join(ofRoot,'libs','freetype','old-library'),'stale');
    const downloaded=[];
    const receipt=await install({plan,ofRoot,platform:'linux',download:async(asset,file)=>{downloaded.push(asset.id);fs.writeFileSync(file,bytes);}});
    assert.deepEqual(downloaded,[linux.id],'download the frozen asset ID, not a tag lookup');
    assert.equal(receipt.openframeworksSha,plan.openframeworksSha);
    assert(!fs.existsSync(path.join(ofRoot,'libs','freetype','old-library')),'candidate replaces stale installed library contents');
    assert.equal(fs.readFileSync(path.join(ofRoot,'libs','freetype','include','fixture.h'),'utf8'),'candidate freetype');
    assert.equal(fs.readlinkSync(path.join(ofRoot,'libs','freetype','include','alias.h')),'fixture.h','preserve relative framework/header symlinks after temporary staging is removed');
    assert.equal(fs.readFileSync(path.join(ofRoot,'libs','freetype','include','alias.h'),'utf8'),'candidate freetype');
    assert(fs.existsSync(path.join(ofRoot,'addons','ofxSvg','libs','svgtiny','include','fixture.h')),'addon libraries use the consumer layout');
    const before=fs.readFileSync(path.join(ofRoot,'libs','freetype','include','fixture.h'));
    await assert.rejects(()=>install({plan,ofRoot,platform:'linux',download:async(asset,file)=>fs.writeFileSync(file,Buffer.from('bad'))}),/checksum mismatch/);
    assert.deepEqual(fs.readFileSync(path.join(ofRoot,'libs','freetype','include','fixture.h')),before,'failed verification does not replace installed libraries');
    fs.rmSync(path.join(staging,'FreeImage'),{recursive:true});
    execFileSync('tar',['-cjf',archive,...fs.readdirSync(staging)],{cwd:staging});
    const incomplete=fs.readFileSync(archive);linux.size=incomplete.length;linux.digest=digest(incomplete);
    await assert.rejects(()=>install({plan,ofRoot,platform:'linux',download:async(asset,file)=>fs.writeFileSync(file,incomplete)}),/incomplete/);
    for(const name of required.windows) {
        fs.mkdirSync(path.join(staging,name,'include'),{recursive:true});
        fs.writeFileSync(path.join(staging,name,'include','fixture.h'),`candidate ${name}`);
    }
    const zip=path.join(temp,'candidate.zip');
    execFileSync('cmake',['-E','tar','cf',zip,'--format=zip',...fs.readdirSync(staging)],{cwd:staging});
    const zipBytes=fs.readFileSync(zip);
    for(const asset of selectAssets(plan,'windows')){asset.size=zipBytes.length;asset.digest=digest(zipBytes);}
    await install({plan,ofRoot,platform:'windows',download:async(asset,file)=>fs.writeFileSync(file,zipBytes)});
    assert(fs.existsSync(path.join(ofRoot,'addons','ofxPoco','libs','poco','include','fixture.h')),'Windows ZIPs preserve the Poco addon destination');
    // Verify workflow wiring as well as the helper: tests must run before
    // promotion, and Windows setup must not overwrite the candidate afterward.
    const workflow=fs.readFileSync('.github/workflows/refresh-nightly.yml','utf8');
    assert(workflow.includes('needs: [plan, integration]'));
    assert(workflow.includes('MASTER_BUILD_RESULT: ${{ needs.integration.result }}'));
    assert(workflow.includes('override_build_gate:'));
    const integration=fs.readFileSync('.github/workflows/test-openframeworks-libraries.yml','utf8');
    assert(integration.includes('workflow_call:'));
    assert(integration.indexOf('- name: Install selected libraries')>integration.indexOf('- name: Install Windows build dependencies'));
    assert(integration.includes('scripts/ci/linux/64/build.sh'));
    assert(integration.includes('env GITHUB_WORKSPACE="$OF_ROOT" scripts/ci/ios/build.sh'));
    assert(integration.includes('env GITHUB_WORKSPACE="$OF_ROOT" scripts/ci/tvos/build.sh'));
    assert(integration.includes("ARCH: arm64-v8a"));
    assert(integration.includes('sdkmanager "ndk;$NDK"'));
    console.log('Nightly candidate: platform selections, frozen IDs, checksums, addon layout, stale-output replacement and workflow gate wiring passed');
} finally {fs.rmSync(temp,{recursive:true,force:true});}})().catch(error=>{console.error(error);process.exitCode=1;});
