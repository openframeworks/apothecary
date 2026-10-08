const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {execFileSync} = require('node:child_process');
const helper = require('../platform-artifacts.cjs');

async function test() {
    const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'platform-artifacts-test-'));
    try {
        process.env.TARGET = 'catos';
        process.env.ARTIFACT_VARIANT = '2';
        process.env.RUNNER_TEMP = temp;
        process.env.GITHUB_WORKSPACE = path.join(temp, 'workspace');
        const outputs = {};
        const core = {
            info() {}, warning() {}, setOutput(k, v) { outputs[k] = v; },
            summary: {addRaw() { return this; }, write() { return Promise.resolve(); }},
        };
        const context = {repo: {owner: 'openframeworks', repo: 'apothecary'}, ref: 'refs/pull/123/merge',
            payload: {pull_request: {base: {ref: 'master'}}}};
        let queried = 0;
        const github = {
            rest: {actions: {listWorkflowRuns: 'runs', listWorkflowRunArtifacts: 'artifacts'}},
            paginate: Object.assign(async (endpoint, args) => {
                assert.equal(endpoint, 'artifacts');
                if (args.run_id === 1) return [{name: 'platform-v1-catos-2-extra', expired: false}];
                if (args.run_id === 2) return [{name: 'platform-v1-catos-2', expired: true}];
                return [{name: 'platform-v1-catos-2', expired: false}];
            }, {iterator: async function* (endpoint, args) {
                queried++;
                assert.equal(endpoint, 'runs');
                assert.equal(args.branch, 'master');
                assert.equal(args.event, 'push');
                assert.equal(args.status, 'success');
                assert.equal(args.workflow_id, 'build-catos.yml');
                assert.equal(args.owner, 'openframeworks');
                yield {data: {workflow_runs: [{id: 1}, {id: 2}]}};
                yield {data: {workflow_runs: [{id: 3}]}};
            }}),
        };
        await helper.select({github, context, core});
        assert.deepEqual(outputs, {'run-id': '3', name: 'platform-v1-catos-2'});
        delete context.payload.pull_request;
        context.ref = 'refs/tags/1.0';
        await helper.select({github, context, core});
        assert.equal(queried, 1, 'tag releases cannot restore branch artifacts');
        context.ref = 'refs/heads/feature';
        await helper.select({github, context, core});
        assert.equal(queried, 1, 'feature pushes cannot supply a trusted baseline');
        context.ref = 'refs/heads/bleeding';
        github.paginate.iterator = async function* () { throw new Error('API unavailable'); };
        await helper.select({github, context, core}); // Optional lookup failure is a source build.

        const source = path.join(temp, 'source');
        fs.mkdirSync(path.join(source, 'unchanged'), {recursive: true});
        fs.mkdirSync(path.join(source, 'changed'));
        fs.writeFileSync(path.join(source, 'unchanged', 'library.a'), 'compiled');
        fs.writeFileSync(path.join(source, 'unchanged', 'tool'), 'executable', {mode: 0o755});
        fs.symlinkSync('library.a', path.join(source, 'unchanged', 'alias.a'));
        fs.writeFileSync(path.join(source, 'changed', 'library.a'), 'stale');
        fs.writeFileSync(path.join(source, '.platform-artifact-keys.tsv'),
            'unchanged\tmodular-v1-catos-same\nchanged\tmodular-v1-catos-old\n');
        fs.writeFileSync(path.join(temp, 'platform-artifact-keys.tsv'),
            'unchanged\tmodular-v1-catos-same\nchanged\tmodular-v1-catos-new\nabsent\tmodular-v1-catos-new\n');
        // Exercise the same tar round trip as CI, including symlinks/mode bits.
        execFileSync('tar', ['-czf', path.join(temp, 'platform-binaries.tar.gz'), '-C', source, '.']);
        fs.mkdirSync(path.join(temp, 'platform-artifact-output'));
        execFileSync('tar', ['-xzf', path.join(temp, 'platform-binaries.tar.gz'), '-C', path.join(temp, 'platform-artifact-output')]);
        helper.restore({core});
        const out = path.join(process.env.GITHUB_WORKSPACE, 'out');
        assert.equal(fs.readFileSync(path.join(out, 'unchanged', 'library.a'), 'utf8'), 'compiled');
        assert.equal(fs.readlinkSync(path.join(out, 'unchanged', 'alias.a')), 'library.a');
        assert.equal(fs.statSync(path.join(out, 'unchanged', 'tool')).mode & 0o777, 0o755);
        assert.equal(fs.existsSync(path.join(out, 'changed')), false);
        assert.equal(fs.existsSync(path.join(out, 'absent')), false);
        fs.writeFileSync(path.join(temp, 'bad.tsv'), '../escape\tmodular-v1-catos-same\n');
        assert.throws(() => helper.keys(path.join(temp, 'bad.tsv')), /Invalid artifact manifest/);
        console.log('Platform artifact lookup, invalidation and archive round trip passed');
    } finally {
        fs.rmSync(temp, {recursive: true, force: true});
    }
}
test().catch(error => { console.error(error); process.exitCode = 1; });
