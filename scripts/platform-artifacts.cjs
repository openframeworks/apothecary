const fs = require('node:fs');
const path = require('node:path');

function keys(file) {
    const result = new Map();
    for (const line of fs.readFileSync(file, 'utf8').trim().split('\n')) {
        const [name, key] = line.split('\t');
        if (!/^[A-Za-z0-9_-]+$/.test(name) || !/^modular-v1-[A-Za-z0-9_-]+$/.test(key || '') || result.has(name)) {
            throw new Error(`Invalid artifact manifest: ${file}`);
        }
        result.set(name, key);
    }
    return result;
}

exports.select = async ({github, context, core}) => {
    // PRs read only their trusted base branch; never restore PR-produced binaries.
    const branch = context.payload.pull_request?.base.ref || context.ref.replace(/^refs\/heads\//, '');
    if (!['bleeding', 'master'].includes(branch)) {
        core.info('No trusted baseline for this ref; building from source.');
        return;
    }
    const name = `platform-v1-${process.env.TARGET}-${process.env.ARTIFACT_VARIANT}`;
    try {
        // Search successful producers, not arbitrary repository-wide artifact names.
        // A cancelled/failed run may have uploaded a bundle before another job failed.
        for await (const page of github.paginate.iterator(github.rest.actions.listWorkflowRuns, {
            ...context.repo, workflow_id: `build-${process.env.TARGET}.yml`,
            branch, event: 'push', status: 'success', per_page: 30,
        })) {
            for (const run of page.data.workflow_runs) {
                const artifacts = await github.paginate(github.rest.actions.listWorkflowRunArtifacts, {
                    ...context.repo, run_id: run.id, per_page: 100,
                });
                if (artifacts.some(a => a.name === name && !a.expired)) {
                    core.setOutput('run-id', String(run.id));
                    core.setOutput('name', name);
                    core.info(`Baseline: ${name}, successful ${branch} run ${run.id}`);
                    return;
                }
                // All older artifacts are also outside our retention period.
                if (Date.parse(run.created_at) < Date.now() - 30 * 86400000) break;
            }
            if (page.data.workflow_runs.some(r => Date.parse(r.created_at) < Date.now() - 30 * 86400000)) break;
        }
        core.info('No unexpired platform baseline; building from source.');
    } catch (error) {
        core.warning(`Artifact lookup unavailable; building from source: ${error.message}`);
    }
};

exports.restore = ({core}) => {
    const temp = process.env.RUNNER_TEMP;
    const baseline = path.join(temp, 'platform-artifact-output');
    const expected = keys(path.join(temp, 'platform-artifact-keys.tsv'));
    const previous = keys(path.join(baseline, '.platform-artifact-keys.tsv'));
    const out = path.join(process.env.GITHUB_WORKSPACE, 'out');
    fs.mkdirSync(out, {recursive: true});
    let hits = 0;
    for (const [name, key] of expected) {
        const source = path.join(baseline, name);
        if (previous.get(name) === key && fs.existsSync(source) && fs.lstatSync(source).isDirectory()) {
            // Never expose a half-copied pickle if optional restoration fails.
            const staging = path.join(out, `.platform-restore-${name}`);
            try {
                fs.cpSync(source, staging, {recursive: true, verbatimSymlinks: true});
                fs.renameSync(staging, path.join(out, name));
            } catch (error) {
                fs.rmSync(staging, {recursive: true, force: true});
                throw error;
            }
            hits++;
            core.info(`Restored ${name}: matching formula, dependencies and toolchain.`);
        } else {
            core.info(`Build ${name}: absent or changed inputs.`);
        }
    }
    core.summary.addRaw(`Platform baseline: restored ${hits}/${expected.size} formula outputs. Version/build metadata is checked again by the engine.\n`).write();
};
exports.keys = keys;
