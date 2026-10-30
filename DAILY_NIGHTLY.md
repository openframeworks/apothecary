# Daily nightly snapshots

`refresh-nightly.yml` starts at 05:00 UTC on the repository's default branch.
It promotes a rolling `nightly` release only after the frozen candidate libraries
build against a pinned openFrameworks `master` commit.

The workflow first records every source `latest` asset's ID, name, size and
SHA-256, the `latest` tag commit, and the openFrameworks master SHA. Seven
integration jobs check out that exact master commit and install the candidate
archives by asset ID, checking their hashes before extraction. The jobs build
Linux, macOS, iOS, tvOS, Android, Emscripten and Windows consumers using the
reusable `test-openframeworks-libraries.yml` workflow. Linux also runs its smoke
tests. Setup runs before candidate installation so a setup script cannot replace
the candidate with the normal nightly download. Candidate receipts are retained
as artifacts.

These are the existing integration targets: Linux x64 with the GCC10 archive, macOS on the selected
runner, iOS/tvOS through their CI scripts, Android core/Gradle, Emscripten through
its CI script, and Windows x64/VS2022 examples. They do not establish physical
Raspberry Pi, every CPU/toolset combination, or optional renderer runtime support.
The frozen source snapshot includes the whole release; the listed consumer builds
are its required compatibility gate.

If any required build fails, is cancelled or is skipped, promotion fails and the
previous nightly remains available. A changed source asset, source tag or
openFrameworks master tip also prevents normal promotion. Integration and transfer
may extend past openFrameworks' 06:00 UTC nightly schedule; that consumer can use
the previous validated nightly until the next promotion completes.

## Manual action controls

Open **Actions → Refresh daily nightly snapshot → Run workflow**:

- `dry_run` defaults to **true**: inspect the snapshot without integration builds
  or release writes.
- Set `dry_run=false` for normal validation and promotion.
- `override_build_gate` defaults to **false**. Set it to **true** together with
  `dry_run=false` to skip compatibility builds and publish manually. The release
  notes record the override, actor, run URL and master SHA observed at planning.
  This bypasses compatibility checks; source-asset identity and checksum checks
  still apply. Schedules cannot request the override.

## Publication

Only after the build gate passes (or a manual override) are library assets copied
to a hidden staging release. Every download and upload is checked by size and
SHA-256. Archive bytes and embedded build timestamps remain unchanged; filenames
containing `_latest` become `_nightly`, with corresponding checksum/manifest
filename references updated. Build-state records remain excluded.

If `latest` changes during copying, or Apothecary master platform workflows are
publishing, nightly is preserved. After verification, the previous nightly is
retained as a hidden backup until the new release is published, with rollback
if publication fails. The floating tag moves to the copied source SHA and temporary
tags are cleaned up. The title includes the UTC date; notes retain source and
validation provenance. Existing latest/versioned releases are not recreated.

This refreshes one rolling release, rather than retaining a dated release every
day. PR tests mock release writes and exercise the build gate, overrides, snapshot
movement, archive installation and rollback. Native integration and live release
transfer still require Actions verification; no release is changed by those tests.
