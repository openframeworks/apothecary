# Published SHA-256 checksums

Library archives remain on `latest` and `latest-modular`. Their downloadable
checksums live on the separate `sha256` release:

| Libraries | Checksum file |
| --- | --- |
| `latest` | `https://github.com/openframeworks/apothecary/releases/download/sha256/latest.SHA256SUMS` |
| `latest-modular` | `https://github.com/openframeworks/apothecary/releases/download/sha256/latest-modular.SHA256SUMS` |

Each file uses the standard `SHA256SUMS` format: a hexadecimal SHA-256, two spaces,
then the archive basename. It covers every published core/modular archive on that
channel, across all platforms. For example, after downloading one core archive:

```sh
curl -fL --retry 3 -o latest.SHA256SUMS \
  https://github.com/openframeworks/apothecary/releases/download/sha256/latest.SHA256SUMS
sha256sum --check --ignore-missing latest.SHA256SUMS
```

These are public download URLs. Other systems can fetch them without GitHub API
authentication. A consumer that formerly fetched `ARCHIVE_URL.sha256` must use
the appropriate checksum list instead. Existing old checksum URLs are retired
only after the destination files are uploaded and verified.

Current openFrameworks `scripts/dev/download_libs.sh` reads GitHub's release-asset
digests through `scripts/dev/sha_verify.sh`, rather than these remote sidecars.
Its existing archive downloads and API verification keep working. Reading these
lists as another source/fallback would require a downloader change.

The publisher runs after library workflows complete, every six hours, and on
manual dispatch. It uses GitHub's server-calculated asset SHA-256 where available.
For older assets without that field, it streams the published archive, verifies
its size and hashes its bytes. Per-channel `.sha256.json` indexes on `sha256`
cache these hashes against exact asset IDs, names, sizes and update timestamps.
An archive changing during synchronization stops cleanup and requires a retry.
There can be a short delay between an archive upload and checksum synchronization;
a downloader must reject a mismatch and retry after synchronization.

The manual action has a read-only `dry_run` option. The first successful publish
migrates existing `.sha256` sidecars from the two channels after checking they
agree with the archive hashes. Archives are never deleted, replaced or renamed.
CI `.pkl` records remain on `build-state`; Linux `.manifest.json` package
descriptors are separate metadata and are outside this checksum migration.
Nightly and immutable versioned releases retain their existing checksum layout.

The `sha256` tag is excluded from native library build triggers. No compiler
profile or formula build number changes are needed for this publishing change.
