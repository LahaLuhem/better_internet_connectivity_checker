import '../probe/models/probe_result.dart';
import 'models/connection_quality.dart';

part 'outcomes/reachable.dart';
part 'outcomes/unreachable.dart';

/// What a check came back with: [Reachable] or [Unreachable], nothing else.
///
/// ```dart
/// switch (await checker.checkOnce()) {
///   case Reachable(:final responseTime, :final quality):
///     print('online (${responseTime.inMilliseconds} ms, $quality)');
///   case Unreachable(:final failedProbes):
///     print('offline, ${failedProbes.length} probes failed');
/// }
/// ```
sealed class InternetStatus {
  /// Creates an [InternetStatus].
  const new();
}
