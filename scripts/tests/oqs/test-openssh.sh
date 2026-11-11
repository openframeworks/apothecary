#!/usr/bin/env bash
# Offline tests of the staged OQS OpenSSH binaries; no agent, daemon or network.
set -euo pipefail
root=${1:?Usage: test-openssh.sh OUTPUT_ROOT TYPE PLATFORM}
type=${2:?TYPE is required}
platform=${3:?PLATFORM is required}
root=$(cd "$root" && pwd -P)
bindir="$root/openssh/bin/$type/$platform"
testdir=$(mktemp -d "${TMPDIR:-/tmp}/oqs-ssh-smoke.XXXXXX")
trap 'rm -rf "$testdir"' EXIT
"$bindir/ssh" -V
"$bindir/ssh" -Q kex > "$testdir/kex"
"$bindir/ssh" -Q key > "$testdir/keys"
grep -q '^mlkem768-sha256$' "$testdir/kex"
grep -q '^ssh-mldsa-44$' "$testdir/keys"
grep -q '^ssh-ecdsa-nistp256-mldsa-44$' "$testdir/keys"
# Query the relocated daemon's effective config without starting a listener.
"$bindir/oqs-sshd" -G -f /dev/null > "$testdir/sshd-config"
grep -Fq "$root/openssh/libexec/$type/$platform/sshd-auth" "$testdir/sshd-config"
grep -Fq "$root/openssh/libexec/$type/$platform/sshd-session" "$testdir/sshd-config"
for algorithm in ssh-mldsa-44 ssh-ecdsa-nistp256-mldsa-44; do
    key="$testdir/$algorithm"
    "$bindir/ssh-keygen" -q -t "$algorithm" -N '' -f "$key"
    printf 'Apothecary OQS signature test\n' > "$testdir/message"
    # Force a fresh signature for each algorithm.
    if [ -f "$testdir/message.sig" ]; then rm "$testdir/message.sig"; fi
    "$bindir/ssh-keygen" -Y sign -n apothecary -f "$key" "$testdir/message"
    printf 'local-test %s\n' "$(cat "$key.pub")" > "$testdir/allowed-signers"
    "$bindir/ssh-keygen" -Y verify -f "$testdir/allowed-signers" -I local-test \
        -n apothecary -s "$testdir/message.sig" < "$testdir/message"
    if printf 'Changed message\n' | "$bindir/ssh-keygen" -Y verify \
        -f "$testdir/allowed-signers" -I local-test -n apothecary \
        -s "$testdir/message.sig" > "$testdir/negative-control.log" 2>&1; then
        echo 'Tampered message unexpectedly verified' >&2
        exit 1
    fi
done
printf 'OpenSSH OQS algorithms, relocated helpers, pure/hybrid ML-DSA signatures and negative controls passed\n'
