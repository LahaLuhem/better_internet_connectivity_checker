## [Unreleased]
### Added
- \[#4\] Benchmarking framework + snapshotting library performance

## [0.2.0] - 2026-05-20
### Added
- Better CICD
- `setSlowThreshold` to mutate slow-classification cutoff at runtime
- \[#1\] Add a new logging module in the form of an `ConnectivityObserver`

### Changed
- `setCheckInterval` and `setSlowThreshold` renamed to setters -> `checkInterval` and `slowThreshold`

## [0.1.0] - 2026-05-18
### Added
- `HttpProbe.get()` issues GET against endpoints that reject HEAD (HTTP 405) or misbehave under it. The response body is drained but not buffered, so per-call memory cost matches `HttpProbe.head()`.
- HttpProbe.get for HTTP GET

### Changed
- **Breaking:** unified the built-in HTTP probe into a single `HttpProbe` class with `HttpProbe.head()` / `HttpProbe.get()` named constructors. Replaces `HttpHeadProbe`; existing callers update via `HttpHeadProbe()` → `HttpProbe.head()`.
- HttpProbe is split into .head(original) and .get

## [0.0.1] - 2026-05-17
### Added
- InternetConnection scheduler with checkOnce() and a de-duped broadcast onStatusChange stream; sealed InternetStatus (Reachable with response time + ConnectionQuality, Unreachable with failed-probe diagnostics); slow-connection detection opt-in via slowThreshold.
- Pluggable ConnectivityProbe interface with default HttpHeadProbe (HTTP HEAD, shared http.Client, per-target timeout); DNS / TCP / retry-decorator / mock transports drop in via constructor injection.
- Pluggable ReachabilityPolicy interface with AnyReachablePolicy (default, any-of-N race) and AllReachablePolicy (strict, all-of-N); per-policy slow classification — winning probe under any-of-N, the slowest successful probe under all-of-N.
- Sibling-probe cancellation via http.AbortableRequest: under any-of-N, in-flight probes abort at the transport layer the moment one succeeds, releasing sockets immediately instead of waiting out the per-target timeout.
- an `externalRecheckTrigger` constructor hook forces an immediate recheck on any Stream<void> event (e.g. connectivity\_plus.onConnectivityChanged.map(noopWithVal) on Flutter) without the package itself depending on Flutter.

[Unreleased]: https://github.com/LahaLuhem/better_internet_connectivity_checker/compare/0.2.0...vHEAD
[0.2.0]: https://github.com/LahaLuhem/better_internet_connectivity_checker/compare/0.1.0...v0.2.0
[0.1.0]: https://github.com/LahaLuhem/better_internet_connectivity_checker/compare/0.0.1...v0.1.0
[0.0.1]: https://github.com/LahaLuhem/better_internet_connectivity_checker/releases/tag/0.0.1
