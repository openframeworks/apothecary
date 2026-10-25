#!/usr/bin/env python3
"""Check that the Windows modular ZIP preserves the complete staged Poco tree."""
import hashlib
import sys
import zipfile
from pathlib import Path


def digest(stream):
    value = hashlib.sha256()
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        value.update(chunk)
    return value.digest()


def check(archive, staged):
    with zipfile.ZipFile(archive) as package:
        members = [entry for entry in package.infolist() if not entry.is_dir()]
        names = [entry.filename for entry in members]
        if len(names) != len(set(names)):
            raise ValueError("Duplicate ZIP members")
        expected = {"poco/" + path.relative_to(staged).as_posix(): path
                    for path in staged.rglob("*") if path.is_file()}
        if set(names) != set(expected):
            raise ValueError("ZIP contents differ from the staged Poco tree")
        for entry in members:
            with package.open(entry) as packed, expected[entry.filename].open("rb") as source:
                if digest(packed) != digest(source):
                    raise ValueError("Packaged bytes differ: " + entry.filename)
        for header in ("Foundation.h", "JSON/Parser.h", "Net/HTTPClientSession.h",
                       "Crypto/Cipher.h", "Net/HTTPSClientSession.h"):
            if "poco/include/Poco/" + header not in expected:
                raise ValueError("Missing public header: " + header)
        if "poco/license/LICENSE" not in expected:
            raise ValueError("Missing Poco license")
        platforms = {name.split("/")[3] for name in names if name.startswith("poco/lib/vs/")}
        if len(platforms) != 1 or not platforms <= {"x64", "ARM64", "ARM64EC"}:
            raise ValueError("Expected exactly one supported VS architecture")
        platform = platforms.pop()
        for config in ("Release", "Debug"):
            prefix = "poco/lib/vs/{}/{}/".format(platform, config)
            suffixes = ("", "md", "mt") if config == "Release" else ("d", "mdd", "mtd")
            for component in ("Foundation", "JSON", "Net", "Crypto", "NetSSL", "Util", "XML", "Zip"):
                candidates = {prefix + "Poco" + component + suffix + ".lib" for suffix in suffixes}
                matching = [entry for entry in members if entry.filename in candidates and entry.file_size > 0]
                if len(matching) != 1:
                    raise ValueError("Missing or ambiguous {} {} library".format(config, component))
        print("Poco {}: headers, license, Debug/Release libraries and all {} files verified byte-for-byte".format(platform, len(names)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: check-poco-windows-package.py ARCHIVE STAGED_POCO_DIR")
    check(Path(sys.argv[1]), Path(sys.argv[2]))
