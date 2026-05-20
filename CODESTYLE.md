Library-package code style. Project facts (goal, stack, repo layout, hard rules) live in [`.ai/AGENTS.md`](./.ai/AGENTS.md);
design rationale lives in [`APPENDIX.md`](./APPENDIX.md);
example-app code style lives in [`example/CODESTYLE.md`](./example/CODESTYLE.md).

The lint posture is deliberately strict
(see [`analysis_options.yaml`](./analysis_options.yaml)). The house style values
explicit types, no ambient mutability, and small focused classes.

Each heading below carries an explicit `<a id="…">` anchor. Link by anchor, not by
heading text, so renames don't break callers.

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [Type safety & nullability](#type-safety-nullability)
- [Naming](#naming)
- [Formatting](#formatting)
- [Constants & magic numbers](#constants-magic-numbers)
- [Class structure](#class-structure)
- [Idioms](#idioms)
    * [Static dot shorthands (Dart 3.10+)](#static-dot-shorthands-dart-310)
    * [Collection-for / collection-if over `Iterable.map(…).toList()`](#collection-for-collection-if-over-iterablemaptolist)
    * [`dart:async` `wait` extensions over static `Future.wait(...)`](#dartasync-wait-extensions-over-static-futurewait)
    * [`Uri.https(…)` / `Uri.http(…)` over `Uri.parse(…)`](#urihttps-urihttp-over-uriparse)
    * [`List.unmodifiable(…)` over `UnmodifiableListView(…)`](#listunmodifiable-over-unmodifiablelistview)
    * [`part` / `part of` only when structurally needed](#part-part-of-only-when-structurally-needed)
- [Comments & dartdoc](#comments-dartdoc)
- [DCM rules (applied by hand)](#dcm-rules-applied-by-hand)
- [Documentation conventions (Markdown)](#documentation-conventions-markdown)

<!-- TOC end -->

<a id="type-safety"></a>
<!-- TOC --><a name="type-safety-nullability"></a>
## Type safety & nullability

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
- **No Java ceremony.** No getter-only abstract base classes, no `AbstractFooFactory`,
  no interface-per-class. Use mixins / sealed classes / records / extension types
  where they add clarity, not weight.

The `dynamic`-escape-hatch ban and the `print()`-in-library ban are listed under
[*Hard rules* in `.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules) — they're contracts, not
style.

---

<a id="naming"></a>
<!-- TOC --><a name="naming"></a>
## Naming

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

---

<a id="formatting"></a>
<!-- TOC --><a name="formatting"></a>
## Formatting

- **Wrap text-file content at 100 columns.** [`.editorconfig`](./.editorconfig) is
  authoritative; Markdown / Dart / YAML all share the same cap.
- **Blank lines separate logical chunks within a method.** Group guard checks, setup,
  the main action, and finalisation with one blank line between groups. Lets readers
  scan past chunks they don't need without re-parsing them line-by-line.
- **Prefer expression bodies** (`prefer_expression_function_bodies`) and **single
  quotes** (`prefer_single_quotes`).

---

<a id="constants"></a>
<!-- TOC --><a name="constants-magic-numbers"></a>
## Constants & magic numbers

- **No magic numbers in `lib/` code.** Pull constants to named `static const`s with a
  descriptive identifier.
- Cross-cutting defaults (timeouts, intervals, header maps, the curated probe-target
  list) belong on `abstract final class Values` in
  [`lib/src/data/values.dart`](./lib/src/data/values.dart). Before introducing a new
  constant in a feature class, check whether it belongs on `Values` instead — see
  [hard rule 1 in `.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules).

---

<a id="class-structure"></a>
<!-- TOC --><a name="class-structure"></a>
## Class structure

- **Any class with fields and constructors: fields → constructors → other members.**
  Lets a reader scan the state shape first, then how to construct it, then how to use
  it. Within constructors, unnamed first, then factories (matches
  `sort_unnamed_constructors_first`). Static helpers go after the methods. Applies to
  value types (`ProbeTarget`, `Reachable`, …), service classes (`InternetConnection`,
  `HttpProbe`), test helpers (`StubProbe`) — wherever a class has both state and a
  constructor. Pure-static namespace classes (`Values`) and field-less interface
  classes (`ConnectivityProbe`, `ReachabilityPolicy`) have nothing to order; the rule
  applies vacuously.
- **`assert` for dev-time errors, `throw` for runtime ones.** Constraints a caller can
  see violated during development (negative number where non-negative is required,
  empty list where non-empty is expected, etc.) belong in `assert` — stripped in
  release mode, zero runtime cost. Reserve `throw` and `Exception` for genuine runtime
  conditions the caller cannot guarantee at compile/dev time (network failure, parsing
  untrusted input, missing file, third-party API contract violations). Prefer
  init-list asserts — `prefer_asserts_in_initializer_lists` and
  `prefer_asserts_with_message` are both on.
- **Value types override `toString`.** Immutable data classes (`ProbeTarget`,
  `ProbeResult`, `Reachable`, `Unreachable`, …) implement `toString()` returning
  `'ClassName(field1: value1, field2: value2)'`. The default
  `Instance of 'ClassName'` is hostile in logs, exception traces, and `print`
  debugging — readers should not have to attach a debugger to recover field values.
  Include every field with a meaningful string representation; expression-bodied
  one-liner placed after the constructors, before any static helpers. Opaque fields
  (function/callback typedefs, controllers, subscriptions — anything whose
  `.toString()` is just `Closure: …` or `Instance of …`) are omitted: they add noise
  without informing the reader, and bare interpolation of a callable trips DCM's
  `avoid-missed-calls`. Service classes (`InternetConnection`, `HttpProbe`) and
  field-less interfaces (`ConnectivityProbe`) are exempt — they have no
  caller-meaningful state to print.

---

<a id="idioms"></a>
<!-- TOC --><a name="idioms"></a>
## Idioms

<a id="idioms-dot-shorthands"></a>
<!-- TOC --><a name="static-dot-shorthands-dart-310"></a>
### Static dot shorthands (Dart 3.10+)

Use static dot shorthands wherever the context type is known. They resolve from the
parameter / return / variable type, not from inference of arbitrary expressions. Drop
the leading type name in *all* of these positions, not just the obvious enum case:

- Enum values in patterns and arg slots:
  `Reachable(quality: cond ? .slow : .good)`, `case .head =>`.
- Named constructors when the return / context type pins it:
  inside `Future<ProbeResult> probe(…)`, write `return .success(target: …, …)` rather
  than `return ProbeResult.success(…)`.
- Const factories on widget parameter types — `padding: const .all(12)`,
  `margin: .zero`, `padding: const .symmetric(horizontal: 12, vertical: 4)`. Works on
  `EdgeInsetsGeometry`-typed params because the static factory delegates through.
- Flex alignment / sizing slots — `crossAxisAlignment: .start`, `mainAxisSize: .min`,
  `mainAxisAlignment: .center`.

Skip when it hurts readability — `.new(…)` for unnamed constructors typically does;
cases where the surrounding context type isn't obvious without re-reading.

After dropping a fully-qualified prefix, the type name often disappears from the file
entirely — remove it from any `show` clauses too. Re-running analyze surfaces
`unused_shown_name` warnings for orphaned ones.

<a id="idioms-collection-literals"></a>
<!-- TOC --><a name="collection-for-collection-if-over-iterablemaptolist"></a>
### Collection-for / collection-if over `Iterable.map(…).toList()`

In widget trees especially, a literal list with embedded control flow reads as data;
a `.map(…).toList()` reads as a pipeline that incidentally produces data. The literal
form also doesn't bloat the file with `<T>` annotations the list-literal context
already infers:

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

<a id="idioms-wait-extensions"></a>
<!-- TOC --><a name="dartasync-wait-extensions-over-static-futurewait"></a>
### `dart:async` `wait` extensions over static `Future.wait(...)`

The extensions (`Iterable<Future<T>>.wait` and the record forms `FutureRecord2`…
`FutureRecord9`) live in `dart:async`'s `future_extensions.dart` and supersede the
static call for everyday use.

- **Fixed number of differently-typed futures → record form.** `(f1, f2).wait`
  returns `Future<(T1, T2)>` and destructures directly. Never await a list literal and
  index into the result by `.first` / `[1]` / etc. — that collapses element types to
  the common supertype and isn't type-checked against slot order, so a swap reads as
  valid until runtime.
- **Dynamic number of same-typed futures → iterable form.** `iterable.wait` returns
  `Future<List<T>>` just like `Future.wait(iterable)`, but errors surface as
  `ParallelWaitError` carrying both per-slot values and per-slot errors — which lets
  callers dispose successful results when a sibling future fails.

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

<a id="idioms-uri-construction"></a>
<!-- TOC --><a name="urihttps-urihttp-over-uriparse"></a>
### `Uri.https(…)` / `Uri.http(…)` over `Uri.parse(…)`

For compile-time-known URLs, use the named constructor and pass path / query
parameters as separate arguments — not mashed into the authority. The named
constructor's shape is `(authority, [unencodedPath, queryParameters])`. Component-wise
construction makes the host, path, and query visible at a glance and short-circuits
the kinds of typo `Uri.parse` silently accepts (missing `://`, stray slashes,
unencoded query chars). `Uri.parse` is still the right tool for runtime input
(user-supplied URLs, response payloads).

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
([`lib/src/data/models/const_uri.dart`](./lib/src/data/models/const_uri.dart)) is
permitted when it unlocks `const` for an enclosing value type — e.g. the
`static const Values.defaultProbeTargets` list, where `const` canonicalisation drops
the `List.unmodifiable` wrapper and shares one parsed `Uri` across identical literals.
`ConstUri` still pays parse cost (lazily, on first access) and is fundamentally a
deferred `Uri.parse` — the trade-off only pays off when the enclosing type is
*already* `const`-constructible. Stay structural in `test/` / `example/` (no `const`
payoff to justify the indirection) and never in public-API code (anything re-exported
from `lib/<package>.dart`).

<a id="idioms-unmodifiable-collections"></a>
<!-- TOC --><a name="listunmodifiable-over-unmodifiablelistview"></a>
### `List.unmodifiable(…)` over `UnmodifiableListView(…)`

Default to `List.unmodifiable(…)` for exposing immutable collections (same for
`Set.unmodifiable` / `Map.unmodifiable` vs their `…View` counterparts in
`dart:collection`). The constructor *copies*: snapshot semantics, decoupled from
whatever the caller passed in. The `…View` only *wraps*: anyone who still holds the
underlying collection can mutate it, and the view silently follows. That footgun
outweighs the saved copy in almost every case.

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

<a id="idioms-parts"></a>
<!-- TOC --><a name="part-part-of-only-when-structurally-needed"></a>
### `part` / `part of` only when structurally needed

Not a smell on its own. Legitimate uses: sealed-class cases across files (Dart 3
requires same library for sealed subtypes — see `lib/src/status/outcomes/`),
code-generation outputs (`*.g.dart` from freezed, json_serializable, drift, etc.).
Avoid for general code organisation — imports/exports are explicit, parts hide
dependencies and leak `_private` symbols across files within the library.

---

<a id="dartdoc"></a>
<!-- TOC --><a name="comments-dartdoc"></a>
## Comments & dartdoc

Public symbols carry `///` dartdoc that explains *why*, not *what* — types already
carry the *what*. `public_member_api_docs` is enabled; see
[hard rule 4 in `.ai/AGENTS.md`](./.ai/AGENTS.md#hard-rules) for the contract.

### `@docImport` for dartdoc-only references

When a file needs a symbol *only* for `[Name]` references in dartdoc (not in code), do
**not** add a regular `import` — that pulls the dependency into the runtime import graph
and hides intent. Use Dart's dartdoc-only directive instead:

```dart
/// @docImport '../internet_connection.dart';
library;

import '../status/internet_status.dart'; // Real code import — InternetStatus is used.
```

**Why.** A regular `import` declares a runtime dependency. If the only reason is
`comment_references` resolution, the runtime graph lies — readers and tooling can't tell
the import is documentation-only, and dead-code elimination has nothing to lean on.
`@docImport` keeps `comment_references` satisfied without polluting the real import set.

**How to apply.** Put the `@docImport` directive(s) as `///` comments directly above the
file's `library;` directive. Code imports stay where they are (regular `import` lines).
The `library;` directive is required for `@docImport` to attach to anything — but
`unnecessary_library_directive` does not fire when a docImport is present.

---

<a id="dcm-rules"></a>
<!-- TOC --><a name="dcm-rules-applied-by-hand"></a>
## DCM rules (applied by hand)

`dart analyze` does not run them, but the project treats them as non-negotiable:

- **`no-empty-block`** — every block (function literal, `if`, `for`, `try`…) must
  contain code or a flutter-style `// TODO(handle): …` comment explaining the gap.
  Empty catch clauses are excused. `onError: (_, _) {}` and `(_) {}` listeners are
  violations; either give them work to do (e.g. a tear-off like `events.add`) or add a
  TODO comment.
- **`newline-before-return`** — separate a block-final `return` from preceding
  statements with one blank line. Inline guards like `if (cond) return;` do not need
  the blank line — the rule is about returns whose preceding sibling is a non-return
  statement in the same block.
- **`prefer-commenting-analyzer-ignores`** — every `// ignore:` line needs a `//`
  explanation adjacent to it (immediately above, immediately below, or appended after
  the directive). Dartdoc (`///`) above the line does not count — the rule looks for a
  regular `//` comment.

---

<a id="documentation-conventions"></a>
<!-- TOC --><a name="documentation-conventions-markdown"></a>
## Documentation conventions (Markdown)

- **APPENDIX.md is the source of truth for rationale.** Hard rules, pitfalls, and
  workflow stay in `.ai/AGENTS.md` and `.ai/CLAUDE.md`; the "why we do it this way"
  essays live in [`APPENDIX.md`](./APPENDIX.md).
- **Explicit `<a id="…">` anchors** sit above every APPENDIX (and CODESTYLE) heading.
  Link to sections via the anchor, not the heading text.
- **Anchor stability is load-bearing.** When renaming a heading, keep the existing
  anchor. If you must change it, `rg '#<old-anchor>'` across the repo and update every
  caller in the same change.
- **Bare `dart` / `flutter` in command examples, never `fvm dart` / `fvm flutter`.** FVM
  is a local implementation detail — `.fvmrc` pins the SDK version. Docs (this file,
  README.md, AGENTS.md, CLAUDE.md, APPENDIX.md) stay tool-agnostic so external
  contributors aren't forced into FVM. The maintainer's shell aliases `dart` to the
  pinned toolchain for interactive use; scripts under `scripts/` prepend
  `.fvm/flutter_sdk/bin` to `PATH` if the symlink exists (so FVM users get the project
  pin) and fall back to whatever `dart` is on `PATH` otherwise — non-FVM contributors
  can run the scripts unchanged.

## Shell scripts

- **`shellcheck` is the lint contract** for `scripts/*.sh`, mirroring `dart analyze` for
  Dart. Run via `shellcheck scripts/*.sh`; `scripts/release.sh` preflight enforces it.
  Install with `brew install shellcheck`.
- **Prefer `# shellcheck disable=SC<code>` + a one-line "why" comment over refactoring
  for simple cases.** Refactor when the warning points at a real bug or when the rewrite
  is genuinely clearer; reach for the directive when the code is correct as-is and
  ShellCheck's analysis is just over-conservative (e.g. SC2154 inside a quoted trap
  body, where ShellCheck can't follow assignment-then-use within the same string).
  Always pair the directive with a comment so the next reader knows it's intentional,
  not a TODO.
