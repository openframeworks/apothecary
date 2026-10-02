# Upstream version checker

The scheduled workflow runs Monday at 08:00 UTC and can also be started with
`workflow_dispatch`. It checks `bleeding` and maintains one issue marked
`<!-- apothecary-upstream-versions -->`. GitHub scheduled workflows must be
present on the repository's default branch to run; merge/cherry-pick the workflow
there too if the default branch differs from `bleeding`.

Requires Bash 3.2 or newer, curl, git, and jq 1.6 or newer (available on the
Ubuntu Actions runner). No Python dependency.

Run a report without writing to GitHub:

```bash
GH_TOKEN="$(gh auth token)" bash scripts/check-upstream-versions.sh
bash scripts/check-upstream-versions.sh --only OpenSSL FreeImage
```

Only `--file-issue --repository owner/repo` writes to GitHub. It creates or
updates the marked issue when there are newer releases or failed checks,
and closes it only after a successful check finds no newer versions. An
unchanged report is not rewritten. Every run also writes the report to the
Actions job summary. Failed checks fail the job and remain visible in the issue.
The workflow grants issue write permission only to scheduled/manual checks;
PRs run offline tests with read permission.

`scripts/upstream-versions.json` lists the formula path, version variable,
official upstream repository and full stable-tag pattern. The Bash checker uses
`upstream-versions.jq` for JSON parsing and numeric version comparisons. Versions
are read as literal assignments; formula scripts are never sourced or executed. GitHub and
freedesktop GitLab release APIs are supported; Mesa uses its official archive
directory listing. Cairo and GStreamer development series are excluded using
their even/odd version conventions. Numeric version components are
compared, excluding draft/prerelease releases and nonmatching tags. When no
matching published releases exist, the checker falls back to version tags.
Every API page is considered, with a limit of 100 pages per endpoint; exceeding
that limit reports a failure instead of silently returning an incomplete result.

Add a registry entry or an explicit exclusion whenever adding a formula. Missing,
stale or duplicate registry entries fail validation. Commit/date pins and legacy
SDKs are excluded with reasons, rather than compared to unrelated numeric tags.
PortAudio's historical `stable_v19_20110326` pin is compared as version 19.0.0.

The report shows the newest stable release, including newer major branches. It
does not decide which branch Apothecary should support, download archives,
change checksums or automatically upgrade formulas. Check ABI/platform support,
patches and verified source hashes when preparing an update PR.

Run regression tests with:

```bash
bash scripts/tests/test-upstream-versions.sh
```
