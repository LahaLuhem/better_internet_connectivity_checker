# APPENDIX — `better_internet_connectivity_checker`

Consolidated source of truth for design decisions, rejected paths, and non-obvious
technical trade-offs.

READMEs and `.ai/AGENTS.md` reference sections here by anchor (e.g.
`APPENDIX.md#pure-dart-not-flutter`). **Headings below are load-bearing** — each carries
an explicit `<a id="…">` anchor immediately above it. When renaming a heading, keep the
anchor stable or grep-and-update every caller.

---

<a id="ai-files-symlinked"></a>
## `AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`

- **Decision:** the canonical text for both files lives under `.ai/`. The repo root holds
  symlinks (`AGENTS.md → .ai/AGENTS.md`, `CLAUDE.md → .ai/CLAUDE.md`).
- **Why:** Claude Code (and most other coding agents) auto-discover `CLAUDE.md` /
  `AGENTS.md` at the project root, but two more loose Markdown files at the root add
  visual noise to the file tree. Scoping the agent-guidance files under `.ai/` keeps them
  together; the root symlinks preserve auto-discovery.
- **Cross-platform note:** symlinks survive `git clone` on macOS/Linux. On Windows hosts
  without symlink support enabled, the file may show up as a small text file containing
  the link target. If that ever bites a contributor, the fallback is to drop the symlinks
  and keep real files at root, hand-syncing the content (or to delete the duplicates
  under `.ai/`).

---

<a id="pure-dart-not-flutter"></a>
## Pure-Dart package, no Flutter dependency

- **Chosen:** zero Flutter dependency. `pubspec.yaml` declares only a Dart SDK constraint
  (`sdk: ^3.11.0`); no `flutter:` block.
- **Why:** connectivity checking is fundamentally an HTTP / DNS / TCP problem, none of
  which need platform channels. Keeping the package Flutter-free means it works equally
  on Dart server, CLI, web, and Flutter — not just Flutter apps — and avoids pulling a
  Flutter dep tree into non-Flutter users' transitive closure.
- **If platform channels ever become necessary** (e.g. iOS reachability API integration),
  the right move is a sibling Flutter-plugin package that depends on this one, not adding
  Flutter to this `pubspec.yaml`.
- **`.fvmrc` exists** for local SDK pinning, but FVM is a build-time tool, not a runtime
  dep — it doesn't show up in `pubspec.yaml` and doesn't affect downstream consumers.

---

<a id="public-api-via-single-export-file"></a>
## Public API funnelled through `lib/<package>.dart`

- **Chosen:** `lib/better_internet_connectivity_checker.dart` is the only file callers
  import. Implementation lives in `lib/src/`; nothing in `src/` is intended to be
  imported directly. The entry file consists almost entirely of `export 'src/…' show …;`
  lines.
- **Why:** Dart doesn't have a hard public/private boundary between library files —
  anything under `lib/` is importable. The single-entry + `lib/src/` convention is how
  the ecosystem signals private intent. It also gives one place to audit the public
  surface when planning a release, and one place to control re-exports with `show` /
  `hide`.
- **Implication for refactors:** moving code *within* `lib/src/` is free (private).
  Moving anything *into or out of* the re-export list is a semver-visible change — minor
  for additions, major for removals or signature changes.

---

<a id="three-layer-architecture"></a>
## Three-layer architecture: probe / policy / scheduler

- **Chosen:** the package splits into three independent concerns:
  1. **`ConnectivityProbe`** — runs one check against one `ProbeTarget`, returns one
     `ProbeResult`. The built-in `HttpProbe` (with `.head()` and `.get()` factories) is
     one implementation; others can wrap it (retry decorators) or replace it (DNS / TCP
     / mock).
  2. **`ReachabilityPolicy`** — aggregates per-probe results into an `InternetStatus`.
     Built-ins: `AnyReachablePolicy` (any-of-N), `AllReachablePolicy` (all-of-N). Future
     variants (k-of-N, majority, circuit-breaker) slot in at this layer.
  3. **`InternetConnection`** — owns scheduling (periodic timer + external-trigger
     stream) and the de-duped broadcast status stream. It composes the other two; it
     does not know how a probe runs or how a status is aggregated.
- **Why:** every named future feature falls cleanly into exactly one layer.
  Retry-with-backoff is a probe decorator. DNS probing is an alternative probe. "k-of-N"
  is a new policy. Reusing the scheduler with a different transport touches one
  constructor argument, not a code path. The previous monolithic class folded all three
  into one, which made the combinatorial dispatch (`enableStrictCheck` × `slowThreshold`
  × `customConnectivityCheck`) the wall every new feature would hit first.
- **What this rules out:** putting probe / policy logic directly on `InternetConnection`
  (the v1 mistake), or exposing knobs (`enableStrict`, `slowConnectionConfig`) that the
  type system encodes more cleanly as strategy objects.

---

<a id="sealed-status-not-enum"></a>
## `InternetStatus` is a sealed class, not an enum

- **Chosen:** `sealed class InternetStatus` with two concrete cases — `Reachable` (carries
  `responseTime` and `quality`) and `Unreachable` (carries the list of `failedProbes`).
  Slow-vs-fast is encoded as a `ConnectionQuality` enum on `Reachable`, not as a third
  top-level status.
- **Why:** a `Slow` status is not a peer of `Connected` and `Disconnected`. It is a
  *refinement* of "connected" — you are connected, but the link is slow. Modelling it as
  a top-level enum value (the previous package's choice) loses that structure. With a
  sealed class, callers `switch` exhaustively, and adding a future variant (e.g.
  `Intermittent`) is a compiler-enforced breaking change instead of a runtime gotcha.
- **Data on the status:** carrying `failedProbes` on `Unreachable` and `responseTime` on
  `Reachable` lets callers debug "why am I offline" without re-running probes — without
  needing a separate "snapshot" type. The shape is small enough that adding such a type
  would be premature.
- **Stream de-duplication operates on *kind*, not value-equality.** Two consecutive
  `Reachable(quality: good)` statuses with different `responseTime`s are still "the same
  state" from a user perspective — the stream does not re-emit. Quality flips (good ↔
  slow) and reachability flips do re-emit. Value-equality on the status types is left to
  identity to avoid surprising users with structural list-equality semantics on
  `failedProbes`.

---

<a id="policy-strategy-not-bool-flag"></a>
## Aggregation policy as a strategy interface, not a `bool`

- **Chosen:** `ReachabilityPolicy` is an interface, with `AnyReachablePolicy` and
  `AllReachablePolicy` as the built-in implementations. The slow threshold is a
  per-evaluation argument, not policy state, so policies are `const`-constructible and
  shareable.
- **Why:** the previous package used a `bool enableStrictCheck` to flip between
  "any" and "all". The boolean flag is the cheapest path to two strategies and the worst
  path to three. The next feature on the roadmap (k-of-N, circuit-breaker) doubles the
  matrix again. A strategy interface makes "add a policy" an *additive* change instead of
  a *cross-cutting* one — no existing code touches.
- **Const-constructible by convention:** every built-in policy has a `const`
  constructor and no per-call state. Callers can write `const AnyReachablePolicy()` and
  pass it around freely. Stateful policies (e.g. one that remembers recent failures for a
  circuit breaker) deserve a class with fields, which is why the interface is a class
  and not a function typedef even though it has a single method.

---

<a id="no-response-data-on-result"></a>
## `ProbeResult` deliberately omits protocol-specific response data

- **Chosen:** `ProbeResult` carries only `target`, `isSuccess`, `responseTime`, and
  `error`. No `statusCode`, no `headers`, no protocol-specific response payload. Probes
  that need to surface protocol-specific data (HTTP response codes, DNS authoritative
  server, TCP reset reason, …) do so on the probe's own surface — constructor callbacks,
  captured state, custom getters on the probe instance — not on the shared result.
- **Why:** `ConnectivityProbe` is the abstraction layer; HTTP HEAD is one implementation
  of it. The result type is the contract every probe fulfils. Putting HTTP fields on it
  leaks HTTP semantics into a transport-agnostic surface: a DNS probe has no
  `statusCode`, a TCP probe has no `headers`, every non-HTTP implementation would carry
  permanently-null fields it can't populate. Each new "I need X on the result" request
  for a future probe (DNS records, gRPC trailers, TLS handshake details, …) compounds the
  bloat. Drawing the line at "no response data on the result" stops that growth before
  it starts.
- **What we considered and rejected:** an early iteration of the auto-method-switch demo
  (HEAD → GET on 405 + `Allow`) pushed `statusCode: int?` and `headers: Map<String, String>?`
  onto `ProbeResult.failure`, motivated by a single demo's needs. Reverted because the
  generalisation was driven by n=1 and would have set a precedent every future custom
  probe could lean on. The demo's `MethodAwareProbe` instead exposes an `onAllowHeader`
  constructor callback — that callback is exactly what the pluggable probe seam is for:
  if your probe needs to expose something the shared `ProbeResult` doesn't carry, expose
  it on the probe.
- **Test:** when reviewing a contribution that proposes adding a field to `ProbeResult`,
  ask whether a non-HTTP probe (DNS, TCP, mock) could populate it meaningfully. If the
  field would be `null` for most probe implementations, it belongs on a specific probe,
  not on the shared result.
- **Future-proof escape hatch:** if a real cross-cutting need ever materialises (multiple
  protocols all needing to surface their own structured metadata), the right shape is a
  single `Map<String, Object?> metadata` field — one bounded surface point, not N
  protocol-specific fields. Defer that until the use case is real.

---

<a id="probe-cancellation-via-http-abortable"></a>
## Probe cancellation via `http.Abortable`, not per-call clients

- **Chosen:** `ConnectivityProbe.probe(target, {cancelSignal})` accepts an optional
  `Future<void>?`. When it completes, the probe should abandon I/O and return a failed
  `ProbeResult`. The built-in `HttpProbe` wires this — and its own per-target timeout
  — into a single [`http.AbortableRequest`](https://pub.dev/documentation/http/latest/http/AbortableRequest-class.html)
  via the `abortTrigger` named parameter. `IOClient` calls `HttpClientRequest.abort()` on
  the underlying socket; `BrowserClient` calls `AbortController.abort()`. Either way the
  TCP/TLS connection is released immediately, not after the Future-level timeout drains.
- **Why an optional `Future<void>`** rather than a new `CancellationToken` type: standard
  Dart types compose cleanly. The fan-out in `AnyReachablePolicy` is one `Completer<void>`
  shared across all probes; custom probes that want to honour the signal can race against
  it with `Future.any` or `whenComplete` without depending on a package-specific primitive.
  Probes that cannot abort (DNS lookups already in flight, mocked transports, retry
  decorators) simply ignore the parameter — the contract is best-effort, the policy still
  resolves correctly.
- **Why `http.Abortable` rather than per-call `http.Client` + `Client.close()`:** the
  closure approach was the original plan and would have worked, but it forced a breaking
  change to `HttpProbe`'s constructor — replacing `{http.Client? client}` with a
  factory function so each probe call could mint and close its own client. That sacrifices
  connection pooling on the injected-client path for no gain over the canonical primitive
  `package:http` 1.6.0 already provides. `Abortable` keeps the constructor untouched, the
  injected client live across calls, and matches what every modern HTTP client (including
  the platform `fetch`) does at the wire level.
- **`AnyReachablePolicy` owns the cancellation fan-out, not `InternetConnection`.** A
  single `Completer<void>` lives for the duration of one `evaluate(...)` call: pass its
  future to every probe, complete it on first success or last failure. `AllReachablePolicy`
  passes nothing — every probe must complete by definition, so there is nothing to cancel.
  `InternetConnection` does not need to know about this: it asks the policy for an answer,
  and the policy decides whether and when to release siblings.
- **Implication for the failure path:** `RequestAbortedException` is an `Exception`
  subtype (via `ClientException`), so the existing `on Exception catch (error)` clause in
  `HttpProbe` captures it and the result lands as `ProbeResult.failure(error: …)`.
  Aborted-by-deadline failures now surface as `RequestAbortedException` rather than
  `TimeoutException` — a small but visible behaviour shift for any caller that
  type-discriminates on `ProbeResult.error`.
- **Not in scope today:** wiring `InternetConnection.dispose()` into the same cancellation
  channel. A mid-flight policy run continues to completion when the connection is disposed
  — bounded by the probe timeout, which now aborts cleanly. Worth revisiting if the
  default check interval ever shrinks below the timeout, but additive when it does.

---

<a id="connectivity-hook-not-baked-in"></a>
## Connectivity-change trigger as an injectable hook, not a baked-in dependency

- **Chosen:** `InternetConnection`'s constructor takes an optional
  `externalRecheckTrigger: Stream<void>`. When provided, every event on that stream
  forces an immediate recheck regardless of the periodic timer. The package itself does
  *not* depend on `connectivity_plus`.
- **Why:** `connectivity_plus` is a Flutter plugin and pulls Flutter into the dependency
  graph. This package is pure Dart by design (see
  [`pure-dart-not-flutter`](#pure-dart-not-flutter)); pulling Flutter just to get a
  network-change signal would break that property for every non-Flutter consumer (CLI,
  server, web).
- **What the hook expects:** any `Stream<void>` whose events suggest the OS-reported
  network state changed. Flutter callers wire it as
  `Connectivity().onConnectivityChanged.map((_) {})`. Other consumers can wire battery
  events, foreground/background transitions, or anything else that should trigger an
  early recheck.
- **Future:** a sibling `better_internet_connectivity_checker_flutter` package can
  provide the `connectivity_plus` wiring as a default, depending on this package without
  the inverse coupling. Today, "wire it yourself" is a 1-line snippet in the README.

---

<a id="why-http-head-default-probe"></a>
## Why HTTP HEAD, not DNS / TCP, is the default probe

- **Chosen:** the default `ConnectivityProbe` (`HttpProbe.head()`) issues an HTTP HEAD
  request and accepts HTTP 200 as success.
- **Rejected:** DNS-only or TCP-connect probes, both of which would be cheaper per check.
- **Why:** the package answers "can I actually reach the public internet right now", not
  "is *some* socket-level path alive". DNS resolution succeeds inside captive portals
  (the portal serves its own DNS), inside transparent proxies, and on LAN-only networks —
  none of which let HTTP traffic out. Raw TCP connects catch some of those cases but still
  miss TLS-handshake failures and HTTP-layer interception (captive portals returning a 302
  to a sign-in page on port 443). HTTP HEAD costs one extra round-trip but exercises the
  entire path the user cares about: DNS, TCP, TLS, and an HTTP response.
- **GET ships alongside HEAD as a built-in fallback.** Same class (`HttpProbe`), different
  named constructor (`HttpProbe.get()`). Some reliability endpoints reject HEAD with HTTP
  405; some CDNs strip cache-control headers on HEAD responses; some legacy APIs simply
  misbehave under it. GET is the universal fallback, paid for with one extra response body
  on the wire. The body is drained but not buffered, so the per-call memory cost matches
  HEAD; the wire cost does not. HEAD stays the default because the body cost matters at
  the periodic-check interval the scheduler runs at.
- **Faster probes remain available as custom impls.** Users who explicitly accept the
  trade-off can implement DNS or TCP probes against the `ConnectivityProbe` interface and
  pass them via `InternetConnection(probe: …)`. The seam exists; the default is
  conservative by design.

---

<a id="why-no-perf-preset"></a>
## Why no performance-preset enum or "perf vs. memory" slider

- **Considered:** a `PerformanceProfile.{battery, balanced, aggressive}` enum on the
  constructor, or a numeric "perf vs. memory" slider.
- **Rejected:** both.
- **Why:**
  1. The real trade-offs are *orthogonal*, not linear. Network bandwidth vs. responsiveness
     (`checkInterval`), reliability vs. fan-out cost (`targets`), strictness vs. speed
     (`policy`), transport overhead vs. portability (`probe`), classification-only
     `slowThreshold`. Collapsing four independent axes onto one slider loses information.
  2. The package's dominant cost is the *network* — bandwidth, latency, battery. Memory is
     already near-zero (well under 1 KB per `InternetConnection`, no buffers, no caches).
     There is no real memory-vs-perf axis to slide along.
  3. Presets bake in opinions and age badly in a published API. If users want a
     "battery mode", the right answer is a documented recipe composing existing knobs
     (long interval, single target, any-of-1) — not a new opaque enum whose semantics
     drift across versions.
- **Future-proof escape hatch:** if a real memory-vs-observability axis ever materialises
  (status-history buffer, diagnostic ring buffer), expose it as a *direct* knob
  (`historySize: 50`) — not as part of a coalesced preset.

---

<a id="why-no-checkonce-coalescing"></a>
## Why `checkOnce()` is not single-flighted today

- **Chosen:** each `checkOnce()` call independently runs the full probe fan-out. Two
  simultaneous callers issue two parallel sets of probes.
- **Why:** most apps call `checkOnce()` from a single place — a status provider, a
  service singleton, the periodic timer inside `InternetConnection` itself. The
  duplicate-call case is rare; pre-shipping a single-flight wrapper adds code paths and
  surface area for a non-problem. Callers that *do* hit the case can wrap one
  `Future<InternetStatus>` themselves with a `Completer`.
- **If real-world demand materialises:** the shape is straightforward and non-breaking —
  keep one in-flight `Future` on `InternetConnection`, return it to concurrent callers,
  clear on completion. The API stays identical; the change is transparent.
