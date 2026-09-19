import 'probe_target.dart';

/// What came of probing one [ProbeTarget].
///
/// Always carries the elapsed time, which is what tells "timed out after 3 s" apart from "DNS died
/// in 30 ms". No protocol-specific fields (headers, DNS records, RST codes): those belong on the
/// probe that knows about them. See [Appendix](https://github.com/LahaLuhem/better_internet_connectivity_checker/blob/main/APPENDIX.md#no-response-data-on-result).
final class const ProbeResult._({
  /// The target that got probed.
  required final ProbeTarget target,

  /// Whether the target's predicate accepted the response. Derived, which is why the primary
  /// constructor is private and the 2 named ones pin it.
  required final bool isSuccess,

  /// How long the probe took.
  required final Duration responseTime,

  /// Whatever the probe threw, if anything. Always null on success.
  final Object? error,
}) {
  /// Creates a successful [ProbeResult].
  const new success({required ProbeTarget target, required Duration responseTime})
    : this._(target: target, isSuccess: true, responseTime: responseTime);

  /// Creates a failed [ProbeResult]. [error] is null when the probe came back fine but
  /// [ProbeTarget.isSuccess] turned the response down.
  const new failure({required ProbeTarget target, required Duration responseTime, Object? error})
    : this._(target: target, isSuccess: false, responseTime: responseTime, error: error);

  @override
  String toString() =>
      'ProbeResult('
      'target: $target, '
      'isSuccess: $isSuccess, '
      'responseTime: $responseTime, '
      'error: $error'
      ')';
}
