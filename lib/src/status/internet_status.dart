import '../probe/models/probe_result.dart';
import 'models/connection_quality.dart';

part 'outcomes/reachable.dart';
part 'outcomes/unreachable.dart';

///
/// Sealed so callers can pattern-match exhaustively:
///
/// ```dart
/// switch (await checker.checkOnce()) {
///   case Reachable(:final responseTime, :final quality):
///     print('online (${responseTime.inMilliseconds} ms, $quality)');
///   case Unreachable(:final failedProbes):
///     print('offline (${failedProbes.length} probes failed)');
/// }
/// ```
sealed class InternetStatus {
  /// Subclasses are sealed; external code may not extend this type.
  const InternetStatus();
}
