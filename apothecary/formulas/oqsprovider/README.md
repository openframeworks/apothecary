# Open Quantum Safe formulas

These opt-in formulas build the Open Quantum Safe projects separately from
Apothecary's core packages:

| Formula | Source pin | Outputs |
| --- | --- | --- |
| `liboqs` | 0.16.0 | Static algorithm library, headers, CMake/pkg-config files and notices. |
| `openssh` | OQS-v10 commit `eed58298755950fb201039d00bcb37b7af1447a9` | OQS OpenSSH 10.4 tools, daemon, helpers, manuals and a relocated daemon launcher. |
| `oqsprovider` | 0.12.0 | Loadable `ossl-modules/oqsprovider.dylib` on macOS (`.so` on Linux), plus `liboqsprovider.a` and a CMake consumer config. |

The OpenSSH source is a full-commit archive pin rather than the older named
snapshot. Every archive is verified by SHA-256 before extraction.

```sh
NO_COLOR=1 UI_ANIM=0 TYPE=osx ARCH=arm64 ./apo update oqsprovider openssh
```

`oqsprovider` depends on the existing `openssl` formula and `liboqs`;
`openssh` additionally declares `zlib`. A guarded liboqs patch namespaces three
internal SNTRUP761 optimization-blocker symbols so the library can link alongside
OpenSSH's bundled SNTRUP761 code; it preserves both implementations and algorithms.

`liboqs` uses its bundled symmetric implementations (`OQS_USE_OPENSSL=OFF`) and
runtime CPU dispatch (`OQS_DIST_BUILD=ON`), with the upstream default algorithm
selection. Libjade, CUDA and ICICLE backends are disabled, avoiding their extra
downloads/toolchains. The initial OpenSSH recipe disables PAM, SELinux, Kerberos,
libedit and the built-in FIDO security-key backend. Transport zlib compression
stays enabled.

Neither new consumer replaces Apothecary OpenSSL. The provider and tools are
built against its staged headers and static libraries. Module consumers must use
the matching OpenSSL build; system/Homebrew CLI loading is not the validation
path. OpenSSL >= 3.5 supplies several standardized PQ algorithms itself, and
upstream oqsprovider suppresses overlapping implementations. Tests deliberately
use provider-specific FrodoKEM/Falcon as well as direct liboqs ML-KEM/ML-DSA.

## Layout and use

- SSH tools: `out/openssh/bin/<type>/<platform>/`.
- SSH helpers: `out/openssh/libexec/<type>/<platform>/`.
- Provider module: `out/oqsprovider/lib/<type>/<platform>/ossl-modules/`.
- Static libraries: `out/<formula>/lib/<type>/<platform>/`.

Load the module with `OSSL_PROVIDER_set_default_search_path` followed by
`OSSL_PROVIDER_load(ctx, "oqsprovider")`, using an application linked to the
matching Apothecary OpenSSL. To embed it statically, link
`apothecary::oqsprovider` from the staged `oqsproviderConfig.cmake`, declare
`extern OSSL_provider_init_fn oqs_provider_init`, and register it through
`OSSL_PROVIDER_add_builtin` before loading it. Supply the staged OpenSSL and
liboqs locations to CMake; the config checks the exact OpenSSL version used at
build time. See `scripts/tests/oqs/CMakeLists.txt` for a complete consumer.

OpenSSH installs through `DESTDIR` and `install-nosysconf`. It does not create
host keys, install configuration or register/start a service. The packaged
`ssh-keysign` helper has ordinary executable permissions, not setuid permissions;
privileged host-based authentication is not provisioned by this formula. The
optional `oqs-sshd` launcher supplies relocated `SshdAuthPath` and `SshdSessionPath`
values; callers must supply their own server configuration and host keys. Use
the staged `sftp-server` path explicitly for an SFTP subsystem. Client tools
retain the usual `/etc/ssh` configuration defaults; offline tests pass explicit
configuration paths. These are tool packages, not linkable OpenSSH SDK libraries.

Two small guarded source patches fix declarations in the pinned OpenSSH tree:
`SSHKEY_INTERNAL` must precede `oqs-utils.h`'s inclusion of `sshkey.h`, and
`kex_reset_keys` needs a declaration in `kex.h`. A macOS-only backport of
[OpenSSH commit d4b4c304](https://github.com/openssh/openssh-portable/commit/d4b4c304a202f5099f2f60be9af9ba266212bb74)
checks for `kSBXProfilePureComputation` before selecting the Darwin sandbox.
SDK 27 removed that profile. On the native SDK 27.2 build, upstream's
`poll`/`RLIMIT_NOFILE` probe also fails, so auto-selection reports sandbox style
`none`. This experimental build therefore has no privsep syscall sandbox;
privilege separation remains enabled. Older SDKs retain Darwin sandboxing when
the profile is available. No configure result is overridden to hide this limit.
The provider's source commit is injected explicitly so an archive build cannot
report the enclosing Apothecary repository's commit as its own.

## Validation

```sh
cmake -S scripts/tests/oqs -B /tmp/oqs-smoke \
  -DDEPS_ROOT="$PWD/out" -DTYPE=osx -DPLATFORM=MAC_ARM64
cmake --build /tmp/oqs-smoke --parallel 4
ctest --test-dir /tmp/oqs-smoke --no-tests=error --output-on-failure
bash scripts/tests/oqs/test-openssh.sh out osx MAC_ARM64
bash scripts/tests/oqs/test-packaged.sh out osx MAC_ARM64
```

The native tests cover liboqs ML-KEM-768, SNTRUP761 and ML-DSA-44; provider
loading and built-in registration; FrodoKEM encapsulation/decapsulation; Falcon
signing/verification; OpenSSL random generation, TLS context creation and
certificate verification; and tampered ciphertext/signature and untrusted
certificate controls. SSH tests check algorithm enumeration, relocated daemon
helper configuration, and pure and hybrid ML-DSA detached signatures with a
tampered-message control. They start no listener and do not establish an SSH
session. The packaging test creates native tar archives, extracts them into a
new path containing spaces, and repeats the consumer checks.

These checks passed on macOS ARM64 with SDK 27.2 and Apothecary OpenSSL 4.1.0
on 2026-11-08. Linux recipes are provided for native desktop builds;
Windows/mobile support, release automation, XCFramework staging, complete
upstream test suites and SSH interoperability are not part of this pass.
These formulas are not in core or automatic publish lists and do not use
remote binary reuse yet. The upstream OQS OpenSSH fork is a prototype for
evaluation; these build checks are not a cryptographic audit.
