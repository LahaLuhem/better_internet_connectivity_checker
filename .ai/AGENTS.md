# AGENTS.md — `better_internet_connectivity_checker`

Tool-agnostic brief for any coding agent (Copilot, Cursor, Codex, Claude Code, …) working in
this package. Claude-Code-specific guidance lives in [CLAUDE.md](./CLAUDE.md).

## Project goal
A Dart package for **robust internet-connectivity checking** — distinguishes "a network
interface is up" (cheap, often wrong) from "I can actually reach the public internet right
now" (the question users typically care about). Pure Dart so it works equally well in CLI,
server, web, and Flutter contexts.

Public API in v0.1 is stable: `InternetConnection` scheduler + sealed `InternetStatus`
outcomes, backed by pluggable `ConnectivityProbe` and `ReachabilityPolicy` layers. See
README for usage; APPENDIX for design rationale.

## Stack
- **Dart ≥ 3.10** (constraint pinned in `pubspec.yaml`). 3.10 is the floor because of
  the static dot-shorthand feature; bump only when a new language feature is actually
  consumed.
- **[FVM](https://fvm.app/)** for SDK version pinning (`.fvmrc`). Use `fvm dart …` rather
  than the host `dart` unless you've confirmed they match.
- **`fvm dart test`** for tests, **`fvm dart --no-version-check analyze .`** for pedantic
  static analysis (matches what `flutter --no-version-check analyze .` runs on a Flutter
  app — pedantic mode is intentional, not negotiable). No Flutter dep, no platform
  channels.
- **CHANGELOG + version are owned by [`scripts/release.sh`](../scripts/release.sh).** Do
  not invoke `cider` commands by hand and do not edit `CHANGELOG.md` or `version:`
  directly — run the script (or, on request, ask the user to run it) so the bump,
  CHANGELOG finalisation, commit, tag, and push stay in lockstep. The `cider:` block in
  `pubspec.yaml` is the script's static configuration (URLs, link templates) and may be
  hand-edited freely.
- **Published to pub.dev.** `.pubignore` controls what ships in the tarball.
- **`.editorconfig`** is the source of truth for text-file conventions — line width 100,
  LF endings, UTF-8, per-language indent rules. The Dart formatter's `page_width: 100` in
  `analysis_options.yaml` matches it; keep them aligned if either ever moves.

## Repo layout
```
better_internet_connectivity_checker/
├── lib/
│   ├── better_internet_connectivity_checker.dart   Public entry; `export 'src/…'` only
│   └── src/
│       ├── internet_connection.dart                  Top-level scheduler / lifecycle
│       ├── data/                                     Cross-cutting helpers + tuning knobs
│       │   ├── typedefs.dart                         Shared typedefs (`ResponseAcceptor`)
│       │   └── values.dart                           `Values` static defaults + `noopWithVal`
│       ├── policy/
│       │   ├── reachability_policy.dart              Abstract interface
│       │   └── strategies/                           Concrete impls (`Any`/`All`Reachable)
│       ├── probe/
│       │   ├── connectivity_probe.dart               Abstract interface
│       │   ├── models/                               Value types (target / result)
│       │   └── transports/                           Concrete impls (HTTP HEAD)
│       └── status/
│           ├── internet_status.dart                  Sealed parent (declares `part`s)
│           ├── models/                               Auxiliary types (quality enum)
│           └── outcomes/                             Sealed cases via `part of`
├── test/                                             `dart test` units (mirrors lib/src/)
├── example/                                          Runnable usage samples (see example/AGENTS.md)
├── analysis_options.yaml                             Strict-mode + opinionated lints
├── pubspec.yaml                                      Deps + cider config + topics
├── .pubignore                                        Files excluded from `pub publish`
├── .fvmrc                                            FVM-pinned SDK version
├── .editorconfig                                     Text-file formatting (width, indents)
├── CHANGELOG.md                                      Pipeline-owned; appears on pub.dev
├── README.md                                         pub.dev landing page
├── APPENDIX.md                                       Design rationale (anchor-keyed)
├── CODESTYLE.md                                      Library-package code style
└── .ai/                                              This file + CLAUDE.md (symlinked)
```

**Feature-directory conventions** (apply within `lib/src/<feature>/`):
- `<feature>.dart` at the root holds the abstract interface or the sealed parent.
- `strategies/` or `transports/` — concrete implementations of the interface. Named for
  what they *are* (Strategy-pattern impls, transport impls), not a generic `impl/`.
- `models/` — value types serving the feature (request/result/options).
- `outcomes/` — sealed-class cases. Uses `part of` to share library scope with the
  parent (required by Dart's sealed-class rules; see
  [`CODESTYLE.md#idioms-parts`](../CODESTYLE.md#idioms-parts)).

## Hard rules
1. **The public API lives only in `lib/<package>.dart`.** That file re-exports from
   `lib/src/`. Don't make users import from `package:…/src/…` — the `src/` subtree is
   private by convention. Anything callers need goes through an explicit `export`.
   Cross-cutting helpers and tuning knobs live in `lib/src/data/`:
   - `data/typedefs.dart` — typedefs shared across the project.
   - `data/values.dart` — internal defaults (timeouts, intervals, header maps, the
     curated probe-target list) grouped under `abstract final class Values` so call
     sites read `Values.defaultX` and the origin is obvious. Loose helpers like
     `noopWithVal` stay top-level alongside the class. Before introducing a new magic
     number or default in a class, check whether it belongs in `Values`.
2. **No `print()` in library code.** Diagnostic output is the caller's responsibility
   (loggers, callbacks, etc.). `avoid_print` is already a warning in
   `analysis_options.yaml`.
3. **No `dynamic` escape hatches.** `strict-casts`, `strict-inference`, and
   `strict-raw-types` are all on in `analysis_options.yaml`. If you reach for `dynamic` or
   unconstrained `Object?`, stop and reconsider.
4. **Public symbols carry dartdoc.** `public_member_api_docs` is enabled. Every public
   class / function / getter / extension needs a `///` comment that explains *why*, not
   *what* — types already carry the *what*.
5. **Semver, strictly.** Breaking changes only on a major bump. Any change to a public
   signature, deletion, or behavioural change of a documented contract is breaking.
   `cider` enforces the version-bump discipline.
6. **Pure Dart, no Flutter dep in `pubspec.yaml`.** This package targets every Dart
   platform — server, CLI, web, Flutter. If platform-channel features ever become
   necessary, a sibling Flutter-plugin package can depend on this one — don't add Flutter
   to this `pubspec.yaml`. See
   [`APPENDIX.md#pure-dart-not-flutter`](../APPENDIX.md#pure-dart-not-flutter).
7. **No manual `CHANGELOG.md` or `version:` edits, no hand-run `cider` commands.** All
   three are owned by [`scripts/release.sh`](../scripts/release.sh); manual entries /
   runs will be reordered or overwritten. Curate the `## Unreleased` section of
   `CHANGELOG.md` by hand between releases — the script consumes it. The `cider:` block
   in `pubspec.yaml` is static configuration (link templates, URLs) and may be
   hand-edited.

## Style
Full guide: [`../CODESTYLE.md`](../CODESTYLE.md). The lint posture is deliberately strict
(see `analysis_options.yaml`); rules are enforced through that file plus the DCM checks
called out in CODESTYLE. Top-level rules to keep in working memory:

- Type-annotate every public symbol; `final` by default for fields and locals.
- Nullability is explicit (no `as T` on `T?`).
- 100-column line width; blank lines separate logical chunks within a method.
- No magic numbers in `lib/` code — pull to named `static const`s (cross-cutting defaults
  belong on `Values`, see *Hard rules* above).
- Public symbols carry `///` dartdoc explaining *why*, not *what*.

For everything else — naming, idioms (`Uri.https`, `.wait`, dot shorthands,
`List.unmodifiable`, …), class structure, DCM rules, markdown conventions — go to
[`../CODESTYLE.md`](../CODESTYLE.md).

## Guidelines for any AI agent
- **Always ask before making technical choices.** When the task admits more than one
  reasonable approach (which connectivity-check strategy to default to, which test fixture
  to mock, whether to expose a class vs a function, whether to add a dependency, etc.),
  stop and ask. Present the options with trade-offs, say which you'd pick and why, then
  wait. Don't silently pick one and build. This applies even when a choice feels small —
  small choices compound.
- **Mark recommendations with `★`.** Prefix your preferred option in every set with `★` —
  in tables, bullet lists, headings, inline — so the user can scan and reply by echoing or
  overriding (e.g. "★ for 1–4, change 5 to B"). Exactly one star per option set in most
  cases; occasionally a combined choice warrants more.
- **Document new user-facing features in the README.** Any new public class, function,
  configuration option, or example must be added to the README in the same change.
  Rationale + design trade-offs still belong in `APPENDIX.md`; the README is the
  user-facing entry point and must reflect what the package actually does.
- **Read `analysis_options.yaml` before writing code.** The lint posture is far stricter
  than the Dart default — code that fails lint won't pass review.
- **Surface semver implications loudly.** If a change touches anything re-exported from
  `lib/<package>.dart`, call out whether it's patch / minor / major before the diff lands.
