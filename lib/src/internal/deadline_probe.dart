part of '../internet_connection.dart';

/// Puts a hard stop on how long one probe may run, whether or not the probe plays along.
///
/// A probe still waiting on a TCP connect has no request to abort yet, so left to itself it runs
/// until the OS gives up, which is over a minute on most platforms. The deadline also goes down as a
/// `cancelSignal`, so a probe that can stop early drops its socket instead of sitting on it. Why
/// this lives here and not in the probe: [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#why-the-coordinator-keeps-the-deadline).
final class _DeadlineProbe(final ConnectivityProbe _inner) implements ConnectivityProbe {
  @override
  Future<ProbeResult> probe(ProbeTarget target, {Future<void>? cancelSignal}) {
    final releaseSignal = Completer<void>();
    void release() {
      if (!releaseSignal.isCompleted) releaseSignal.complete();
    }

    unawaited(cancelSignal?.whenComplete(release));

    return _inner
        .probe(target, cancelSignal: releaseSignal.future)
        .timeout(
          target.timeout,
          onTimeout: () {
            release();

            return ProbeResult.failure(
              target: target,
              responseTime: target.timeout,
              error: TimeoutException('Probe of ${target.uri} timed out.', target.timeout),
            );
          },
        );
  }
}
