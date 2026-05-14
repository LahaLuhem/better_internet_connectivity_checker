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
- **CHANGELOG + version are owned by automated release pipelines (TBA).** Do not invoke
  `cider` commands by hand and do not edit `CHANGELOG.md` or `version:` directly. The
  `cider:` block in `pubspec.yaml` is the pipeline's static configuration (URLs, link
  templates) — hand-edit it freely.
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
└── .ai/                                              This file + CLAUDE.md (symlinked)
```

**Feature-directory conventions** (apply within `lib/src/<feature>/`):
- `<feature>.dart` at the root holds the abstract interface or the sealed parent.
- `strategies/` or `transports/` — concrete implementations of the interface. Named for
  what they *are* (Strategy-pattern impls, transport impls), not a generic `impl/`.
- `models/` — value types serving the feature (request/result/options).
- `outcomes/` — sealed-class cases. Uses `part of` to share library scope with the
  parent (required by Dart's sealed-class rules; see Style section).

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
   three are owned by automated release pipelines (TBA); manual entries / runs will be
   reordered or overwritten. The `cider:` block in `pubspec.yaml` is static
   configuration (link templates, URLs) and may be hand-edited.

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
- **Local-variable names carry a concise type-suffix.** Dart is strongly typed, but a
  reader without IDE inlay-hints can't see the inferred type — the *name* has to do
  that work. Suffix a local with what it *is* so the next reader doesn't have to
  scroll back to the assignment (or install a plugin) to recover the type.
  **Callback parameters** are exempt and stay single-word (`result`, `probe`,
  `target`) — the enclosing call site already pins the type. Single-letter callback
  params are out, *except* symmetric pair-wise params in comparators / reducers where
  `(a, b)` is the genre convention. Regular method parameters follow the
  local-variable rule, not the callback exemption. **When a domain type exists, the
  suffix is the type name** — `suggestedProbeMethod` (not `suggestedMethod`),
  `probeMethodNames` (not `methodNames`), `probeResults` (not `results`). Generic
  suffixes (`Names`, `Method`, `Results`) lose the disambiguation the rule is meant
  to provide.

  ```dart
  // Prefer:
  final probeResults = await targets.map(probe.probe).wait;
  final worstDuration = probeResults
      .map((result) => result.responseTime)
      .reduce((a, b) => a > b ? a : b);

  // Over:
  final results = await targets.map(probe.probe).wait;
  final worst = results.map((r) => r.responseTime).reduce((a, b) => a > b ? a : b);
  ```

  Strong format-string conventions (`hh`/`mm`/`ss` in a timestamp formatter, etc.)
  override this — the rule targets *type ambiguity*, not all short names.
- **Wrap text-file content at 100 columns.** `.editorconfig` is authoritative;
  Markdown / Dart / YAML all share the same cap.
- **Blank lines separate logical chunks within a method.** Group guard checks, setup,
  the main action, and finalisation with one blank line between groups. Lets readers
  scan past chunks they don't need without re-parsing them line-by-line.
- **`assert` for dev-time errors, `throw` for runtime ones.** Constraints a caller can
  see violated during development (negative number where non-negative is required, empty
  list where non-empty is expected, etc.) belong in `assert` — stripped in release mode,
  zero runtime cost. Reserve `throw` and `Exception` for genuine runtime conditions the
  caller cannot guarantee at compile/dev time (network failure, parsing untrusted input,
  missing file, third-party API contract violations). Prefer init-list asserts —
  `prefer_asserts_in_initializer_lists` and `prefer_asserts_with_message` are both on.
- **Any class with fields and constructors: fields → constructors → other members.**
  Lets a reader scan the state shape first, then how to construct it, then how to use
  it. Within constructors, unnamed first, then factories (matches
  `sort_unnamed_constructors_first`). Static helpers go after the methods. Applies to
  value types (`ProbeTarget`, `Reachable`, …), service classes (`InternetConnection`,
  `HttpHeadProbe`), test helpers (`StubProbe`) — wherever a class has both state and a
  constructor. Pure-static namespace classes (`Values`) and field-less interface
  classes (`ConnectivityProbe`, `ReachabilityPolicy`) have nothing to order; the rule
  applies vacuously.
- **Use static dot shorthands (Dart 3.10+) wherever the context type is known.** They
  resolve from the parameter / return / variable type, not from inference of arbitrary
  expressions. Drop the leading type name in *all* of these positions, not just the
  obvious enum case:
  - Enum values in patterns and arg slots:
    `Reachable(quality: cond ? .slow : .good)`, `case .head =>`.
  - Named constructors when the return / context type pins it:
    inside `Future<ProbeResult> probe(…)`, write `return .success(target: …, …)` rather
    than `return ProbeResult.success(…)`.
  - Const factories on widget parameter types — `padding: const .all(12)`, `margin: .zero`,
    `padding: const .symmetric(horizontal: 12, vertical: 4)`. Works on
    `EdgeInsetsGeometry`-typed params because the static factory delegates through.
  - Flex alignment / sizing slots — `crossAxisAlignment: .start`, `mainAxisSize: .min`,
    `mainAxisAlignment: .center`.

  Skip when it hurts readability — `.new(…)` for unnamed constructors typically does;
  cases where the surrounding context type isn't obvious without re-reading.

  After dropping a fully-qualified prefix, the type name often disappears from the file
  entirely — remove it from any `show` clauses too. Re-running analyze surfaces
  `unused_shown_name` warnings for orphaned ones.
- **Prefer collection-for / collection-if over `Iterable.map(…).toList()` in widget
  trees.** A literal list with embedded control flow reads as data; a `.map(…).toList()`
  reads as a pipeline that incidentally produces data. The literal form also doesn't
  bloat the file with `<T>` annotations the list-literal context already infers:

  ```dart
  // Prefer:
  DropdownButton(
    value: viewModel.probeMethod,
    items: [
      for (final method in ProbeMethod.values)
        DropdownMenuItem(value: method, child: Text(method.label)),
    ],
    onChanged: …,
  )

  // Over:
  DropdownButton<ProbeMethod>(
    value: viewModel.probeMethod,
    items: ProbeMethod.values
        .map((m) => DropdownMenuItem<ProbeMethod>(value: m, child: Text(m.label)))
        .toList(),
    onChanged: …,
  )
  ```

  Drop explicit generic type arguments when the surrounding context (other args, the
  assignment target, the return slot) already pins them. Keep them when inference would
  otherwise fall back to `dynamic` — e.g. `MaterialPageRoute<void>(builder: …)` stays,
  because nothing else constrains the route's `T`.
- **Prefer the `dart:async` `wait` extensions over the static `Future.wait(...)`.** The
  extensions (`Iterable<Future<T>>.wait` and the record forms `FutureRecord2`…
  `FutureRecord9`) live in `dart:async`'s `future_extensions.dart` and supersede the
  static call for everyday use.
  - **Fixed number of differently-typed futures → record form.** `(f1, f2).wait`
    returns `Future<(T1, T2)>` and destructures directly. Never await a list literal
    and index into the result by `.first` / `[1]` / etc. — that collapses element
    types to the common supertype and isn't type-checked against slot order, so a
    swap reads as valid until runtime.
  - **Dynamic number of same-typed futures → iterable form.** `iterable.wait` returns
    `Future<List<T>>` just like `Future.wait(iterable)`, but errors surface as
    `ParallelWaitError` carrying both per-slot values and per-slot errors — which
    lets callers dispose successful results when a sibling future fails.

  ```dart
  // Prefer (fixed-size, mixed types):
  final (anyStatus, allStatus) = await (any.checkOnce(), all.checkOnce()).wait;

  // Over:
  final results = await Future.wait([any.checkOnce(), all.checkOnce()]);
  final anyStatus = results.first;
  final allStatus = results[1];

  // Prefer (dynamic-size):
  final results = await targets.map(probe.probe).wait;

  // Over:
  final results = await Future.wait(targets.map(probe.probe));
  ```
- **Prefer `Uri.https(…)` / `Uri.http(…)` over `Uri.parse(…)` for compile-time-known
  URLs, and pass path / query parameters as separate arguments — not mashed into the
  authority.** The named constructor's shape is `(authority, [unencodedPath,
  queryParameters])`. Component-wise construction makes the host, path, and query
  visible at a glance and short-circuits the kinds of typo `Uri.parse` silently
  accepts (missing `://`, stray slashes, unencoded query chars). `Uri.parse` is still
  the right tool for runtime input (user-supplied URLs, response payloads).

  ```dart
  // Prefer:
  Uri.https('jsonplaceholder.typicode.com', '/todos/1')
  Uri.https('pokeapi.co', '/api/v2/ability/', {'limit': '1'})

  // Over (path / query smuggled into the authority — parsed at runtime anyway):
  Uri.https('pokeapi.co/api/v2/ability/?limit=1')

  // Over (full string parse — same drawback, plus scheme is now stringly-typed):
  Uri.parse('https://pokeapi.co/api/v2/ability/?limit=1')
  ```

  **Exception (`lib/src/` only):** the internal `ConstUri('https://...')` wrapper
  ([`lib/src/data/models/const_uri.dart`](../lib/src/data/models/const_uri.dart))
  is permitted when it unlocks `const` for an enclosing value type — e.g. the
  `static const Values.defaultProbeTargets` list, where `const` canonicalisation
  drops the `List.unmodifiable` wrapper and shares one parsed `Uri` across
  identical literals. `ConstUri` still pays parse cost (lazily, on first access)
  and is fundamentally a deferred `Uri.parse` — the trade-off only pays off when
  the enclosing type is *already* `const`-constructible. Stay structural in
  `test/` / `example/` (no `const` payoff to justify the indirection) and never
  in public-API code (anything re-exported from `lib/<package>.dart`).
- **Prefer `List.unmodifiable(…)` over `UnmodifiableListView(…)` as the default for
  exposing immutable collections** (same for `Set.unmodifiable` / `Map.unmodifiable`
  vs their `…View` counterparts in `dart:collection`). The constructor *copies*:
  snapshot semantics, decoupled from whatever the caller passed in. The `…View`
  only *wraps*: anyone who still holds the underlying collection can mutate it, and
  the view silently follows. That footgun outweighs the saved copy in almost every
  case.

  Reach for `UnmodifiableListView` only when you specifically want **read-through
  visibility** into private mutable internal state — e.g. a future logging /
  event-buffer class whose consumers should see new entries appended live.

  ```dart
  // Prefer — defensive snapshot, caller-supplied list cannot mutate our state:
  class Foo {
    Foo(List<X> input) : _xs = List.unmodifiable(input);
    final List<X> _xs;
  }

  // Reserve — read-through view of private mutable internal state:
  class EventLog {
    final List<Event> _events = [];
    List<Event> get events => UnmodifiableListView(_events);
    void add(Event e) => _events.add(e);
  }
  ```
- **`part` / `part of` only when structurally needed.** Not a smell on its own.
  Legitimate uses: sealed-class cases across files (Dart 3 requires same library for
  sealed subtypes — see `status/outcomes/`), code-generation outputs (`*.g.dart` from
  freezed, json_serializable, drift, etc.). Avoid for general code organisation —
  imports/exports are explicit, parts hide dependencies and leak `_private` symbols
  across files within the library.
- **DCM (free tier) rules apply by hand.** `dart analyze` does not run them, but the
  project treats them as non-negotiable:
  - **`no-empty-block`** — every block (function literal, `if`, `for`, `try`…) must
    contain code or a flutter-style `// TODO(handle): …` comment explaining the gap.
    Empty catch clauses are excused. `onError: (_, _) {}` and `(_) {}` listeners are
    violations; either give them work to do (e.g. a tear-off like `events.add`) or add
    a TODO comment.
  - **`newline-before-return`** — separate a block-final `return` from preceding
    statements with one blank line. Inline guards like `if (cond) return;` do not need
    the blank line — the rule is about returns whose preceding sibling is a non-return
    statement in the same block.
  - **`prefer-commenting-analyzer-ignores`** — every `// ignore:` line needs a `//`
    explanation adjacent to it (immediately above, immediately below, or appended after
    the directive). Dartdoc (`///`) above the line does not count — the rule looks for a
    regular `//` comment.

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
