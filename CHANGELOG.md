## [Unreleased]
### Changed
- \[#69\] Require Dart 3.14

## [1.1.0] - 2026-08-21
### Changed
- \[#31\] Add `MinimumReachablePolicy`, and stop probes following redirects
- \[#34\] Spread the default probe targets across three operators

### Fixed
- \[#30\] Bound every probe at `ProbeTarget.timeout`, whatever the transport does

## [1.0.0] - 2026-08-20
### Added
- \[#4\] Benchmark suite that snapshots the library's performance between releases
- \[#5\] Sealed `ConnectivityEvent` hierarchy on `InternetConnection.events`, for watching the whole check lifecycle instead of only status changes
- \[#5\] `attachObserver(events, observer)` top-level helper, which wires a `ConnectivityObserver` onto that stream
- Add a debug-mode watchdog that warns when an observer callback blocks the event loop
- \[#24\] Add a `CheckSchedule` seam with exponential backoff (**Breaking:** adds `NextCheckScheduledEvent`)
- \[#25\] Add jitter to `ExponentialBackoffSchedule`, on by default at ±25%

### Changed
- \[#26\] Use the new shared lint repo
- Bump the Dart SDK floor to ^3.12.0
- \[#0\] Bump the SDK floor to ^3.13
- \[#26\] Move existing classes to header-form primary constructors

### Fixed
- post merge fix
- Fix the performance regressions the refactor introduced

### Removed
- \[#5\] **Breaking:** `observer:` constructor parameter on `InternetConnection`, migrate via `attachObserver(connection.events, observer)`

## [0.2.0] - 2026-05-20
### Added
- Better CICD
- `setSlowThreshold`, to move the slow-classification cutoff at runtime
- \[#1\] Add a logging hook, `ConnectivityObserver`

### Changed
- `setCheckInterval` and `setSlowThreshold` became the setters `checkInterval` and `slowThreshold`

## [0.1.0] - 2026-05-18
### Added
- `HttpProbe.get()`, for endpoints that reject HEAD with a 405 or misbehave under it. The body is drained rather than buffered, so a GET costs the same memory per call as a HEAD.
- HttpProbe.get for HTTP GET

### Changed
- **Breaking:** unified the built-in HTTP probe into a single `HttpProbe` class with `HttpProbe.head()` / `HttpProbe.get()` named constructors. It replaces `HttpHeadProbe`, so existing callers update via `HttpHeadProbe()` → `HttpProbe.head()`.
- HttpProbe is split into .head(original) and .get

## [0.0.1] - 2026-05-17
### Added
- `InternetConnection` scheduler with `checkOnce()` and a de-duped broadcast `onStatusChange` stream. Sealed `InternetStatus`, where `Reachable` carries the response time and a `ConnectionQuality` and `Unreachable` carries failed-probe diagnostics. Slow-connection detection is opt-in through `slowThreshold`.
- Pluggable `ConnectivityProbe` interface with default `HttpHeadProbe` (HTTP HEAD, shared `http.Client`, per-target timeout). DNS, TCP, retry-decorator and mock transports drop in via constructor injection.
- Pluggable `ReachabilityPolicy` interface with `AnyReachablePolicy` (default, any-of-N race) and `AllReachablePolicy` (strict, all-of-N). Each judges slowness its own way: the winning probe under any-of-N, the slowest successful probe under all-of-N.
- Sibling-probe cancellation via `http.AbortableRequest`: under any-of-N, in-flight probes abort at the transport layer the moment one succeeds, releasing sockets immediately instead of waiting out the per-target timeout.
- An `externalRecheckTrigger` constructor hook forces an immediate recheck on any `Stream<void>` event (e.g. `connectivity_plus.onConnectivityChanged` on Flutter) without the package itself depending on Flutter.

[Unreleased]: https://github.com/LahaLuhem/better_internet_connectivity_checker/compare/1.1.0...HEAD
[1.1.0]: https://github.com/LahaLuhem/better_internet_connectivity_checker/compare/1.0.0...1.1.0
[1.0.0]: https://github.com/LahaLuhem/better_internet_connectivity_checker/compare/0.2.0...1.0.0
[0.2.0]: https://github.com/LahaLuhem/better_internet_connectivity_checker/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/LahaLuhem/better_internet_connectivity_checker/compare/0.0.1...0.1.0
[0.0.1]: https://github.com/LahaLuhem/better_internet_connectivity_checker/releases/tag/0.0.1
