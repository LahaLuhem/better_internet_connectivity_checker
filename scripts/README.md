<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Usage](#usage)
- [What's pipeline-owned vs. hand-editable](#whats-pipeline-owned-vs-hand-editable)
- [Tag format](#tag-format)
- [Preflight](#preflight)
- [FVM note](#fvm-note)

<!-- TOC end -->

Audience: maintainers and contributors who want to understand or invoke the release
flow. End users of the package don't need anything in this directory.

Cuts a versioned release of `better_internet_connectivity_checker`. Bumps the
`version:` field in `pubspec.yaml` via `cider`, finalises the `## Unreleased` block
in `CHANGELOG.md` into a dated section, commits both files, creates a SemVer tag,
and pushes commit + tag atomically. The tag push triggers
[`../.github/workflows/publish.yml`](../.github/workflows/publish.yml), which then
publishes to pub.dev via OIDC.

Laptop-only — does not run inside CI.

## Usage

```bash
scripts/release.sh                # fully interactive
scripts/release.sh patch          # bump type set, confirm on TTY
scripts/release.sh patch --yes    # non-interactive (CI-style)
scripts/release.sh --dry-run      # full preflight + plan, no side effects
```

`BUMP` is one of `major`, `minor`, `patch`. The script prompts on a TTY if omitted.

## What's pipeline-owned vs. hand-editable

`CHANGELOG.md` and the `version:` field in `pubspec.yaml` are **pipeline-owned**: the
script reorders or overwrites manual edits to them. Hand-edits will not survive the
next release.

The `## Unreleased` block in `CHANGELOG.md` is the script's **input** — curated by
hand between releases. The script bails if it's empty.

The `cider:` block in `pubspec.yaml` is static configuration (link templates, URLs)
and sits outside the pipeline-owned set — hand-editable.

## Tag format

`<MAJOR>.<MINOR>.<PATCH>` — no `v` prefix. Matches the trigger pattern in
[`../.github/workflows/publish.yml`](../.github/workflows/publish.yml)
(`[0-9]+.[0-9]+.[0-9]+`) and pub.dev's canonical `{{version}}` convention.

## Preflight

The script refuses to proceed unless every check passes:

- `dart` resolvable (prefers `.fvm/flutter_sdk/bin/dart` if present, else PATH).
- `cider` on PATH.
- `shellcheck` on PATH.
- Working tree clean, on `main`, in sync with `origin/main` (fetches first).
- `CHANGELOG.md` has a non-empty `## Unreleased` (or `## [Unreleased]`) section.
- `dart format`, `dart analyze`, and `dart test` all clean.
- The target tag does not already exist locally or on the remote.

`dart pub publish --dry-run` is *not* in preflight. It cross-checks three things
that must be satisfied simultaneously:

1. `pubspec.yaml`'s `version:` matches a CHANGELOG header.
2. No checked-in files are modified in the working tree.
3. The tarball builds and validates against pub.dev rules.

(1) only holds *after* `cider bump` + `cider release`. (2) only holds *after*
`git commit` — running the dry-run against the working tree mid-execute would
trip on the bump/release modifications. So the dry-run runs as step 5, after
the prep commit lands. The `ERR` trap handles failure in two phases:

- **Pre-commit failure** (bump or release errored, no commit yet): restore
  `pubspec.yaml` + `CHANGELOG.md` from `HEAD`.
- **Post-commit, pre-tag failure** (dry-run rejected the prep commit):
  `git reset --hard HEAD~1` to drop the prep commit, leaving the working
  tree exactly as it was before `release.sh` started. No remote tag is ever
  created in this case — the validation gate sits between commit and tag, so
  there's nothing to clean up on `origin`.

After the dry-run passes, the trap clears — `git tag` / `git push` failures
require manual recovery (the script prints the recipe).

## FVM note

If `.fvm/flutter_sdk/bin/dart` exists, the script prepends it to `PATH` so plain
`dart` resolves to the `.fvmrc`-pinned SDK. Otherwise, it falls back to whatever
`dart` is on `PATH` — a non-FVM contributor can run the script unchanged.
SDK-version compatibility is enforced indirectly via `pub publish --dry-run` in
preflight.
