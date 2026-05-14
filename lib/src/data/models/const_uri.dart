// The class is logically immutable (`final` class, `final` field, `const`
// constructor), but doesn't carry `@immutable` because that annotation ships
// only in `package:meta` — a dep we deliberately avoid (keeps the runtime
// pubspec at one entry, per the package's pure-Dart, minimal-dep posture).
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

/// A `const`-constructible wrapper around [Uri] that defers parsing until
/// first member access.
///
/// `Uri.parse(...)` is not a `const` expression, so [Uri] instances cannot
/// appear inside `const` constructors or `const` collection literals.
/// [ConstUri] stores the raw string at compile time and parses it lazily on
/// first accessor call, caching the result process-wide so multiple instances
/// pointing at the same string share one parsed [Uri].
///
/// Trade-offs vs. `Uri.https(...)` / `Uri.parse(...)`:
/// - **Gains** `const` construction — enclosing value types can become `const`
///   and benefit from compile-time canonicalisation.
/// - **Loses** eager validation — a malformed URI surfaces only on first
///   accessor call. `Uri.parse` itself is permissive, so most typos (e.g.
///   `'htps://...'`) parse "successfully" with the wrong scheme rather than
///   throwing.
/// - **Adds** one map lookup per accessor, plus a one-off parse on first
///   access of any given string.
///
/// Adapted from https://gist.github.com/passsy/0be2ca0e86ff11e400187f7076404678.
final class ConstUri implements Uri {
  static final _cache = <String, Uri>{};

  final String _uri;

  /// Wraps a URI string, deferring `Uri.parse` until the first member access.
  const ConstUri(this._uri);

  Uri get _delegate => _cache.putIfAbsent(_uri, () => Uri.parse(_uri));

  @override
  String get authority => _delegate.authority;

  @override
  UriData? get data => _delegate.data;

  @override
  String get fragment => _delegate.fragment;

  @override
  bool get hasAbsolutePath => _delegate.hasAbsolutePath;

  @override
  bool get hasAuthority => _delegate.hasAuthority;

  @override
  bool get hasEmptyPath => _delegate.hasEmptyPath;

  @override
  bool get hasFragment => _delegate.hasFragment;

  @override
  bool get hasPort => _delegate.hasPort;

  @override
  bool get hasQuery => _delegate.hasQuery;

  @override
  bool get hasScheme => _delegate.hasScheme;

  @override
  String get host => _delegate.host;

  @override
  bool get isAbsolute => _delegate.isAbsolute;

  @override
  bool isScheme(String scheme) => _delegate.isScheme(scheme);

  @override
  Uri normalizePath() => _delegate.normalizePath();

  @override
  String get origin => _delegate.origin;

  @override
  String get path => _delegate.path;

  @override
  List<String> get pathSegments => _delegate.pathSegments;

  @override
  int get port => _delegate.port;

  @override
  String get query => _delegate.query;

  @override
  Map<String, String> get queryParameters => _delegate.queryParameters;

  @override
  Map<String, List<String>> get queryParametersAll => _delegate.queryParametersAll;

  @override
  Uri removeFragment() => _delegate.removeFragment();

  @override
  Uri replace({
    String? scheme,
    String? userInfo,
    String? host,
    int? port,
    String? path,
    Iterable<String>? pathSegments,
    String? query,
    Map<String, dynamic>? queryParameters,
    String? fragment,
  }) => _delegate.replace(
    scheme: scheme,
    userInfo: userInfo,
    host: host,
    port: port,
    path: path,
    pathSegments: pathSegments,
    query: query,
    queryParameters: queryParameters,
    fragment: fragment,
  );

  @override
  Uri resolve(String reference) => _delegate.resolve(reference);

  @override
  Uri resolveUri(Uri reference) => _delegate.resolveUri(reference);

  @override
  String get scheme => _delegate.scheme;

  @override
  String toFilePath({bool? windows}) => _delegate.toFilePath(windows: windows);

  @override
  String get userInfo => _delegate.userInfo;

  @override
  String toString() => _delegate.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ConstUri && _uri == other._uri) || _delegate == other;

  @override
  int get hashCode => _delegate.hashCode;
}
