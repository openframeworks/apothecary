// Install only frozen, digest-verified release assets; never resolve "latest" again.
const fs=require('node:fs');
const os=require('node:os');
const path=require('node:path');
const crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const {Readable}=require('node:stream');
const {pipeline}=require('node:stream/promises');
const common=['zlib','libpng','brotli','freetype','FreeImage','glm','json','fmt'];
const required={linux:[...common,'glew','glfw'],macos:common,ios:common,tvos:common,
    android:[...common,'openssl','curl'],emscripten:[...common,'glew','glfw'],windows:[...common,'openssl','poco']};
function selectAssets(plan,platform) {
    const names={
        linux:['openFrameworksLibs_latest_linux_64_gcc10.tar.bz2'],
        macos:[1,2,3].map(i=>`openFrameworksLibs_latest_osx_${i}.tar.bz2`),
        ios:[1,2,3].map(i=>`openFrameworksLibs_latest_macos_${i}.tar.bz2`),
        tvos:[1,2,3].map(i=>`openFrameworksLibs_latest_macos_${i}.tar.bz2`),
        android:['armv7','arm64','x86_64'].map(arch=>`openFrameworksLibs_latest_android_${arch}.tar.bz2`),
        emscripten:[32,64].map(arch=>`openFrameworksLibs_latest_emscripten_${arch}.tar.bz2`),
        windows:[1,2].map(i=>`openFrameworksLibs_latest_vs_64_${i}.zip`)
    }[platform];
    if(!names)throw Error(`Unsupported nightly integration platform: ${platform}`);
    return names.map(name=>{
        const found=plan.assets.filter(asset=>asset.name===name);
        if(found.length!==1)throw Error(`Candidate is missing or duplicates ${name}`);
        const asset=found[0];
        if(!Number.isSafeInteger(asset.id)||asset.id<=0||!/^sha256:[a-f0-9]{64}$/.test(asset.digest||''))throw Error(`Invalid candidate asset: ${name}`);
        return asset;
    });
}
async function install({plan,ofRoot,platform,download}) {
    if(plan.schema!==1||!plan.platforms?.includes(platform)||!/^[-\w.]+\/[-\w.]+$/.test(plan.repository||''))throw Error('Invalid nightly validation plan');
    const assets=selectAssets(plan,platform);
    const temp=fs.mkdtempSync(path.join(os.tmpdir(),'nightly-candidate-'));
    const staged=path.join(temp,'libs');fs.mkdirSync(staged);
    try {
        for(const asset of assets) {
            const file=path.join(temp,asset.name);
            if(download)await download(asset,file);
            else {
                const response=await fetch(`https://api.github.com/repos/${plan.repository}/releases/assets/${asset.id}`,{
                    headers:{Accept:'application/octet-stream',Authorization:`Bearer ${process.env.GH_TOKEN}`}});
                if(!response.ok)throw Error(`Download ${asset.name}: HTTP ${response.status}`);
                await pipeline(Readable.fromWeb(response.body),fs.createWriteStream(file));
            }
            const h=crypto.createHash('sha256');for await(const chunk of fs.createReadStream(file))h.update(chunk);
            if(fs.statSync(file).size!==asset.size||`sha256:${h.digest('hex')}`!==asset.digest)throw Error(`Candidate checksum mismatch: ${asset.name}`);
            const zip=asset.name.endsWith('.zip');
            const members=execFileSync(zip?'unzip':'tar',zip?['-Z1',file]:['-tf',file],{encoding:'utf8',maxBuffer:16*1024*1024}).trim().split('\n');
            if(members.some(name=>path.posix.isAbsolute(name)||name.split(/[\\/]/).includes('..')))throw Error(`Unsafe candidate archive: ${asset.name}`);
            execFileSync(zip?'unzip':'tar',zip?['-qo',file,'-d',staged]:['-xf',file,'-C',staged]);
            fs.unlinkSync(file);
        }
        for(const name of required[platform])if(!fs.existsSync(path.join(staged,name)))throw Error(`Candidate is incomplete for ${platform}: ${name}`);
        const addons={assimp:'ofxAssimpModelLoader',opencv:'ofxOpenCv',opencv5:'ofxOpenCv',ippicv:'ofxOpenCv',libusb:'ofxKinect',libfreenect:'ofxKinect',libxml2:'ofxSvg',svgtiny:'ofxSvg',oscpack:'ofxOsc',poco:'ofxPoco'};
        for(const entry of fs.readdirSync(staged,{withFileTypes:true})) {
            if(!entry.isDirectory())continue;
            if(!/^[A-Za-z0-9_+-]+$/.test(entry.name)||['openFrameworks','openFrameworksCompiled'].includes(entry.name))throw Error(`Unexpected candidate library: ${entry.name}`);
            const destination=addons[entry.name]?path.join(ofRoot,'addons',addons[entry.name],'libs',entry.name):path.join(ofRoot,'libs',entry.name);
            fs.rmSync(destination,{recursive:true,force:true});
            fs.mkdirSync(path.dirname(destination),{recursive:true});
            fs.cpSync(path.join(staged,entry.name),destination,{recursive:true,verbatimSymlinks:true});
        }
        const receipt={openframeworksSha:plan.openframeworksSha,sourceSha:plan.sourceSha,platform,assets};
        fs.writeFileSync(path.join(ofRoot,`.nightly-candidate-${platform}.json`),JSON.stringify(receipt,null,2)+'\n');
        console.log(`Installed ${assets.length} frozen candidate archives for ${platform}; SHA-256 verified`);
        return receipt;
    } finally {fs.rmSync(temp,{recursive:true,force:true});}
}
module.exports={install,selectAssets,required};
if(require.main===module) {
    const [manifest,ofRoot,platform]=process.argv.slice(2);
    if(!manifest||!ofRoot||!platform)throw Error('Usage: install-nightly-candidate.cjs PLAN OPENFRAMEWORKS_ROOT PLATFORM');
    install({plan:JSON.parse(fs.readFileSync(manifest,'utf8')),ofRoot,platform}).catch(error=>{console.error(error);process.exitCode=1;});
}
