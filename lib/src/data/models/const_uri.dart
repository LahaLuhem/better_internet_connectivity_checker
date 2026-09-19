// Immutable in practice, but `@immutable` lives in `package:meta` and the runtime pubspec stays at
// one dependency.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

/// A [Uri] you can put in a `const`, by holding the string and parsing it on first use.
///
/// `Uri.parse` isn't a const expression, so this keeps the raw string until someone reads a member,
/// then caches the parse process-wide. What it costs you: a malformed URI only blows up on first
/// access, and every accessor pays a map lookup.
///
/// Adapted from https://gist.github.com/passsy/0be2ca0e86ff11e400187f7076404678.
final class const ConstUri(final String _uri) implements Uri {
  static final _cache = <String, Uri>{};

  /// Wraps a URI string. Nothing is parsed until you read a member.
  this;

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
