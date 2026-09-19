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

Laptop-only. Does not run inside CI.

## Usage

```bash
scripts/release.sh                                # fully interactive
scripts/release.sh patch                          # bump type set, confirm on TTY
scripts/release.sh patch --yes                    # non-interactive (CI-style)
scripts/release.sh --dry-run                      # full preflight + plan, no side effects
scripts/release.sh minor -m "Big new feature"     # annotated tag with this message
```

`BUMP` is one of `major`, `minor`, `patch`. The script prompts on a TTY if omitted.

### Tag mode

By default, `git tag <version>` produces a **lightweight tag**: a bare ref pointer with no body,
message, or signature. Pass `-m "MSG"` / `--tag-message "MSG"` for an **annotated tag** with that
message, which also gets signed if your git config has `tag.gpgSign=true`.

The lightweight default doesn't care about your `tag.gpgSign` setting. On the no-`-m` path the
script runs `git tag` with `-c tag.gpgSign=false` applied to that one invocation, so plain
`release.sh minor` never opens an editor or demands a message. Lightweight tags can't be signed,
there being no body to sign, so the bypass is mechanically necessary rather than a style choice.

## What's pipeline-owned vs. hand-editable

`CHANGELOG.md`, the `version:` field in `pubspec.yaml`, and `example/pubspec.lock` are
**pipeline-owned**: the script reorders or overwrites manual edits to them. Hand-edits
will not survive the next release.

`example/pubspec.lock` is regenerated automatically because `example/pubspec.yaml`
declares its parent via `path: ../`, so when the parent version changes the lockfile has to
follow. The release script runs `(cd example && flutter pub get)` after the
bump and stages the refreshed lockfile in the prep commit, so the tree is consistent
before pub.dev sees it. Without this, the next `flutter pub get` *anywhere* (CI's
publish step, pana on pub.dev, an IDE on a contributor's machine) would rewrite it
and `dart pub publish` would complain that a checked-in file is modified.

The `## Unreleased` block in `CHANGELOG.md` is the script's **input**, curated by hand between
releases. The script bails if it's empty.

The `cider:` block in `pubspec.yaml` is static configuration (link templates, URLs), sits outside
the pipeline-owned set, and is hand-editable.

## Tag format

`<MAJOR>.<MINOR>.<PATCH>`, no `v` prefix. Matches the trigger pattern in
[`../.github/workflows/publish.yml`](../.github/workflows/publish.yml)
(`[0-9]+.[0-9]+.[0-9]+`) and pub.dev's canonical `{{version}}` convention.

## Preflight

The script refuses to proceed unless every check passes:

- `dart` resolvable (prefers `.fvm/flutter_sdk/bin/dart` if present, else PATH).
- `flutter` on PATH (used to regenerate `example/pubspec.lock` against the new parent
  version, see *What's pipeline-owned vs. hand-editable* above).
- `cider` on PATH.
- `docker` on PATH, daemon running (scripts + workflows are linted via the linterpol
  image: `shellcheck` and `actionlint`, no local installs).
- Working tree clean, on `main`, in sync with `origin/main` (fetches first).
- `CHANGELOG.md` has a non-empty `## Unreleased` (or `## [Unreleased]`) section.
- `dart format`, `dart analyze`, and `dart test` all clean.
- The target tag does not already exist locally or on the remote.

`dart pub publish --dry-run` is *not* in preflight. It cross-checks 3 things that all have to hold
at once:

1. `pubspec.yaml`'s `version:` matches a CHANGELOG header.
2. No checked-in files are modified in the working tree.
3. The tarball builds and validates against pub.dev rules.

(1) only holds *after* `cider bump` plus `cider release`. (2) only holds *after* `git commit`,
since running the dry-run against the working tree mid-execute would trip on the bump and release
modifications. So the dry-run runs as step 5, once the prep commit lands. The `ERR` trap handles
failure in 2 phases:

- **Pre-commit failure** (bump, release, or `example/` resync errored, no commit yet):
  restore `pubspec.yaml` + `CHANGELOG.md` + `example/pubspec.lock` from `HEAD`.
- **Post-commit, pre-tag failure** (dry-run rejected the prep commit):
  `git reset --hard HEAD~1` to drop the prep commit, leaving the working
  tree exactly as it was before `release.sh` started. No remote tag is ever created here, because
  the validation gate sits between commit and tag, so there's nothing to clean up on `origin`.

Once the dry-run passes the trap clears, and `git tag` / `git push` failures need manual recovery
(the script prints the recipe).

## FVM note

If `.fvm/flutter_sdk/bin/dart` exists, the script prepends it to `PATH` so plain
`dart` resolves to the SDK FVM installed for the `.fvmrc` channel. Otherwise it falls back to
whatever `dart` is on `PATH`, so a non-FVM contributor can run the script unchanged.
SDK-version compatibility is enforced indirectly via `pub publish --dry-run` in
preflight.
