# CLAUDE.md — `better_internet_connectivity_checker`

Claude-Code-specific guidance. Project facts, stack, hard rules, and AI-agent
guidelines live in [AGENTS.md](./AGENTS.md); the full code-style guide lives in
[`../CODESTYLE.md`](../CODESTYLE.md); design rationale lives in
[`../APPENDIX.md`](../APPENDIX.md). Read AGENTS.md and CODESTYLE.md first.

## Role & context
You're assisting with **better_internet_connectivity_checker**: a pure Dart package that
distinguishes "a network interface is up" from "I can actually reach the public internet
right now". Treat the user as technical and direct. The package is intended for pub.dev —
changes are visible to every downstream user, so breakage is expensive and slow to walk
back (unpublished versions stay reserved for 7 days).

## Communication
- **Concise.** No "here's what I just did" recap; the diff speaks.
- **Explain the *why*** when recommending. The *what* is in the diff.
- Reference code as `file.dart:42` (markdown links if you can).
- Flag breaking-API or lint-violation implications loudly and early.

## Technical choices — always ask first
- **Do not silently pick between reasonable alternatives.** Whenever a task admits more
  than one defensible approach (connectivity-check strategy, dependency choice, whether a
  symbol belongs in `lib/<pkg>.dart`'s public exports or stays under `lib/src/`, function
  vs class API shape, sync vs Future vs Stream return, etc.), **stop and ask**.
  Recommendations in the question are expected — list the options with trade-offs, say
  which you'd pick and why, then wait.
- **"Small" choices count.** The bar isn't "is this architecturally significant" — it's
  "could a reasonable maintainer disagree with my pick". If yes, ask.
- **Mark your recommendation with `★`.** When presenting options, prefix your preferred
  pick(s) with `★` so the user can scan and reply by echoing or overriding (e.g. "go with
  ★ for 1–4, change 5 to B").
- **Exception:** obvious single-answer fixes (typo, clear bug with one correct patch, lint
  error) — just do them.

## Tool preferences
- **Read / Edit / Grep / Glob** over `cat` / `sed` / `grep` / `find`. Always.
- **Bash** only for things without a dedicated tool: `dart`, `fvm`, `git`.
- **Use the FVM-pinned Dart** when running `dart …` — `.fvmrc` is the source of truth.
  Prefer `fvm dart …` unless the host shell is already wrapped.
- **Lint with `fvm dart --no-version-check analyze .`** — the project runs pedantic mode
  by intent (mirrors `flutter --no-version-check analyze .` in Flutter-app projects).
  Don't substitute `fvm dart analyze` and ignore lints it surfaces; they're the contract.
- **Agent tool** for wide / open-ended searches or to keep large outputs out of main
  context. Not for trivial lookups.

## Scope awareness
- **Public-API edits** (anything in `lib/<package>.dart`, or anything re-exported from it)
  are pub.dev-visible. Treat them with care; flag whether the change is patch / minor /
  major under semver before landing.
- **`lib/src/` edits** are private. Refactor freely as long as the public re-exports stay
  stable.
- **`test/` edits** are local — no publish impact.
- **`analysis_options.yaml` edits** affect every file. Surface lint-posture changes loudly
  and add a written reason in `APPENDIX.md`.
- **`pubspec.yaml` edits** that touch `dependencies` add to every downstream user's
  transitive closure — treat as public-API-class.

## Auto-memory conventions for this project
- **`project` memories** — scope/constraints the user states aloud (e.g. "we're shipping
  v0.1 before the end of the sprint", "minimum SDK bumps to 3.x on date Y"). Convert
  relative dates to absolute.
- **`feedback` memories** — corrections AND validated non-obvious choices. Include
  **Why** and **How to apply** lines.
- **`reference` memories** — external pointers (pub.dev page, GitHub issues, related
  discussions). Not internal code paths — those live in AGENTS.md or are derivable from
  the repo.
- **Do NOT save** Dart file paths, lint-rule lists, or API surface — all derivable from
  the repo or APPENDIX.md. Re-deriving is safer than acting on a stale memory.
- **Before acting on a memory**, verify the named file / symbol still exists.

## Plan before editing when
- The change touches the public API (anything re-exported from `lib/<package>.dart`). Even
  adding a new public method affects semver and downstream users.
- You're adding or removing a dependency in `pubspec.yaml`. Each dep expands the
  user-facing surface area and constrains downstream resolution.
- You're changing `analysis_options.yaml`. Lint posture is project-wide; any toggle
  deserves a written reason in APPENDIX.

For single-file, single-concern fixes inside `lib/src/`: just do it.

The release flow — `CHANGELOG.md` and `version:` in `pubspec.yaml` — is **not** in this
list. It's pipeline-owned; see *Forbidden / confirm-first actions* below. Don't plan a
CHANGELOG edit; don't make one. The `cider:` block itself is static configuration (URLs,
link templates) and may be hand-edited like any other yaml.

## Commit / PR etiquette
- **Never commit without being asked.** Not after a fix, not as a "checkpoint".
- **Never push without being asked.** Especially not to `main`.
- **Never `--amend`** unless the user asked — create a new commit instead.
- **Never `--no-verify`**, **never `git add -A`** — stage named paths.
- Match existing commit style (short imperative subject, no Claude-authored footer unless
  asked).
- When asked for a commit: show `git status` + `git diff`, draft the message, wait for
  approval.

## Forbidden / confirm-first actions
- **Never** `dart pub publish` (or `fvm dart pub publish`). Publishing is effectively
  one-way — pub.dev reserves the version for 7 days after retraction. The user runs
  `publish` manually.
- **Never** run `cider` commands (`cider bump`, `cider release`, …) and **never**
  manually edit `CHANGELOG.md` or the `version:` field in `pubspec.yaml`. Version bumps
  and CHANGELOG entries are owned by automated release pipelines (TBA); manual edits
  there will be reordered or overwritten. The `cider:` block in `pubspec.yaml` is static
  configuration (link templates, URLs) — hand-edit it freely.
- **Never** edit `pubspec.lock` directly. It's `dart pub get`'s output.
- **Never** delete files under `.fvm/`, `.dart_tool/`, or `pubspec.lock` without approval.
  These are tooling state; deleting them forces a re-resolve.
- **Destructive git** (`reset --hard`, `push --force`, `branch -D`, `clean -fd`) → ask
  first.

## Definition of done
- `fvm dart --no-version-check analyze .` clean (pedantic mode — non-negotiable).
- `fvm dart format --output=none --set-exit-if-changed .` clean.
- `fvm dart test` green (where tests exist).
- DCM rules in `analysis_options.yaml` applied by hand (`dart analyze` does not run
  them): `no-empty-block`, `newline-before-return`, `prefer-commenting-analyzer-ignores`,
  plus the project-wide rule that blank lines segment logical chunks inside methods.
- `fvm dart pub publish --dry-run` clean if the change is publish-relevant. Do **not**
  bump the version or add a CHANGELOG entry to make the dry-run happy — the pipeline
  owns those.
- Public API additions documented with `///` dartdoc and reflected in README.
- Explicitly call out what you did NOT verify (e.g. "didn't exercise on a real network —
  only mocked HTTP responses").
