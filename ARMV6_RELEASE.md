# ARMv6 release publication

After this PR is merged, run **build-linux-rpi** from `bleeding`, `master` or a
release tag. Select `arch=armv6l` and enable **Publish ARMv6 libraries to release**
(`publish_armv6l=true`). Only ARMv6 is rebuilt for that request.

The workflow verifies the archive checksum and manifest, uploads a review
artifact, and publishes the core `.tar.bz2`, `.sha256` and `.manifest.json` to
`latest` from `bleeding`, `nightly` from `master`, or the selected version tag.
Individual ARMv6 library packages are published to `latest-modular`. PR and
ordinary manual diagnostic runs do not publish release assets. Manual release
publication does not record a release-planner baseline as successful.

The optional `pi_zero_test=true` input runs ARM1176 and Cortex-A7 diagnostics,
including Brotli/zlib roundtrips linked from the extracted archive. When selected,
failed runtime tests fail the job before publication. The packaged zlib filename
is `zlib.a`.

Cross-compiling ARMv6 libraries does not establish original Pi Zero compatibility.
The previous ARM1176 run exposed illegal instructions in the Debian bookworm
armhf system runtime. This PR adds a publication path; it does not replace that
sysroot or claim to fix the runtime incompatibility. Enable the diagnostic when
testing Pi Zero support, and validate on physical hardware before claiming support.
