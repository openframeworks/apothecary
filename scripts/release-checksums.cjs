// Keep downloadable checksums separate from library archives and build records.
const crypto = require('node:crypto');
const channels = ['latest', 'latest-modular'];
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const validHash = value => /^[a-f0-9]{64}$/.test(value || '');
const archiveName = name => /^(?:openFrameworksLibs_|oF_)[A-Za-z0-9_.+-]*\.(?:zip|tar\.bz2|tar\.gz|tar\.xz|tgz|7z)$/.test(name);

async function release(github, repo, tag) {
    try { return (await github.rest.repos.getReleaseByTag({...repo, tag})).data; }
    catch (error) { if (error.status === 404) return null; throw error; }
}
async function assets(github, repo, item) {
    return github.paginate(github.rest.repos.listReleaseAssets, {...repo, release_id:item.id, per_page:100});
}
async function readAsset(github, repo, asset) {
    if (asset.size > 4 * 1024 * 1024) throw Error(`Oversized checksum metadata: ${asset.name}`);
    const response = await github.rest.repos.getReleaseAsset({...repo, asset_id:asset.id, headers:{accept:'application/octet-stream'}});
    const data = Buffer.from(response.data);
    if (data.length !== asset.size) throw Error(`Metadata size differs: ${asset.name}`);
    if (asset.digest && asset.digest !== `sha256:${sha(data)}`) throw Error(`Metadata digest differs: ${asset.name}`);
    return data;
}
function archives(items) {
    return items.filter(asset => archiveName(asset.name)).sort((a,b) => a.name.localeCompare(b.name)).map(asset => {
        if (asset.state !== 'uploaded' || !Number.isSafeInteger(asset.id) || !Number.isSafeInteger(asset.size) || asset.size <= 0) {
            throw Error(`Incomplete library asset: ${asset.name}`);
        }
        if (asset.digest != null && !/^sha256:[a-f0-9]{64}$/.test(asset.digest)) throw Error(`Invalid published digest: ${asset.name}`);
        return asset;
    });
}
function identity(asset) {
    return {id:asset.id, name:asset.name, size:asset.size, updatedAt:asset.updated_at || null, digest:asset.digest || null};
}
function snapshot(items) { return JSON.stringify(archives(items).map(identity)); }

async function hashAsset(asset, tag, repo) {
    // Only legacy releases lack GitHub's server-computed digest. Stream their
    // published bytes once, then cache the result against immutable asset IDs.
    const url = `https://github.com/${repo.owner}/${repo.repo}/releases/download/${encodeURIComponent(tag)}/${encodeURIComponent(asset.name)}`;
    const response = await fetch(url, {signal:AbortSignal.timeout(20 * 60 * 1000)});
    if (!response.ok || !response.body) throw Error(`Cannot hash ${asset.name}: HTTP ${response.status}`);
    const hash = crypto.createHash('sha256');
    let size = 0;
    for await (const chunk of response.body) { hash.update(chunk); size += chunk.length; }
    if (size !== asset.size) throw Error(`Published size changed while hashing ${asset.name}`);
    return hash.digest('hex');
}

async function destination(github, repo, context) {
    const found = await release(github, repo, 'sha256');
    if (found) return found;
    try {
        return (await github.rest.repos.createRelease({...repo, tag_name:'sha256', target_commitish:context.sha,
            name:'SHA-256 checksums', prerelease:true, make_latest:'false',
            body:'Checksums for the published latest and latest-modular library archives. Download latest.SHA256SUMS or latest-modular.SHA256SUMS. Build records remain under build-state. Library archive URLs are unchanged.'})).data;
    } catch (error) {
        if (error.status !== 422) throw error;
        const raced = await release(github, repo, 'sha256');
        if (!raced) throw error;
        return raced;
    }
}

async function publishFile(github, repo, target, current, name, data, runId) {
    const old = current.find(asset => asset.name === name);
    if (old && (await readAsset(github, repo, old)).equals(data)) return;
    // Verify the replacement before removing the old checksum file. Source
    // sidecars are removed only after the final named files are verified too.
    const temporary = `${name}.pending-${runId}`;
    const stale = current.find(asset => asset.name === temporary);
    if (stale) await github.rest.repos.deleteReleaseAsset({...repo, asset_id:stale.id});
    const uploaded = (await github.rest.repos.uploadReleaseAsset({...repo, release_id:target.id,
        name:temporary, data, headers:{'content-type':'text/plain', 'content-length':data.length}})).data;
    if (!(await readAsset(github, repo, uploaded)).equals(data)) throw Error(`Checksum upload differs: ${name}`);
    if (old) await github.rest.repos.deleteReleaseAsset({...repo, asset_id:old.id});
    const renamed = (await github.rest.repos.updateReleaseAsset({...repo, asset_id:uploaded.id, name})).data;
    if (!(await readAsset(github, repo, renamed)).equals(data)) throw Error(`Final checksum differs: ${name}`);
}

async function sync({github, context, core, dryRun = false, digestAsset = hashAsset}) {
    const repo = context.repo;
    let target = await release(github, repo, 'sha256');
    let targetAssets = target ? await assets(github, repo, target) : [];
    const results = [];
    for (const tag of channels) {
        const source = await release(github, repo, tag);
        if (!source) { core.warning(`No ${tag} release; skipped`); continue; }
        const sourceAssets = await assets(github, repo, source);
        const libraries = archives(sourceAssets);
        if (!libraries.length) throw Error(`No published libraries in ${tag}; refusing an empty checksum list`);
        const indexName = `${tag}.sha256.json`, sumsName = `${tag}.SHA256SUMS`;
        const previousIndex = targetAssets.find(asset => asset.name === indexName);
        let cached = [];
        if (previousIndex) {
            const previous = JSON.parse((await readAsset(github, repo, previousIndex)).toString('utf8'));
            if (previous.schema === 1 && previous.releaseId === source.id && Array.isArray(previous.assets)) cached = previous.assets;
        }
        const records = [];
        for (const asset of libraries) {
            const key = identity(asset);
            const previous = cached.find(item => JSON.stringify(item.source) === JSON.stringify(key) && validHash(item.sha256));
            let digest = asset.digest ? asset.digest.slice(7) : previous?.sha256;
            if (!digest) {
                core.info(`Hash legacy archive: ${tag}/${asset.name} (${asset.size} bytes)`);
                digest = await digestAsset(asset, tag, repo);
            }
            if (!validHash(digest)) throw Error(`No SHA-256 for ${asset.name}`);
            records.push({source:key, sha256:digest});
        }
        const sums = Buffer.from(records.map(item => `${item.sha256}  ${item.source.name}\n`).join(''));
        const index = Buffer.from(JSON.stringify({schema:1, channel:tag, releaseId:source.id, assets:records}, null, 2) + '\n');
        const sidecars = sourceAssets.filter(asset => asset.name.endsWith('.sha256') && archiveName(asset.name.slice(0,-7)));
        // Check the old sidecars before removing them; a disagreement is a
        // publication error, never a reason to discard integrity metadata.
        for (const asset of sidecars) {
            const name = asset.name.slice(0,-7), record = records.find(item => item.source.name === name);
            if (!record) throw Error(`Orphan checksum: ${asset.name}`);
            const text = (await readAsset(github, repo, asset)).toString('utf8');
            if (text.trim() !== `${record.sha256}  ${name}`) throw Error(`Existing checksum differs: ${asset.name}`);
        }
        if (snapshot(await assets(github, repo, source)) !== snapshot(sourceAssets)) throw Error(`${tag} moved while checksums were calculated; retry`);
        core.info(`${dryRun ? 'Preview' : 'Publish'} ${sumsName}: ${records.length} archives; relocate ${sidecars.length} sidecars`);
        if (!dryRun) {
            target ||= await destination(github, repo, context);
            await publishFile(github, repo, target, targetAssets, sumsName, sums, context.runId);
            await publishFile(github, repo, target, targetAssets, indexName, index, context.runId);
            if (snapshot(await assets(github, repo, source)) !== snapshot(sourceAssets)) throw Error(`${tag} moved during publication; source sidecars retained`);
            for (const asset of sidecars) await github.rest.repos.deleteReleaseAsset({...repo, asset_id:asset.id});
            targetAssets = await assets(github, repo, target);
        }
        results.push({tag, archives:records.length, sidecars:sidecars.length, sums:sums.toString('utf8')});
    }
    return results;
}
module.exports = {sync, archiveName, snapshot, hashAsset};
