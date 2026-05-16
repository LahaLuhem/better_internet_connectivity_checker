<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [What it does](#what-it-does)
- [Getting started](#getting-started)
- [Usage](#usage)
    * [One-shot check](#one-shot-check)
    * [Pattern-matching the sealed status](#pattern-matching-the-sealed-status)
    * [Listening to status changes](#listening-to-status-changes)
    * [Slow-connection detection](#slow-connection-detection)
    * [Custom probe targets](#custom-probe-targets)
    * [Strict aggregation (every probe must succeed)](#strict-aggregation-every-probe-must-succeed)
    * [Injecting a custom `http.Client`](#injecting-a-custom-httpclient)
    * [Writing a custom `ConnectivityProbe`](#writing-a-custom-connectivityprobe)
    * [Wiring `connectivity_plus` (Flutter)](#wiring-connectivity_plus-flutter)
- [Testing](#testing)
- [Releasing](#releasing)
- [Contributing](#contributing)
    * [Optional: AI-agent discovery symlinks](#optional-ai-agent-discovery-symlinks)

<!-- TOC end -->

`better_internet_connectivity_checker` is a pure-Dart package for **robust
internet-connectivity checking**. The goal is to answer "can I actually reach the public
internet right now?" — distinct from "is a network interface up?", which is what most
OS-level checks report.

## What it does

- Probes one or more URIs to determine *actual* internet reachability — not just "an
  interface is up".
- Distinguishes **Reachable** / **Unreachable** with an optional **good** / **slow**
  quality classification when a response-time threshold is configured.
- Streams status transitions on a broadcast stream, de-duped so the same status kind is
  not re-emitted on every periodic tick.
- Ships a default HTTP-HEAD probe; the probe layer is pluggable, so retry decorators,
  alternative transports, or test stubs slot in without touching the rest of the package.
- Ships **any-of-N** (default) and **all-of-N** (strict) aggregation policies; the policy
  layer is also pluggable.
- Exposes an `externalRecheckTrigger` hook so callers can plug in OS-level network-change
  signals (`connectivity_plus` on Flutter is the canonical wiring) without the package
  itself taking a Flutter dependency.
- Pure Dart — works on CLI, server, web, and Flutter with no platform channels.

## Getting started

Add the package to `pubspec.yaml`:

```yaml
dependencies:
  better_internet_connectivity_checker: ^0.0.0
```

Then run:

```bash
dart pub get
```

This package is **pure Dart** and does not depend on Flutter. It works in any Dart 3.11+
project — CLI, server-side, web, and Flutter alike.

## Usage

### One-shot check

```dart
import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';

Future<void> main() async {
  final checker = InternetConnection();
  final status = await checker.checkOnce();
  print(status is Reachable ? 'online' : 'offline');
  await checker.dispose();
}
```

### Pattern-matching the sealed status

`InternetStatus` is a sealed class. Exhaustive `switch` is the recommended way to consume
it — the compiler will tell you if a future variant is added.

```dart
switch (await checker.checkOnce()) {
  case Reachable(:final responseTime, :final quality):
    print('online — $quality, ${responseTime.inMilliseconds} ms');
  case Unreachable(:final failedProbes):
    print('offline — ${failedProbes.length} probes failed');
}
```

### Listening to status changes

```dart
final checker = InternetConnection();
final subscription = checker.onStatusChange.listen((status) {
  // Same status kind is not re-emitted, so this fires only on real transitions.
});

// later:
await subscription.cancel();
await checker.dispose();
```

### Slow-connection detection

Pass a `slowThreshold` to classify the `quality` field on every `Reachable` status:

```dart
final checker = InternetConnection(
  slowThreshold: const Duration(milliseconds: 500),
);
```

### Custom probe targets

Override the default reliability endpoints, e.g. to probe your own healthchecks:

```dart
final checker = InternetConnection(
  targets: [
    ProbeTarget(uri: Uri.parse('https://my-api.example.com/health')),
    ProbeTarget(
      uri: Uri.parse('https://other.example.com/ping'),
      isSuccess: (response) => response.statusCode == 204,
    ),
  ],
);
```

### Strict aggregation (every probe must succeed)

```dart
final checker = InternetConnection(
  policy: const AllReachablePolicy(),
);
```

Recommended only with a curated probe list — any one public endpoint being down would
flag a working connection as unreachable under the default endpoint set.

### Injecting a custom `http.Client`

For proxies, middleware, or a `MockClient` in tests:

```dart
import 'package:http/http.dart' as http;

final checker = InternetConnection(
  probe: HttpHeadProbe(client: myHttpClient),
);
```

### Writing a custom `ConnectivityProbe`

For probes that go beyond HTTP HEAD — DNS, TCP, a private API, or a decorator wrapping
another probe — implement `ConnectivityProbe.probe(target, {cancelSignal})`. Honour the
optional `cancelSignal` whenever your transport supports cancellation: under
`AnyReachablePolicy` it fires the moment a sibling probe succeeds, so the in-flight
request can release its socket at the transport layer instead of waiting out the
per-target timeout. The built-in `HttpHeadProbe` honours it via `http.AbortableRequest`;
probes that cannot abort simply ignore the parameter and the policy still resolves
correctly.

See [`example/lib/features/custom_targets/method_aware_probe.dart`](example/lib/features/custom_targets/method_aware_probe.dart)
for the canonical pattern — dispatching HEAD or GET per-target, surfacing protocol-specific
response data on the probe itself, and honouring `cancelSignal` alongside the per-target
deadline through a single abort trigger.

### Wiring `connectivity_plus` (Flutter)

The package does not depend on `connectivity_plus` — it accepts any `Stream<void>` as an
external trigger. Flutter apps can wire it up themselves:

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

final checker = InternetConnection(
    externalRecheckTrigger:
    Connectivity().onConnectivityChanged.map(noopWithVal),
);
```

A runnable example will live in `example/` once the example app is added.

## Testing

```bash
fvm dart test                                            # full test suite
fvm dart analyze                                         # strict-mode static analysis
fvm dart format --output=none --set-exit-if-changed .    # formatter check
```

The Dart/Flutter SDK version is pinned via [FVM](https://fvm.app/); see `.fvmrc`. Run
`fvm install` once before the first build.

## Releasing

Version bumps and CHANGELOG entries are owned by an automated release pipeline (TBA).
**Do not edit `CHANGELOG.md` or the `version:` field in `pubspec.yaml` by hand** — the
pipeline reorders and overwrites manual edits. The `cider:` block in `pubspec.yaml` and
the `link_template` it carries are pipeline configuration.

Released tags will follow `v<MAJOR>.<MINOR>.<PATCH>` and link to GitHub releases via the
`link_template` block.

## Contributing

Issues and PRs welcome at
<https://github.com/LahaLuhem/better_internet_connectivity_checker>. Before sending a
non-trivial change, read [`CODESTYLE.md`](./CODESTYLE.md) for the house style,
[`.ai/AGENTS.md`](./.ai/AGENTS.md) for the hard rules and contributor / AI-agent
guidelines, and [`APPENDIX.md`](./APPENDIX.md) for the design rationale.

### Optional: AI-agent discovery symlinks

The canonical text for `AGENTS.md` and `CLAUDE.md` lives under `.ai/`. The repo root
holds **gitignored symlinks** (`AGENTS.md → .ai/AGENTS.md`,
`CLAUDE.md → .ai/CLAUDE.md`, `example/AGENTS.md → example/.ai/AGENTS.md`) so coding
agents that auto-discover root-level guidance files (Claude Code, Codex, Cursor,
Copilot, …) find them without polluting the file tree with two extra Markdown files at
each level. The arrangement is opt-in per contributor:

- **If you use a coding agent**, set the symlinks up once from the repo root:

  ```bash
  ln -s .ai/AGENTS.md AGENTS.md
  ln -s .ai/CLAUDE.md CLAUDE.md
  ln -s .ai/AGENTS.md example/AGENTS.md
  ```

- **If you don't use one**, skip the step entirely. The canonical files under `.ai/`
  are committed; nothing in the build, lint, or test pipeline depends on the symlinks
  existing.
- **If you want different agent guidance for your own workflow**, drop a real
  `AGENTS.md` or `CLAUDE.md` at the repo root. A real file beats the symlink
  convention — your agent reads the root file you put there instead of the canonical
  one under `.ai/`. The committed `.ai/` copies remain the project default for
  everyone else.

The `CODESTYLE.md` files are not symlinked — they sit directly at the repo root and at
`example/`, since style serves humans and agents alike and is not AI-specific. See
[`APPENDIX.md#ai-files-symlinked`](./APPENDIX.md#ai-files-symlinked) for the rationale
behind the `.ai/` arrangement.
