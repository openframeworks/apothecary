#!/usr/bin/env python3
"""Verify compiler provenance and binary identities in a VS2019 core ZIP."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import zipfile


def verify(archive, bundle, commit):
    records = []
    with zipfile.ZipFile(archive) as package:
        names = package.namelist()
        if len(names) != len(set(names)):
            raise ValueError("Duplicate ZIP entries")
        for name in names:
            path = PurePosixPath(name)
            if path.suffix != ".pkl" or "/lib/vs/x64/" not in "/" + name:
                continue
            text = package.read(name).decode("utf-8")
            # Parse data fields only; never evaluate downloaded Pkl code.
            fields = {}
            for line in text.splitlines():
                match = re.fullmatch(r'(\w+) = ("(?:\\.|[^"\\])*")', line)
                if match:
                    fields[match[1]] = json.loads(match[2])
            if fields.get("cppStandard") != "17":
                raise ValueError(f"{name}: expected cppStandard=17")
            if not re.search(r"\bVersion 19\.29\.", fields.get("compilerVersion", "")):
                raise ValueError(f"{name}: missing MSVC 19.29 compiler provenance")
            if fields.get("buildCommit") != commit:
                raise ValueError(f"{name}: does not belong to this build commit")
            binary = fields.get("binary", "")
            if not binary or PurePosixPath(binary).name != binary or "\\" in binary:
                raise ValueError(f"{name}: invalid binary filename")
            binary_path = str(path.parent / binary)
            digest = hashlib.sha256(package.read(binary_path)).hexdigest()
            if fields.get("binarySha") != digest:
                raise ValueError(f"{name}: packaged binary SHA-256 mismatch")
            records.append({"metadata": name, **fields})
    required = "zlib" if str(bundle) == "1" else "fmt"
    if not any(record["metadata"].split("/")[0] == required for record in records):
        raise ValueError(f"Bundle {bundle}: missing {required} provenance")
    return {"schema": 1, "toolset": "v142", "cppStandard": "17",
            "buildCommit": commit, "bundle": int(bundle), "binaries": records}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--bundle", choices=["1", "2"], required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    try:
        result = verify(args.archive, args.bundle, args.commit)
    except (ValueError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(1, f"VS2019 package verification failed: {error}\n")
    if args.manifest:
        args.manifest.write_text(json.dumps(result, indent=2) + "\n")
    print(f"Verified {len(result['binaries'])} v142/C++17 binary records in {args.archive}")
