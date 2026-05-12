# AGENTS.md — `ultimate_internet_connectivity_checker`

Tool-agnostic brief for any coding agent (Copilot, Cursor, Codex, Claude Code, …) working in
this package. Claude-Code-specific guidance lives in [CLAUDE.md](./CLAUDE.md).

## Project goal
A Dart package for **robust internet-connectivity checking** — distinguishes "a network
interface is up" (cheap, often wrong) from "I can actually reach the public internet right
now" (the question users typically care about). Pure Dart so it works equally well in CLI,
server, web, and Flutter contexts.

The package is in early scaffolding — no public API yet. The intent shapes the file layout
and the lint posture; the surface itself is still to be designed.

## Stack
- **Dart ≥ 3.11** (constraint pinned in `pubspec.yaml`).
- **[FVM](https://fvm.app/)** for SDK version pinning (`.fvmrc`). Use `fvm dart …` rather
  than the host `dart` unless you've confirmed they match.
- **`dart test`** + **`dart analyze`** for verification. No Flutter dep, no platform
  channels.
- **[`cider`](https://pub.dev/packages/cider)** for CHANGELOG + version management
  (configured at the bottom of `pubspec.yaml`).
- **Published to pub.dev.** `.pubignore` controls what ships in the tarball.
- **`.editorconfig`** is the source of truth for text-file conventions — line width 100,
  LF endings, UTF-8, per-language indent rules. The Dart formatter's `page_width: 100` in
  `analysis_options.yaml` matches it; keep them aligned if either ever moves.

## Repo layout
```
ultimate_internet_connectivity_checker/
├── lib/
│   ├── ultimate_internet_connectivity_checker.dart   Public entry; `export 'src/…'`s only
│   └── src/                                           Implementation; not re-exported
├── test/                                              `dart test`-discoverable units (TBA)
├── example/                                           Runnable usage samples (TBA)
├── analysis_options.yaml                              Strict-mode + opinionated lints
├── pubspec.yaml                                       Deps + cider config + topics
├── .pubignore                                         Files excluded from `pub publish`
├── .fvmrc                                             FVM-pinned SDK version
├── .editorconfig                                      Text-file formatting (width, indents)
├── CHANGELOG.md                                       cider-managed; appears on pub.dev
├── README.md                                          pub.dev landing page
├── APPENDIX.md                                        Design rationale (anchor-keyed)
└── .ai/                                               This file + CLAUDE.md (symlinked)
```

## Hard rules
1. **The public API lives only in `lib/<package>.dart`.** That file re-exports from
   `lib/src/`. Don't make users import from `package:…/src/…` — the `src/` subtree is
   private by convention. Anything callers need goes through an explicit `export`.
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
6. **CHANGELOG before publish.** `cider log add <kind> "…"` (or hand-edit) before any
   `dart pub publish`. The CHANGELOG appears on pub.dev's *Changelog* tab — empty /
   missing entries make releases look unreviewed.
7. **Pure Dart, no Flutter dep in `pubspec.yaml`.** This package targets every Dart
   platform — server, CLI, web, Flutter. If platform-channel features ever become
   necessary, a sibling Flutter-plugin package can depend on this one — don't add Flutter
   to this `pubspec.yaml`. See
   [`APPENDIX.md#pure-dart-not-flutter`](../APPENDIX.md#pure-dart-not-flutter).

## Style (Dart-as-strongly-typed)
The lint posture is deliberately strict (see `analysis_options.yaml`). The house style
values explicit types, no ambient mutability, and small focused classes.

- **Type-annotate every public symbol.** Inference is fine on locals
  (`omit_local_variable_types` is on); public surfaces are not the place to rely on
  inference.
- **`final` by default for fields and locals.** `prefer_final_fields`,
  `prefer_final_locals`, `prefer_final_in_for_each` are all on. Parameters are *not*
  required to be `final`, consistent with `avoid_final_parameters` and
  `parameter_assignments` (which forbids the actual bad behaviour — mutating a parameter
  inside the body).
- **Nullability is explicit.** Use `T?` everywhere a value can be missing.
  `cast_nullable_to_non_nullable` is on — `as T` on a `T?` will fail lint.
- **No Java ceremony.** No getter-only abstract base classes, no `AbstractFooFactory`, no
  interface-per-class. Use mixins / sealed classes / records / extension types where they
  add clarity, not weight.
- **Prefer expression bodies** (`prefer_expression_function_bodies`) and **single quotes**
  (`prefer_single_quotes`).
- **No magic numbers in `lib/` code.** Pull constants to named `static const`s with a
  descriptive identifier.
- **Prefer abbreviations over initialisms for domain terms.** In code, comments,
  docstrings, and log messages alike, expand. Widely-known protocol initialisms (HTTP,
  DNS, TCP, TLS, …) stay as-is; novel project terms get spelt out.
- **Wrap text-file content at 100 columns.** `.editorconfig` is authoritative;
  Markdown / Dart / YAML all share the same cap.

## Documentation convention
- **APPENDIX.md is the source of truth for rationale.** Hard rules, pitfalls, and workflow
  stay in this file and CLAUDE.md; the "why we do it this way" essays live in
  [`APPENDIX.md`](../APPENDIX.md).
- **Explicit `<a id="…">` anchors** sit above every APPENDIX heading. Link to sections via
  the anchor, not the heading text.
- **Anchor stability is load-bearing.** When renaming a heading, keep the existing anchor.
  If you must change it, `rg '#<old-anchor>'` across the repo and update every caller in
  the same change.

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
