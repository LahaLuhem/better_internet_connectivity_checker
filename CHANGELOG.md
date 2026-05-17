## [0.0.1] - 2026-05-17
### Added
- InternetConnection scheduler with checkOnce() and a de-duped broadcast onStatusChange stream; sealed InternetStatus (Reachable with response time + ConnectionQuality, Unreachable with failed-probe diagnostics); slow-connection detection opt-in via slowThreshold.
- Pluggable ConnectivityProbe interface with default HttpHeadProbe (HTTP HEAD, shared http.Client, per-target timeout); DNS / TCP / retry-decorator / mock transports drop in via constructor injection.
- Pluggable ReachabilityPolicy interface with AnyReachablePolicy (default, any-of-N race) and AllReachablePolicy (strict, all-of-N); per-policy slow classification — winning probe under any-of-N, the slowest successful probe under all-of-N.
- Sibling-probe cancellation via http.AbortableRequest: under any-of-N, in-flight probes abort at the transport layer the moment one succeeds, releasing sockets immediately instead of waiting out the per-target timeout.
- an `externalRecheckTrigger` constructor hook forces an immediate recheck on any Stream<void> event (e.g. connectivity\_plus.onConnectivityChanged.map(noopWithVal) on Flutter) without the package itself depending on Flutter.

[0.0.1]: https://github.com/LahaLuhem/better_internet_connectivity_checker/releases/tag/0.0.1
