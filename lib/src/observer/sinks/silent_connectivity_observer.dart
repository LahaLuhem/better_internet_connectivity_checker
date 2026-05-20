part of '../../internet_connection.dart';

/// Internal default observer used when the caller passes none.
///
/// Every method inherits the no-op default from [ConnectivityObserver], so
/// the instance is `const` and the hot-path calls inline to nothing under
/// AOT. Kept library-private to [InternetConnection]'s scope via the
/// part-of relationship — it has no public meaning beyond backing the
/// constructor's default.
final class _SilentConnectivityObserver extends ConnectivityObserver {
  const _SilentConnectivityObserver();
}
