[![Pub Version](https://img.shields.io/pub/v/better_internet_connectivity_checker.svg)](https://pub.dev/packages/better_internet_connectivity_checker)
[![Pub Points](https://img.shields.io/pub/points/better_internet_connectivity_checker?logo=dart)](https://pub.dev/packages/better_internet_connectivity_checker/score)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](./LICENSE)

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [What it does](#what-it-does)
- [Getting started](#getting-started)
- [Platform setup](#platform-setup)
    * [Android](#android)
    * [iOS and macOS](#ios-and-macos)
    * [Web](#web)
- [Usage](#usage)
    * [One-shot check](#one-shot-check)
    * [Pattern-matching the sealed status](#pattern-matching-the-sealed-status)
    * [Listening to status changes](#listening-to-status-changes)
    * [Slow-connection detection](#slow-connection-detection)
    * [Custom probe targets](#custom-probe-targets)
    * [Strict aggregation (every probe must succeed)](#strict-aggregation-every-probe-must-succeed)
    * [Injecting a custom `http.Client`](#injecting-a-custom-httpclient)
    * [Falling back to GET](#falling-back-to-get)
    * [Writing a custom `ConnectivityProbe`](#writing-a-custom-connectivityprobe)
    * [Wiring `connectivity_plus` (Flutter)](#wiring-connectivity_plus-flutter)
- [When to reach for this](#when-to-reach-for-this)
- [Performance & memory](#performance--memory)
- [Caveats](#caveats)
- [Roadmap](#roadmap)
- [Testing](#testing)
- [Contributing](#contributing)
    * [Optional: AI-agent discovery symlinks](#optional-ai-agent-discovery-symlinks)

<!-- TOC end -->

`better_internet_connectivity_checker` is a pure-Dart package for **robust
internet-connectivity checking** and **actual internet reachability** detection. The goal
is to answer "can I actually reach the public internet right now?" — distinct from "is a
network interface up?", which is what most OS-reported connectivity signals (and most
existing Dart / Flutter checkers) ultimately rely on. Bridges the gap where DNS resolves
and the OS reports connected, but HTTP traffic is silently dropped — captive portals,
transparent proxies, broken middleboxes, and LAN-only networks.

## What it does

- Probes one or more URIs to determine *actual* internet reachability — not just "an
  interface is up". Catches the "DNS works but no internet" / "OS says connected but
  every request times out" failure modes that interface-level checks miss.
- Distinguishes **Reachable** / **Unreachable** with an optional **good** / **slow**
  quality classification — slow-connection detection via a single response-time
  threshold, no extra plumbing.
- Streams status transitions on a broadcast stream, de-duped so the same status kind is
  not re-emitted on every periodic tick.
- Ships a default HTTP-HEAD probe with a GET fallback (`HttpProbe.head()` /
  `HttpProbe.get()`) for endpoints that reject HEAD; the probe layer is pluggable, so
  retry decorators, alternative transports, or test stubs slot in without touching the
  rest of the package.
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

This package is **pure Dart** and does not depend on Flutter. It works in any Dart 3.10+
project — CLI, server-side, web, and Flutter alike.

## Platform setup

The package is pure Dart, but the underlying OS still gates outbound network access. The
defaults probe over HTTPS only; HTTP-only probes you wire in have extra caveats on iOS
and macOS.

Pure-Dart CLI and server-side targets need no setup. Flutter targets do:

### Android

Add `android.permission.INTERNET` to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <!-- ... -->
</manifest>
```

Flutter scaffolds this permission into the **debug** and **profile** manifest variants
(so the tooling can attach for hot reload) but **not** into `main` — the only variant
included in release builds. Without the declaration above, every probe fails immediately
with `_ClientSocketException` in single-digit milliseconds — the OS is denying the
socket, not a real timeout — so `flutter run --release` reports unreachable while
`flutter run` works.

### iOS and macOS

HTTPS probes work out of the box. HTTP-only probes need an App Transport Security
exception in `ios/Runner/Info.plist` (and the macOS equivalent). Sandboxed macOS apps
additionally need the `com.apple.security.network.client` entitlement in
`macos/Runner/*.entitlements`.

### Web

Probe targets must serve `Access-Control-Allow-Origin` matching your app's origin — see
[Caveats](#caveats).

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
    probe: HttpProbe.head(client: myHttpClient),
);
```

### Falling back to GET

Some endpoints reject HEAD (HTTP 405) or strip caching headers on it. Swap to
`HttpProbe.get()` per-instance:

```dart
final checker = InternetConnection(
    probe: HttpProbe.get(),
);
```

The GET probe drains the response body from the wire but does not buffer it into
memory, so a verbose endpoint does not bloat the probe's footprint. Any custom
`isSuccess` predicate sees an empty `response.body` regardless of what the server
returned — inspect `statusCode` and `headers` instead.

### Writing a custom `ConnectivityProbe`

For probes that go beyond HTTP — DNS, TCP, a private API, or a decorator wrapping
another probe — implement `ConnectivityProbe.probe(target, {cancelSignal})`. Honour the
optional `cancelSignal` whenever your transport supports cancellation: under
`AnyReachablePolicy` it fires the moment a sibling probe succeeds, so the in-flight
request can release its socket at the transport layer instead of waiting out the
per-target timeout. The built-in `HttpProbe` honours it via `http.AbortableRequest`;
probes that cannot abort simply ignore the parameter and the policy still resolves
correctly.

See [`example/lib/features/custom_targets/method_aware_probe.dart`](example/lib/features/custom_targets/method_aware_probe.dart)
for the canonical pattern: when your probe needs to surface protocol-specific response
data (the HTTP `Allow` header on 405 responses, in this demo) that `ProbeResult`
intentionally omits, expose it on the probe itself via a constructor callback. The
example wires the built-in `HttpProbe.head()` / `HttpProbe.get()` as the main probe and
falls back to `MethodAwareProbe` only on the failure-inspection path.

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

Runnable examples live in [`example/`](./example/) — a Flutter demo app exercising
one-shot checks, status streaming, both aggregation policies, slow-connection detection,
and a custom probe.

## When to reach for this

The Dart / Flutter ecosystem already has reachability and connectivity packages. They
each answer a slightly different question — and the right pick depends on the question
*you* are trying to answer.

**Reach for this package when** your problem looks like one of these:

- The OS reports a Wi-Fi or cellular connection, but the app times out on every request.
- A captive portal (hotel, airport, conference Wi-Fi) is intercepting traffic, and your
  app needs to know it's not really online.
- You need to distinguish "slow but reachable" from "offline" — for a slow-connection
  UI banner, a quality-aware retry policy, or analytics on degraded connections.
- You need diagnostic output on a failed check — *which* probe failed, *what* error,
  *how long* it took — not a bare `false`.
- You're on a non-Flutter Dart target (CLI, server, web) and need internet-reachability
  detection without a Flutter plugin in the dep tree.

**Compared to the other established choices:**

- [`connectivity_plus`](https://pub.dev/packages/connectivity_plus) answers a *different*
  question: "what network type is the OS on (Wi-Fi / cellular / none)?". It does not
  probe actual reachability — a captive portal will register as a healthy Wi-Fi
  connection. The two packages are complementary: wire `connectivity_plus` as this
  package's `externalRecheckTrigger` to get instant rechecks on OS network-state flips
  (canonical wiring in [Usage](#wiring-connectivity_plus-flutter)).
- [`internet_connection_checker`](https://pub.dev/packages/internet_connection_checker)
  and
  [`internet_connection_checker_plus`](https://pub.dev/packages/internet_connection_checker_plus)
  answer the *same* question this package does. They're battle-tested and a fine default
  if you don't need slow-connection classification (missing from the `_plus` fork — see
  [issue #71](https://github.com/OutdatedGuy/internet_connection_checker_plus/issues/71)),
  pluggable aggregation policies, or per-probe failure diagnostics. This package layers
  a probe / policy / scheduler architecture under the same headline feature set —
  worth the extra surface area if you need the seams; overkill if you don't.

**Don't reach for this if** you only need "what network type am I on?" — use
`connectivity_plus` directly and skip the per-check probe cost.

What the default configuration buys you, with no further configuration:

- **Race-and-cancel probes** — `AnyReachablePolicy` returns on the first success and
  aborts in-flight siblings at the transport layer (sockets release immediately, not at
  timeout-drain). See
  [`APPENDIX.md`](./APPENDIX.md#probe-cancellation-via-http-abortable).
- **Shared `http.Client`** — connection pooling and TLS-session reuse across periodic
  ticks, instead of a fresh socket per probe.
- **HTTP HEAD, not GET** — no response body on the wire. See
  [`APPENDIX.md`](./APPENDIX.md#why-http-head-default-probe)
  for why HEAD over a cheaper DNS / TCP probe.
- **Listener-gated periodic timer** — auto-suspends when nothing is listening to
  `onStatusChange`, auto-resumes on first re-subscription. No CPU or network spend while
  the stream has no consumers.
- **Status-kind de-duping** — two consecutive `Reachable(quality: good)` events do not
  re-emit, so downstream `setState` / listener rebuilds fire only on real transitions.
  Quality flips and reachability flips do re-emit.
- **`const` defaults and `ConstUri` lazy parsing** — the default target list and its URIs
  are compile-time constants shared process-wide; constructing
  `InternetConnection()` with no `targets` argument allocates nothing for the target
  list.
- **Growth-bounded result lists** — `failedProbes` uses `growable: false`; no status
  history buffer, rolling window, or per-probe cache is kept anywhere.

Memory footprint per `InternetConnection` is well under 1 KB at steady state.

## Caveats

Deliberate non-features that may affect how you use the package:

- **Concurrent `checkOnce()` calls are not coalesced.** Each spins a full probe fan-out;
  there is no built-in single-flight. If your app issues many simultaneous reachability
  checks, wrap your own debouncer or share one `Future`. Rationale in
  [`APPENDIX.md`](./APPENDIX.md#why-no-checkonce-coalescing).
- **`Unreachable.failedProbes` retains caught `Exception` objects** on each
  `ProbeResult.error`. If those exceptions chain heavy transport state (TLS context,
  request bodies, custom error payloads), an `Unreachable` reference can keep that memory
  alive. Drop the reference — or extract only what you need from it — once you're done.
- **HTTP caching on probe endpoints will mask outages.** Use endpoints that respond with
  `Cache-Control: no-cache` — the defaults do. On the web platform, probe targets must
  also allow CORS for the request to reach the probe.
- **`AllReachablePolicy` is brittle with arbitrary public endpoints** — any one being
  briefly unavailable flags a working connection as offline. Use it only with a curated
  probe list (e.g. enterprise internal endpoints); see the policy's dartdoc.

## Roadmap

Features deferred today but inside the design envelope (no API break required to add):

- **Single-flight `checkOnce()` coalescing** — share one in-flight `Future` across
  concurrent callers. Will land if real-world demand surfaces. See
  [`APPENDIX.md`](./APPENDIX.md#why-no-checkonce-coalescing).
- **Optional status-history buffer for diagnostics** — a rolling window of recent
  transitions, opt-in with a buffer-size knob. This is the one genuine
  memory-vs-observability trade-off in the package; until it lands, the package keeps
  no history.
- **DNS / TCP probes as custom `ConnectivityProbe` implementations** — faster but lose
  captive-portal / TLS / transparent-proxy detection. Out of scope as defaults; valid as
  user-supplied custom probes against the existing `ConnectivityProbe` seam. See
  [`APPENDIX.md`](./APPENDIX.md#why-http-head-default-probe).

Not on the roadmap (deliberate non-features):

- **No performance-preset enum or perf-vs-memory slider.** The orthogonal knobs
  (`checkInterval`, `targets`, `policy`, `probe`) already control the real trade-offs;
  collapsing them onto one slider loses information. Rationale in
  [`APPENDIX.md`](./APPENDIX.md#why-no-perf-preset).

## Testing

```bash
dart test                                            # full test suite
dart analyze                                         # strict-mode static analysis
dart format --output=none --set-exit-if-changed .    # formatter check
```

Dart 3.10+ required (see `pubspec.yaml`).

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
[`APPENDIX.md`](./APPENDIX.md#ai-files-symlinked) for the rationale
behind the `.ai/` arrangement.
