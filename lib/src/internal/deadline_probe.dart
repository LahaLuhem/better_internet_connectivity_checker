part of '../internet_connection.dart';

/// Puts a hard stop on how long one probe may run.
///
/// [ProbeTarget.timeout] is a promise made to the caller, so it can't be left to each probe to keep.
/// A probe still waiting for a TCP connection has no request to abort yet, so it runs until the OS
/// gives up on the connect, which is over a minute on most platforms. Wrapping every probe from the
/// outside bounds it whether or not the probe cooperates.
///
/// The deadline is passed down as a `cancelSignal` too, so a probe that *can* stop early drops its socket
/// instead of leaving it dangling.
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
