# Linux modular libudev

Pinned source: 3.2.15 from https://github.com/eudev-project/eudev/releases/download/v3.2.15/eudev-3.2.15.tar.gz.

Build with `TYPE=linux ARCH=64 ./apo update libudev` (or `ARCH=arm64`).
The dedicated workflow builds both native architectures, packages the installed
headers, shared libraries, native pkg-config metadata and runtime data, and
publishes `oF_libudev_linux_<arch>_gcc14.tar.bz2` to `latest-modular` on upstream
branch pushes. PRs upload review artifacts and do not publish releases.

Set `PKG_CONFIG_PATH` to the package's `lib/linux/<arch>/pkgconfig` and
`LD_LIBRARY_PATH` to its `lib/linux/<arch>` when consuming the download.
This package retains the `libudev` interface. External dependencies remain
visible through its native `.pc` metadata and must be provided by matching
modular packages or the host distribution. It does not replace host services,
kernel interfaces, display servers or GPU drivers.

Linux x86_64/ARM64 GCC14 builds are validated by the dedicated workflow.
Raspberry Pi ARMv6/ARMv7 packages are outside this initial matrix.

This builds eudev's ABI-compatible libudev client library only. The host
udev service and its runtime device database remain required.
