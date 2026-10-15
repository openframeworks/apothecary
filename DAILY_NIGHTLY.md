# Daily nightly snapshots

`refresh-nightly.yml` runs on the default branch at 05:00 UTC daily, one hour before openFrameworks nightly.yml (06:00 UTC), with manual
workflow dispatch available. Manual dispatch defaults to a read-only dry run.
Set dry_run=false to publish. The schedule publishes automatically after merge.

This copies latest; it does not compile libraries. The release title includes
the UTC date and the body identifies the source release, source tag commit and
latest asset update. Existing archive contents and embedded build times remain
unchanged. Names containing _latest are renamed to _nightly for downloaders;
checksum and archive-manifest filename references are adjusted accordingly.
Build-state JSON files are excluded (they belong to the build-state release).

The workflow currently copies about 4.4 GiB across 61 source assets. It downloads
one asset at a time, verifies its original digest, and uploads to a hidden staging
release. Transient downloads retry up to three times. Uploaded digests are checked.
If latest changes during the copy, staging is discarded and nightly is preserved.
Active master platform publication also prevents a conflicting replacement.

Only after verification does it move the previous nightly release into a hidden
backup and publish the staged release under nightly. The previous release is
retained until that succeeds, with rollback if publication is rejected. The
floating nightly tag is updated to the source SHA, and temporary tags are cleaned
up after success. Existing latest/versioned releases are not recreated.

This recreates the rolling nightly release with a fresh publication date; it does
not retain a dated release every day. GitHub upload/delete/tag permissions and
network transfer still need verification in a real publication. No live release
is changed by PR tests. Use the manual dry run before the first live refresh.

GitHub schedules can be delayed; this establishes a one-hour scheduled lead,
not a cross-repository completion dependency.
