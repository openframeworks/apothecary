// Cheap Linux planning; release sidecars are separate per workflow/job/matrix.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const stable = value => JSON.stringify(value, (_, item) => item && typeof item === 'object' && !Array.isArray(item) ? Object.fromEntries(Object.entries(item).sort(([a],[b]) => a.localeCompare(b))) : item);
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const git = (...args) => execFileSync('git', args, {encoding:'utf8'}).trim();
const read = (file, ref) => ref ? execFileSync('git',['show',`${ref}:${file}`],{encoding:'utf8'}) : fs.readFileSync(file, 'utf8');
const tracked = ref => (ref ? git('ls-tree','-r','--name-only',ref) : git('ls-files')).split('\n');
function yaml(file) {
    return JSON.parse(execFileSync('ruby',['-ryaml','-rjson','-e','puts JSON.generate(YAML.load_file(ARGV[0]))',file],{encoding:'utf8'}));
}
function matrixRows(matrix) {
    if (!Object.keys(matrix).some(k => !['include','exclude'].includes(k))) return (matrix.include || []).map(row => ({...row}));
    const axes = Object.entries(matrix).filter(([k]) => !['include','exclude'].includes(k));
    let rows = axes.length ? [{}] : [];
    for (const [key, values] of axes) rows = rows.flatMap(row => values.map(value => ({...row,[key]:value})));
    rows = rows.filter(row => !(matrix.exclude || []).some(ex => Object.entries(ex).every(([k,v]) => JSON.stringify(row[k]) === JSON.stringify(v))));
    for (const extra of matrix.include || []) {
        let applied = false;
        for (const row of rows) if (axes.every(([key]) => extra[key] === undefined || JSON.stringify(row[key]) === JSON.stringify(extra[key]))) {
            Object.assign(row, extra); applied = true;
        }
        if (!applied) rows.push({...extra});
    }
    return rows;
}
function resolve(value, row) {
    return String(value).replace(/\$\{\{\s*matrix\.([\w.]+)\s*\}\}/g, (_, key) => {
        const result = key.split('.').reduce((obj,k) => obj?.[k],row);
        if (result === undefined) throw new Error(`Unknown matrix value ${key}`);
        return String(result);
    });
}
function inputs(file, jobId, row, ref) {
    const workflow = yaml(file), job = workflow.jobs[jobId];
    const env = Object.fromEntries(Object.entries({...workflow.env,...job.env}).filter(([key]) => !/SECRET|TOKEN|PASSWORD/i.test(key)).map(([key,value]) => [key,resolve(value,row)]));
    env.ARCH = String(row.ARCH ?? row.arch ?? row.flavor ?? row.cfg?.arch ?? env.ARCH ?? '64');
    env.BUNDLE = String(row.bundle ?? env.BUNDLE ?? 0);
    // Plan individual library records even when native execution shares a runner.
    if (row.library) {env.FORMULAS_OVERRIDE=String(row.library);env.PACKAGE_LIBS=String(row.library);}
    if (!/^[a-z0-9]+$/.test(env.TARGET || '')) throw new Error('Unresolved target');
    const selectionScript = read('scripts/calculate_formulas.sh',ref);
    const libraries = execFileSync('bash',['-c',`${selectionScript}\nprintf '\\nPLANNER_FORMULAS=%s\\n' "\${FORMULAS[*]}"`], {env:{...process.env,...env},encoding:'utf8'}).split('\n').find(line => line.startsWith('PLANNER_FORMULAS=')).slice(17).trim().split(/\s+/).filter(Boolean);
    const files = tracked(ref);
    const profile = hash(stable({schema:1,workflow:read(file,ref),matrix:JSON.parse(read('scripts/build-matrices.json',ref))[file][jobId],row,env}));
    const shared = files.filter(p => p === 'apothecary/apothecary' || p === 'apothecary/configure' || p.startsWith('apothecary/toolchains/') || /^scripts\/(build\.sh|calculate_formulas\.sh|package.*|export_config\.sh|secure\.sh|load\.sh|save\.sh|release-build-plan\.cjs|release-toolchain\.sh|cache-toolchain\.sh)$/.test(p) || p.toLowerCase().startsWith(`scripts/${env.TARGET}/`) || p.startsWith('scripts/artifact/'));
    function formula(lib, seen = new Set()) {
        if (seen.has(lib)) return [];
        seen.add(lib);
        const candidates = [`apothecary/formulas/${lib}.sh`,`apothecary/formulas/${lib}/${lib}.sh`,`apothecary/formulas/_depends/${lib}.sh`].filter(p => files.includes(p));
        if (candidates.length !== 1) throw new Error(`Cannot resolve formula ${lib}`);
        const filename = candidates[0], text = read(filename,ref), dir = path.posix.dirname(filename);
        const selected = ['apothecary/formulas','apothecary/formulas/_depends'].includes(dir) ? [filename] : files.filter(p => p.startsWith(`${dir}/`));
        const dep = text.match(/^FORMULA_DEPENDS=\(([^\n]*)\)/m);
        if (/^\s*FORMULA_DEPENDS[+]?=/m.test(text) && (!dep || /[^\w\s'"-]/.test(dep[1]))) throw new Error(`Nonliteral dependencies: ${lib}`);
        for (const name of (dep?.[1] || '').replace(/['"]/g,'').trim().split(/\s+/).filter(Boolean)) selected.push(...formula(name,seen));
        return selected;
    }
    const formulas = {};
    for (const lib of libraries) {
        const selected = [...new Set([...shared,...formula(lib)])].sort();
        formulas[lib] = {key:hash(profile+'\n'+selected.map(p => `${p}\0${hash(read(p,ref))}`).join('\n'))};
        const src = files.find(p => p === `apothecary/formulas/${lib}.sh` || p === `apothecary/formulas/${lib}/${lib}.sh` || p === `apothecary/formulas/_depends/${lib}.sh`);
        for (const field of ['VER','BUILD_ID','SHA256','SOURCE_COMMIT']) formulas[lib][field] = read(src,ref).match(new RegExp(`^${field}=(.*)$`,'m'))?.[1] || '';
    }
    return {schema:1,workflow:file,job:jobId,matrix:row,target:env.TARGET,profile,formulas};
}
// Emit and read a data-only Pkl subset. Never evaluate downloaded Pkl code.
function pklString(value) {
    return '"'+Array.from(value, ch => {
        const code=ch.codePointAt(0);
        if(code<32)return `\\u{${code.toString(16).padStart(4,'0')}}`;
        return ch==='"'||ch==='\\' ? '\\'+ch : ch;
    }).join('')+'"';
}
function renderPkl(state) {
    function value(item, depth) {
        if (item === null) return 'null';
        if (typeof item === 'string') return pklString(item);
        if (typeof item === 'number' || typeof item === 'boolean') return String(item);
        const pad='  '.repeat(depth), inner=pad+'  ';
        if (Array.isArray(item)) return 'new Listing {\n'+item.map(v=>inner+value(v,depth+1)).join('\n')+'\n'+pad+'}';
        return 'new Mapping {\n'+Object.entries(item).map(([k,v])=>inner+'['+pklString(k)+'] = '+value(v,depth+1)).join('\n')+'\n'+pad+'}';
    }
    return Object.entries(state).filter(([,v])=>v!==undefined).map(([k,v])=>k+' = '+value(v,0)).join('\n')+'\n';
}
function parsePkl(text) {
    const tokens=text.match(/"(?:\\.|[^"\\])*"|[A-Za-z_][A-Za-z_0-9]*|-?\d+(?:\.\d+)?|[{}\[\]=]|\S/g)||[];
    let i=0;
    const take=expected=>{const token=tokens[i++];if(expected!==undefined&&token!==expected)throw Error('Invalid build-state Pkl');return token;};
    function string(token) {return JSON.parse(token.replace(/\\u\{([0-9a-f]{4})\}/gi,'\\u$1'));}
    function value() {
        const token=take();
        if(token?.startsWith('"'))return string(token);
        if(token==='null')return null;
        if(token==='true'||token==='false')return token==='true';
        if(/^-?\d/.test(token||''))return Number(token);
        if(token!=='new')throw Error('Unsupported build-state Pkl value');
        const kind=take();if(!['Mapping','Listing'].includes(kind))throw Error('Unsupported Pkl collection');take('{');
        const result=kind==='Listing'?[]:Object.create(null);
        while(tokens[i]!=='}') {
            if(i>=tokens.length)throw Error('Unterminated Pkl collection');
            if(kind==='Listing')result.push(value());
            else {take('[');const key=string(take());take(']');take('=');result[key]=value();}
        }
        take('}');return result;
    }
    const result=Object.create(null);
    while(i<tokens.length){const key=take();if(!/^[A-Za-z_][A-Za-z_0-9]*$/.test(key))throw Error('Invalid Pkl property');take('=');result[key]=value();}
    return result;
}
exports.renderPkl=renderPkl;exports.parsePkl=parsePkl;

function stateName(file, job, row) {
    const platform=path.basename(file,'.yml').replace(/^build-/, '').replace(/-modular$/, '');
    const part=value=>encodeURIComponent(String(value)).replace(/-/g,'%2D');
    const parts=row.library ? [part(row.library),platform] : [platform];
    const standardJobs=['build',`build-${platform}`,`build-${platform}-platforms`, 'build-vs2022-64', 'build-vs2026'];
    if(!standardJobs.includes(job))parts.push('job',part(job));
    // These describe runner setup, not independent output variants. Their values
    // still participate in profile/recipe fingerprints inside the record.
    const setup=new Set(['library','runner','arch_flags','artifact_target','sysroot','prefix','qemu_arch','target']);
    for(const [key,value] of Object.entries(row).sort(([a],[b])=>a.localeCompare(b))) {
        if(setup.has(key))continue;
        parts.push(part(key.toLowerCase()),part(value && typeof value==='object' ? stable(value) : value));
    }
    return parts.join('-')+'.pkl';
}
function matches(wanted, previous, assets, now = Date.now()) {
    if (previous?.schema !== 1 || previous.profile !== wanted.profile || !Number.isFinite(Date.parse(previous.publishedAt)) || Date.parse(previous.publishedAt)>now) return false;
    if (!Array.isArray(previous.assets) || !previous.assets.length || !previous.assets.every(a => assets.some(b => b.id === a.id && b.name === a.name && b.size === a.size && b.digest === a.digest && /^sha256:[0-9a-f]{64}$/.test(b.digest || '')))) return false;
    const names = Object.keys(wanted.formulas).sort();
    return JSON.stringify(names) === JSON.stringify(Object.keys(previous.formulas || {}).sort()) && names.every(name => wanted.formulas[name].key === previous.formulas[name].key);
}
function groupLibraries(rows) {
    const groups=new Map();
    for(const row of rows) {
        const {library,...platform}=row, key=stable(platform);
        if(!groups.has(key))groups.set(key,{...platform,libraries:[],entries:[]});
        const group=groups.get(key);
        group.libraries.push(library);group.entries.push(row);
    }
    return [...groups.values()];
}
function channel(file, context) {
    return file.endsWith('build-linux-modular.yml') ? 'modular' :
        (context.payload.pull_request?.base.ref || context.ref.replace('refs/heads/','')) === 'master' ? 'nightly' : 'latest';
}
function publishedStateName(file, job, row, context) {return `${channel(file,context)}-${stateName(file,job,row)}`;}
async function stateRelease(github, context, create = false) {
    try {return (await github.rest.repos.getReleaseByTag({...context.repo,tag:'build-state'})).data;}
    catch (error) {
        if (!create || error.status !== 404) throw error;
        try {
            return (await github.rest.repos.createRelease({...context.repo,tag_name:'build-state',target_commitish:context.sha,
                name:'Build state manifests',body:'Machine-readable build records. Library downloads are on latest, nightly and latest-modular.',
                prerelease:true,make_latest:'false'})).data;
        } catch (race) {
            if (race.status !== 422) throw race;
            return (await github.rest.repos.getReleaseByTag({...context.repo,tag:'build-state'})).data;
        }
    }
}
async function plan({github,context,core,workflow: file,job:jobId}) {
    const config = yaml(file), rows = matrixRows(JSON.parse(fs.readFileSync('scripts/build-matrices.json','utf8'))[file][jobId]);
    const chosen = [], summary = [];
    let release, assets = [], states = [];
    const tag = file.endsWith('build-linux-modular.yml') ? 'latest-modular' : (context.payload.pull_request?.base.ref || context.ref.replace('refs/heads/','')) === 'master' ? 'nightly' : 'latest';
    if (!context.payload.pull_request && !context.ref.startsWith('refs/tags/')) {
        try {
            release = (await github.rest.repos.getReleaseByTag({...context.repo,tag})).data;
            assets = await github.paginate(github.rest.repos.listReleaseAssets,{...context.repo,release_id:release.id,per_page:100});
            const metadata = await stateRelease(github,context);
            states = await github.paginate(github.rest.repos.listReleaseAssets,{...context.repo,release_id:metadata.id,per_page:100});
        } catch (error) {core.warning(`No release baseline: ${error.message}`);}
    }
    for (const row of rows) {
        let reason = 'missing or changed published output';
        try {
            const wanted = inputs(file,jobId,row);
            fs.mkdirSync('.build-plans',{recursive:true});
            fs.writeFileSync(path.join('.build-plans',stateName(file,jobId,row)),renderPkl(wanted));
            if (context.payload.pull_request) {
                const previous = inputs(file,jobId,row,context.payload.pull_request.base.sha);
                if (JSON.stringify(wanted.formulas) === JSON.stringify(previous.formulas) && wanted.profile === previous.profile) reason = '';
                else reason = 'PR changes selected recipes, dependencies or toolchain';
            } else if (context.ref.startsWith('refs/tags/')) reason = 'tag publication';
            else if (context.eventName === 'workflow_dispatch') reason = 'manual rebuild';
            else {
                const asset = states.find(a => a.name === publishedStateName(file,jobId,row,context));
                if (asset && asset.size < 4*1024*1024) {
                    const response = await github.rest.repos.getReleaseAsset({...context.repo,asset_id:asset.id,headers:{accept:'application/octet-stream'}});
                    const previous = parsePkl(Buffer.from(response.data).toString('utf8'));
                    if (matches(wanted,previous,assets)) reason = '';
                }
            }
        } catch (error) {reason = `conservative rebuild: ${error.message}`;}
        if (reason) chosen.push(row);
        summary.push([JSON.stringify(row),reason || 'unchanged; runner skipped']);
    }
    const disabled = String(config.env?.DISABLE_WORKFLOW || 'false') === 'true';
    core.setOutput('build_needed',String(!disabled && chosen.length > 0));
    // Keep a syntactically valid matrix even when the job-level if skips it.
    const execution = file.endsWith('build-linux-modular.yml') ? groupLibraries(chosen.length ? chosen : rows.slice(0,1)) : chosen.length ? chosen : rows.slice(0,1);
    core.setOutput('matrix',JSON.stringify({include:execution}));
    core.setOutput('workflow_disabled',String(disabled));
    await core.summary.addHeading('Platform build plan').addTable([['Variant','Decision'],...summary]).write();
    if (file.endsWith('/build-ios.yml')) {
        let finalize = !disabled && chosen.length > 0;
        for (const target of ['macos','tvos','catos','xros']) {
            const other = `.github/workflows/build-${target}.yml`;
            const job = Object.keys(JSON.parse(fs.readFileSync('scripts/build-matrices.json','utf8'))[other])[0];
            await plan({github,context,workflow:other,job,core:{...core,setOutput:(key,value) => {if (key === 'build_needed' && value === 'true') finalize=true;}}});
        }
        core.setOutput('apple_finalize',String(finalize));
    }
}
exports.plan=plan;
exports.record = async ({github,context,core,workflow:file,job:jobId,matrix:row}) => {
    if (context.eventName !== 'push' || !['refs/heads/bleeding','refs/heads/master'].includes(context.ref)) return;
    if (Array.isArray(row.entries)) {
        for (const entry of row.entries) await exports.record({github,context,core,workflow:file,job:jobId,matrix:entry});
        return;
    }
    const tag = file.endsWith('build-linux-modular.yml') ? 'latest-modular' : context.ref === 'refs/heads/master' ? 'nightly' : 'latest';
    const release = (await github.rest.repos.getReleaseByTag({...context.repo,tag})).data;
    const assets = await github.paginate(github.rest.repos.listReleaseAssets,{...context.repo,release_id:release.id,per_page:100});
    const publishedByName = new Map();
    for (const dir of ['out','xout']) {
        if (!fs.existsSync(dir)) continue;
        for (const name of fs.readdirSync(dir)) {
            if (!/^(?:openFrameworksLibs_|oF_).*\.(zip|tar\.bz2|tar\.gz)(\.sha256)?$/.test(name)) continue;
            if (row.library && !name.startsWith(`oF_${row.library}_`)) continue;
            const archive = name.replace(/\.sha256$/,''), asset = assets.find(a => a.name === archive);
            if (!asset) continue; // Raw intermediate bundles are not final release assets.
            const file = path.join(dir,name);
            let digest;
            if (name.endsWith('.sha256')) digest = fs.readFileSync(file,'utf8').match(/^[0-9a-f]{64}/)?.[0];
            else {
                const h = crypto.createHash('sha256'), fd = fs.openSync(file,'r'), chunk = Buffer.alloc(1024*1024);
                try {let n; while ((n=fs.readSync(fd,chunk,0,chunk.length,null))) h.update(chunk.subarray(0,n));} finally {fs.closeSync(fd);}
                digest = h.digest('hex');
                if (fs.statSync(file).size !== asset.size) throw new Error(`Published size differs: ${archive}`);
            }
            if (asset.digest !== `sha256:${digest}`) throw new Error(`Published digest differs: ${archive}`);
            publishedByName.set(archive,{id:asset.id,name:archive,size:asset.size,digest:asset.digest});
        }
    }
    const published = [...publishedByName.values()];
    if (!published.length) throw new Error('No verified final release outputs; refusing to record a successful baseline');
    const state = parsePkl(fs.readFileSync(path.join(process.env.RUNNER_TEMP,'build-plans',stateName(file,jobId,row)),'utf8'));
    for (const [library, recipe] of Object.entries(state.formulas)) {
        const metadata = [];
        function inspect(dir) {
            if (!fs.existsSync(dir)) return;
            for (const entry of fs.readdirSync(dir,{withFileTypes:true})) {
                const file = path.join(dir,entry.name);
                if (entry.isDirectory()) inspect(file);
                else if (entry.isFile() && entry.name.endsWith('.pkl')) {
                    const text = fs.readFileSync(file,'utf8'), values = {};
                    for (const key of ['version','buildNumber','binary','binarySha','cppStandard','cStandard','architecture','sdk','ndk','androidApi','emsdkVersion','compiler','compilerVersion','buildCommit','buildRunId','runnerImage','cFlags','cxxFlags']) {
                        const match = text.match(new RegExp(`^${key} = "([^"\\n]*)"$`,'m'));
                        if (match) values[key] = match[1];
                    }
                    if (Object.keys(values).length) metadata.push({file,...values});
                }
            }
        }
        inspect(path.join('out',library,'lib')); inspect(path.join('out',library,'bin'));
        if (metadata.length) recipe.installed = metadata;
    }
    state.publishedAt = new Date().toISOString(); state.commit = context.sha; state.runId = context.runId; state.assets = published;
    state.toolchain = execFileSync('bash',['scripts/release-toolchain.sh'],{encoding:'utf8'});
    state.channel = channel(file,context); state.release = tag; state.releaseId = release.id;
    const metadata = await stateRelease(github,context,true);
    const states = await github.paginate(github.rest.repos.listReleaseAssets,{...context.repo,release_id:metadata.id,per_page:100});
    const name = publishedStateName(file,jobId,row,context), data = Buffer.from(renderPkl(state));
    fs.writeFileSync(path.join('out',name),data);
    const old = states.find(a => a.name === name);
    if (old) await github.rest.repos.deleteReleaseAsset({...context.repo,asset_id:old.id});
    await github.rest.repos.uploadReleaseAsset({...context.repo,release_id:metadata.id,name,data,headers:{'content-type':'application/vnd.apple.pkl','content-length':data.length}});
    core.info(`Recorded ${name}: ${Object.keys(state.formulas).length} formulas, ${published.length} verified outputs`);
};
exports.inputs=inputs;exports.matrixRows=matrixRows;exports.matches=matches;exports.stateName=stateName;

exports.groupLibraries=groupLibraries;
