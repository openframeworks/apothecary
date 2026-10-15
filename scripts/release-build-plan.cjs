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
function stateName(file, job, row) {return `build-state-${path.basename(file,'.yml')}-${job}-${hash(stable(row)).slice(0,16)}.json`;}
function matches(wanted, previous, assets, now = Date.now()) {
    if (previous?.schema !== 1 || previous.profile !== wanted.profile || !Number.isFinite(Date.parse(previous.publishedAt)) || now-Date.parse(previous.publishedAt) > 24*3600*1000 || Date.parse(previous.publishedAt)>now) return false;
    if (!Array.isArray(previous.assets) || !previous.assets.length || !previous.assets.every(a => assets.some(b => b.id === a.id && b.name === a.name && b.size === a.size && b.digest === a.digest && /^sha256:[0-9a-f]{64}$/.test(b.digest || '')))) return false;
    const names = Object.keys(wanted.formulas).sort();
    return JSON.stringify(names) === JSON.stringify(Object.keys(previous.formulas || {}).sort()) && names.every(name => wanted.formulas[name].key === previous.formulas[name].key);
}
async function plan({github,context,core,workflow: file,job:jobId}) {
    const config = yaml(file), rows = matrixRows(JSON.parse(fs.readFileSync('scripts/build-matrices.json','utf8'))[file][jobId]);
    const chosen = [], summary = [];
    let release, assets = [];
    const tag = file.endsWith('build-linux-modular.yml') ? 'latest-modular' : (context.payload.pull_request?.base.ref || context.ref.replace('refs/heads/','')) === 'master' ? 'nightly' : 'latest';
    if (!context.payload.pull_request && !context.ref.startsWith('refs/tags/')) {
        try {
            release = (await github.rest.repos.getReleaseByTag({...context.repo,tag})).data;
            assets = await github.paginate(github.rest.repos.listReleaseAssets,{...context.repo,release_id:release.id,per_page:100});
        } catch (error) {core.warning(`No release baseline: ${error.message}`);}
    }
    for (const row of rows) {
        let reason = 'missing or changed published output';
        try {
            const wanted = inputs(file,jobId,row);
            fs.mkdirSync('.build-plans',{recursive:true});
            fs.writeFileSync(path.join('.build-plans',stateName(file,jobId,row)),JSON.stringify(wanted));
            if (context.payload.pull_request) {
                const previous = inputs(file,jobId,row,context.payload.pull_request.base.sha);
                if (JSON.stringify(wanted.formulas) === JSON.stringify(previous.formulas) && wanted.profile === previous.profile) reason = '';
                else reason = 'PR changes selected recipes, dependencies or toolchain';
            } else if (context.ref.startsWith('refs/tags/')) reason = 'tag publication';
            else if (context.eventName === 'workflow_dispatch') reason = 'manual rebuild';
            else {
                const asset = assets.find(a => a.name === stateName(file,jobId,row));
                if (asset && asset.size < 4*1024*1024) {
                    const response = await github.rest.repos.getReleaseAsset({...context.repo,asset_id:asset.id,headers:{accept:'application/octet-stream'}});
                    const previous = JSON.parse(Buffer.from(response.data).toString('utf8'));
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
    core.setOutput('matrix',JSON.stringify({include:chosen.length ? chosen : rows.slice(0,1)}));
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
    const tag = file.endsWith('build-linux-modular.yml') ? 'latest-modular' : context.ref === 'refs/heads/master' ? 'nightly' : 'latest';
    const release = (await github.rest.repos.getReleaseByTag({...context.repo,tag})).data;
    const assets = await github.paginate(github.rest.repos.listReleaseAssets,{...context.repo,release_id:release.id,per_page:100});
    const publishedByName = new Map();
    for (const dir of ['out','xout']) {
        if (!fs.existsSync(dir)) continue;
        for (const name of fs.readdirSync(dir)) {
            if (!/^(?:openFrameworksLibs_|oF_).*\.(zip|tar\.bz2|tar\.gz)(\.sha256)?$/.test(name)) continue;
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
    const state = JSON.parse(fs.readFileSync(path.join(process.env.RUNNER_TEMP,'build-plans',stateName(file,jobId,row)),'utf8'));
    for (const [library, recipe] of Object.entries(state.formulas)) {
        const metadata = [];
        function inspect(dir) {
            if (!fs.existsSync(dir)) return;
            for (const entry of fs.readdirSync(dir,{withFileTypes:true})) {
                const file = path.join(dir,entry.name);
                if (entry.isDirectory()) inspect(file);
                else if (entry.isFile() && entry.name.endsWith('.pkl')) {
                    const text = fs.readFileSync(file,'utf8'), values = {};
                    for (const key of ['version','buildNumber','binary','binarySha','cppStandard','cStandard']) {
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
    const name = stateName(file,jobId,row), data = Buffer.from(JSON.stringify(state,null,2)+'\n');
    fs.writeFileSync(path.join('out',name),data);
    const old = assets.find(a => a.name === name);
    if (old) await github.rest.repos.deleteReleaseAsset({...context.repo,asset_id:old.id});
    await github.rest.repos.uploadReleaseAsset({...context.repo,release_id:release.id,name,data,headers:{'content-type':'application/json','content-length':data.length}});
    core.info(`Recorded ${name}: ${Object.keys(state.formulas).length} formulas, ${published.length} verified outputs`);
};
exports.inputs=inputs;exports.matrixRows=matrixRows;exports.matches=matches;exports.stateName=stateName;
