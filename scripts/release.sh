#!/usr/bin/env bash
# ===========================================================================
# release.sh
#
# Cut a versioned release of better_internet_connectivity_checker. Bumps the
# pubspec.yaml `version:` with `cider`, finalises the CHANGELOG.md
# `## Unreleased` section into a dated `## <new_version>` block, commits both
# files, creates a SemVer tag, and pushes commit + tag atomically. The tag
# push triggers .github/workflows/publish.yml, which then publishes to
# pub.dev via OIDC.
#
# Laptop-only — does not run inside CI. Safe by default: preflight refuses to
# proceed on a dirty tree, wrong branch, origin mismatch, missing tooling,
# an empty/missing `## Unreleased` section, failing format/analyze/test or
# `pub publish --dry-run`, or a tag that already exists.
#
# Tags are pushed without a `v` prefix, matching the trigger pattern in
# .github/workflows/publish.yml (`[0-9]+.[0-9]+.[0-9]+`) and pub.dev's
# canonical `{{version}}` convention.
#
# Usage:
#   scripts/release.sh                # fully interactive
#   scripts/release.sh patch          # bump type set, confirm on TTY
#   scripts/release.sh patch --yes    # non-interactive (CI-style)
#   scripts/release.sh --dry-run      # full preflight + plan, no side effects
# ===========================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

MAIN_BRANCH="main"

BUMP=""
YES=0
DRY_RUN=0

usage() {
    cat <<'USAGE'
release.sh — bump version, finalise CHANGELOG, commit, tag, push to origin.

Usage:
  scripts/release.sh [BUMP] [OPTIONS]

Arguments:
  BUMP            one of: major, minor, patch  (prompted if omitted on a TTY)

Options:
  -y, --yes       skip the confirmation prompt (required for non-TTY)
  -n, --dry-run   run full preflight + print the plan, no side effects
  -h, --help      show this message

Preflight (all must pass):
  - cider + fvm on PATH
  - working tree clean, on `main`, in sync with origin/main (fetches first)
  - CHANGELOG.md has a non-empty `## Unreleased` (or `## [Unreleased]`) section
  - `fvm dart format --output=none --set-exit-if-changed .` clean
  - `fvm dart --no-version-check analyze .` clean
  - `fvm dart test` green
  - `fvm dart pub publish --dry-run` clean
  - computed tag unused locally AND on origin

Sequence:
  cider bump <BUMP>          (pubspec.yaml version → new)
  cider release              (CHANGELOG.md ## Unreleased → ## <new> dated today)
  git add  pubspec.yaml CHANGELOG.md
  git commit -m "Prep for release <new>"
  git tag <new>
  git push --atomic origin HEAD:main <new>   (triggers publish.yml)

Non-interactive example:
  scripts/release.sh patch --yes
USAGE
}

while (($#)); do
    case "$1" in
        major|minor|patch) BUMP="$1" ;;
        -y|--yes)          YES=1 ;;
        -n|--dry-run)      DRY_RUN=1 ;;
        -h|--help)         usage; exit 0 ;;
        *)                 printf 'unknown arg: %s (use --help)\n' "$1" >&2; exit 2 ;;
    esac
    shift
done

log()  { printf '[release] %s\n' "$*"; }
step() { printf '\n[release] == %s ==\n' "$*"; }
err()  { printf '[release] ERROR: %s\n' "$*" >&2; }

is_tty() { [ -t 0 ]; }

prompt_bump() {
    local reply
    while :; do
        printf 'Bump type [major/minor/patch] (default: patch): ' >&2
        read -r reply
        reply="${reply:-patch}"
        case "$reply" in
            major|minor|patch) echo "$reply"; return 0 ;;
            *) printf 'Please enter major, minor, or patch.\n' >&2 ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Resolve BUMP
# ---------------------------------------------------------------------------
if [ -z "$BUMP" ]; then
    if is_tty; then
        BUMP="$(prompt_bump)"
    else
        err 'BUMP argument required in non-interactive mode (one of: major, minor, patch).'
        exit 2
    fi
fi

# ---------------------------------------------------------------------------
# Preflight: tooling (fail fast — cheapest checks first)
# ---------------------------------------------------------------------------
step 'Preflight: tooling'
fail=0
if ! command -v fvm >/dev/null 2>&1; then
    err 'fvm not on PATH. Install: https://fvm.app/'
    fail=1
else
    log 'fvm available.'
fi
if ! command -v cider >/dev/null 2>&1; then
    err 'cider not on PATH. Install: fvm dart pub global activate cider'
    fail=1
else
    log 'cider available.'
fi
[ "$fail" -eq 1 ] && { err 'Tooling preflight failed — aborting.'; exit 1; }

# ---------------------------------------------------------------------------
# Preflight: git state
# ---------------------------------------------------------------------------
step 'Preflight: git state'
log 'Fetching origin (with tag prune)...'
git fetch origin --quiet --tags --prune --prune-tags

if [ -n "$(git status --porcelain)" ]; then
    err 'Working tree is dirty. Commit or stash first.'
    fail=1
else
    log 'Working tree clean.'
fi

current_branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$current_branch" != "$MAIN_BRANCH" ]; then
    err "Current branch is '$current_branch'; expected '$MAIN_BRANCH'."
    fail=1
else
    log "On branch '$MAIN_BRANCH'."
fi

local_head="$(git rev-parse HEAD)"
remote_head="$(git rev-parse "origin/${MAIN_BRANCH}" 2>/dev/null || echo '')"
if [ -z "$remote_head" ]; then
    err "origin/${MAIN_BRANCH} not found."
    fail=1
elif [ "$local_head" != "$remote_head" ]; then
    err "HEAD ($local_head) is not at origin/${MAIN_BRANCH} ($remote_head). Pull / push first."
    fail=1
else
    log "In sync with origin/${MAIN_BRANCH}."
fi

[ "$fail" -eq 1 ] && { err 'Git-state preflight failed — aborting.'; exit 1; }

# ---------------------------------------------------------------------------
# Compute new version from pubspec.yaml (via cider)
# ---------------------------------------------------------------------------
step 'Compute new version'
current_version="$(cider version)"
log "Current version: ${current_version}"

# Plain SemVer arithmetic. Pre-release / build metadata is stripped so the
# bump produces a clean X.Y.Z — cider's own behaviour for a plain X.Y.Z
# input matches this, so the two will agree.
IFS='.' read -r cur_major cur_minor cur_patch <<< "${current_version%%[+-]*}"
case "$BUMP" in
    major) new_version="$((cur_major + 1)).0.0" ;;
    minor) new_version="${cur_major}.$((cur_minor + 1)).0" ;;
    patch) new_version="${cur_major}.${cur_minor}.$((cur_patch + 1))" ;;
esac
log "New version:     ${new_version}  (${BUMP} bump)"

# ---------------------------------------------------------------------------
# Preflight: tag collision (no `v` prefix — matches publish.yml + pub.dev)
# ---------------------------------------------------------------------------
step 'Preflight: tag collision'
if git rev-parse "refs/tags/${new_version}" >/dev/null 2>&1; then
    err "Tag '${new_version}' already exists locally."
    exit 1
elif git ls-remote --tags origin "refs/tags/${new_version}" | grep -q .; then
    err "Tag '${new_version}' already exists on origin."
    exit 1
else
    log "Tag '${new_version}' is unused locally and on origin."
fi

# ---------------------------------------------------------------------------
# Preflight: `## Unreleased` populated in CHANGELOG.md
# ---------------------------------------------------------------------------
step 'Preflight: CHANGELOG'
if ! grep -qiE '^## \[?Unreleased\]?' CHANGELOG.md 2>/dev/null; then
    err 'CHANGELOG.md is missing a `## Unreleased` section.'
    err 'Add notes for this release first, e.g.:'
    err '  ## Unreleased'
    err '  - Describe the change.'
    exit 1
fi

unreleased_block="$(awk '
    BEGIN{found=0}
    tolower($0) ~ /^## \[?unreleased\]?/{found=1; next}
    found && /^## /{exit}
    found{print}
' CHANGELOG.md)"

if [ -z "$(printf '%s' "$unreleased_block" | tr -d '[:space:]-')" ]; then
    err 'CHANGELOG.md has `## Unreleased` but no entries beneath it.'
    err 'Populate the section before re-running.'
    exit 1
fi
log '`## Unreleased` populated.'

# ---------------------------------------------------------------------------
# Preflight: format / analyze / test / publish dry-run (cheapest → slowest)
# ---------------------------------------------------------------------------
step 'Preflight: fvm dart format'
if ! fvm dart format --output=none --set-exit-if-changed .; then
    err 'Formatting check failed. Run `fvm dart format .` and commit.'
    exit 1
fi

step 'Preflight: fvm dart --no-version-check analyze'
if ! fvm dart --no-version-check analyze .; then
    err 'Static analysis failed.'
    exit 1
fi

step 'Preflight: fvm dart test'
if ! fvm dart test; then
    err 'Test suite failed.'
    exit 1
fi

step 'Preflight: fvm dart pub publish --dry-run'
if ! fvm dart pub publish --dry-run; then
    err '`pub publish --dry-run` failed.'
    exit 1
fi

# ---------------------------------------------------------------------------
# Plan
# ---------------------------------------------------------------------------
step 'Plan'
cat <<PLAN
Will execute, in order:
  1. cider bump ${BUMP}                                    (pubspec.yaml: ${current_version} → ${new_version})
  2. cider release                                         (CHANGELOG.md: ## Unreleased → ## ${new_version} [dated today])
  3. git add  pubspec.yaml CHANGELOG.md
  4. git commit -m "Prep for release ${new_version}"
  5. git tag ${new_version}
  6. git push --atomic origin HEAD:${MAIN_BRANCH} ${new_version}   (triggers .github/workflows/publish.yml)

publish.yml will then build & publish ${new_version} to pub.dev via OIDC.
PLAN

if [ "$DRY_RUN" -eq 1 ]; then
    log 'Dry-run mode — preflight passed; nothing executed.'
    exit 0
fi

# ---------------------------------------------------------------------------
# Confirm
# ---------------------------------------------------------------------------
if [ "$YES" -eq 0 ]; then
    if is_tty; then
        printf '\nProceed with release? [y/N] '
        read -r reply
        case "$reply" in
            y|Y|yes|YES) ;;
            *) log 'Aborted.'; exit 0 ;;
        esac
    else
        err 'Refusing to proceed without --yes in non-interactive mode.'
        exit 2
    fi
fi

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
# Auto-revert pubspec.yaml + CHANGELOG.md if anything fails between the
# `cider bump` step and the `git commit` step. Cleared once the commit
# succeeds — after that, the commit + tag are in the local repo and
# automatic cleanup would silently nuke real work.
cider_phase=0
trap '
    rc=$?
    if [ "$cider_phase" = "1" ]; then
        printf "[release] failure mid-release — restoring pubspec.yaml + CHANGELOG.md from HEAD\n" >&2
        git checkout HEAD -- pubspec.yaml CHANGELOG.md 2>/dev/null || true
    fi
    exit $rc
' ERR

cider_phase=1

step "cider bump ${BUMP}"
bumped_version="$(cider bump "$BUMP")"
if [ "$bumped_version" != "$new_version" ]; then
    err "cider produced '${bumped_version}' but expected '${new_version}'."
    err 'Aborting; pubspec.yaml will be reverted by the trap.'
    exit 1
fi

step 'cider release'
cider release

step 'git add pubspec.yaml CHANGELOG.md'
git add pubspec.yaml CHANGELOG.md

step "git commit -m \"Prep for release ${new_version}\""
git commit -m "Prep for release ${new_version}"

# Past this point: trap no longer auto-reverts. Manual recovery if the
# tag/push fails:
#   git tag -d ${new_version} 2>/dev/null
#   git reset --hard HEAD~1
cider_phase=0

step "git tag ${new_version}"
git tag "${new_version}"

step "git push --atomic origin HEAD:${MAIN_BRANCH} ${new_version}"
git push --atomic origin "HEAD:${MAIN_BRANCH}" "${new_version}"

step "Released ${new_version}"
log "Pushed commit + tag '${new_version}' to origin/${MAIN_BRANCH}."
log "Watch .github/workflows/publish.yml for the pub.dev upload."
