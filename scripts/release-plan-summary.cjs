// Presentation only: never use published history to change PR build selection.
const escape = value => String(value ?? '').replace(/[&<>"']/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[ch]));
const literal = value => String(value ?? '').trim().replace(/^(['"])(.*?)\1(?:\s+#.*)?$/, '$2') || 'Not declared';
const variant = row => Object.entries(row).map(([key,value]) => `${key}=${typeof value === 'object' ? JSON.stringify(value) : value}`).join(', ') || 'default';
const fields = ['BUILD_PROFILE_ID','TARGET','ARCH','BUNDLE','SDK','NDK','ANDROID_API','EMSDK_VERSION','PTHREADS_ENABLED','DEVELOPER_DIR','GCC','GCC_VERSION','CC','CXX','VS_VER','VS_STUDIO','WINDOWS_SDK_VERSION','MSYSTEM','C_STANDARD','CPP_STANDARD'];
function environment(config, jobId, row) {
    const job = config.jobs[jobId];
    const resolve = value => String(value).replace(/\$\{\{\s*matrix\.([\w.]+)\s*\}\}/g, (expression, key) => {
        const item = key.split('.').reduce((obj,k) => obj?.[k],row);
        return item === undefined ? expression : String(item);
    }).replace(/\$\{\{[^}]*secrets\.[^}]*\}\}/gi, '[redacted]');
    const env = {...config.env,...job.env};
    const result = [];
    const archs = job.steps?.find(step => step.uses === './.github/actions/platform-artifacts' && step.with?.archs)?.with.archs;
    if (archs) result.push(['Architectures',resolve(archs)]);
    const xcode = String(env.DEVELOPER_DIR || '').match(/Xcode_([^/]+)\.app/);
    if (xcode) result.push(['Xcode',xcode[1]]);
    if (job['runs-on']) result.push(['Runner',resolve(row.runner ?? job['runs-on'])]);
    if (job.container) result.push(['Container',resolve(typeof job.container === 'string' ? job.container : job.container.image)]);
    for (const key of fields) if (env[key] !== undefined) result.push([key,resolve(env[key])]);
    // Some workflows set architecture or SDK versions only at step scope.
    for (const key of ['ARCH','SDK','NDK','API','flavor']) {
        if (row[key] !== undefined && env[key] === undefined) result.push([key,String(row[key])]);
    }
    if (row.arch !== undefined && env.ARCH === undefined) result.push(['ARCH',String(row.arch)]);
    if (row.cfg) for (const key of ['arch','gcc','distro']) if (row.cfg[key] !== undefined) result.push([key.toUpperCase(),String(row.cfg[key])]);
    return result;
}
function lastBuild(recipe, state) {
    if (!recipe) return 'Not recorded';
    const dates = (Array.isArray(recipe.installed) ? recipe.installed : []).map(item => Date.parse(String(item?.buildTime || '').replace(/\s+T/, 'T'))).filter(Number.isFinite);
    if (dates.length) return new Date(Math.max(...dates)).toISOString();
    const published = Date.parse(state?.publishedAt);
    return Number.isFinite(published) ? `${new Date(published).toISOString()} (published; build time not recorded)` : 'Not recorded';
}
function libraryRows(plan, disabled, isPR) {
    const decision = disabled ? 'Workflow disabled' : plan.reason ? 'Build scheduled' : isPR ? 'No rebuild needed (unchanged in PR)' : 'Reuse verified output';
    return Object.entries(plan.wanted?.formulas || {}).map(([name,recipe]) => [name,literal(recipe.VER),literal(recipe.BUILD_ID),lastBuild(plan.published?.formulas?.[name],plan.published),decision]);
}
async function write({core, file, job, config, plans, disabled, isPR}) {
    const table = rows => core.summary.addTable(rows.map(row => row.map(escape)));
    core.summary.addHeading(`Platform build plan — ${escape(config.name || file)}`);
    core.summary.addHeading('Build environment and keys', 3);
    core.summary.addRaw('Declared native build configuration follows; this Linux pre-check does not probe native SDKs or compilers. The profile key covers BUILD_PROFILE_ID, the selected matrix row, environment, runner, container and shell. Publishing steps and workflow text are excluded; each library also has its own recipe/dependency key.\n\n');
    table([['Variant','Toolchain / SDK configuration','Profile key'],...plans.map(plan => [variant(plan.row),environment(config,job,plan.row).map(([key,value])=>`${key}=${value}`).join('; ') || 'Native runner defaults',plan.wanted?.profile || 'Unavailable'])]);
    core.summary.addHeading('Variant decisions',3);
    table([['Variant','Decision'],...plans.map(plan=>[variant(plan.row),disabled ? 'Workflow disabled' : plan.reason || (isPR ? 'Unchanged against PR base; runner skipped' : 'Verified published output unchanged; runner skipped')])]);
    core.summary.addRaw('\nBuild scheduled means work is planned, not completed. All libraries in a scheduled bundle are listed; native caches may reuse their outputs. Dates refer to the last published build record for this channel and variant, using the latest recorded binary build time when available.\n\n');
    if (isPR) core.summary.addRaw('PR selection compares with the PR base commit. Published history is informational and does not determine which PR builds run.\n\n');
    for (const plan of plans) {
        core.summary.addHeading(`Libraries — ${escape(variant(plan.row))}`,3);
        const rows = libraryRows(plan,disabled,isPR);
        if (rows.length) table([['Library','Version','Build ID','Last build (UTC)','Decision'],...rows]);
        else core.summary.addRaw('Library details unavailable; see the conservative rebuild reason above.\n\n');
    }
    await core.summary.write();
}
module.exports={write,environment,lastBuild,libraryRows};
