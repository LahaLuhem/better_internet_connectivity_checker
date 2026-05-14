import 'package:better_internet_connectivity_checker/src/data/models/const_uri.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('ConstUri construction', () {
    test('is const-constructible — proves the parse is deferred', () {
      // `Uri.parse(...)` is not a const expression, so the constructor being
      // `const` is itself the load-bearing proof that parsing happens lazily.
      // Would fail to compile if the ctor were non-const.
      const wrapped = ConstUri('https://example.com');

      check(wrapped.scheme).equals('https');
    });

    test('inherits Uri.parse permissiveness — does not validate input', () {
      // Documents the trade-off captured in the class dartdoc: an unconventional
      // scheme is accepted, not rejected, mirroring `Uri.parse` behaviour.
      const wrapped = ConstUri('htps://example.com');

      check(wrapped.scheme).equals('htps');
    });
  });

  group('ConstUri accessor delegation', () {
    test('host / scheme / path / query / port match Uri.parse', () {
      const wrapped = ConstUri('https://example.com:8443/api/v2?limit=1');
      final reference = Uri.parse('https://example.com:8443/api/v2?limit=1');

      check(wrapped.host).equals(reference.host);
      check(wrapped.scheme).equals(reference.scheme);
      check(wrapped.path).equals(reference.path);
      check(wrapped.query).equals(reference.query);
      check(wrapped.port).equals(reference.port);
    });

    test('toString matches Uri.parse.toString', () {
      const wrapped = ConstUri('https://example.com/x');
      final reference = Uri.parse('https://example.com/x');

      check(wrapped.toString()).equals(reference.toString());
    });

    test('replace produces a working Uri', () {
      const wrapped = ConstUri('https://example.com/x');
      final replaced = wrapped.replace(path: '/y');

      check(replaced.path).equals('/y');
      check(replaced.host).equals('example.com');
    });

    test('resolve works against a relative reference', () {
      const base = ConstUri('https://example.com/foo/');
      final resolved = base.resolve('bar');

      check(resolved.toString()).equals('https://example.com/foo/bar');
    });
  });

  group('ConstUri equality', () {
    test('two instances wrapping the same string compare equal', () {
      const a = ConstUri('https://example.com');
      const b = ConstUri('https://example.com');

      check(a == b).isTrue();
      check(a.hashCode).equals(b.hashCode);
    });

    test('compares equal to Uri.parse of the same string in both directions', () {
      const wrapped = ConstUri('https://example.com');
      final parsed = Uri.parse('https://example.com');

      check(wrapped == parsed).isTrue();
      check(parsed == wrapped).isTrue();
      check(wrapped.hashCode).equals(parsed.hashCode);
    });

    test('different strings compare unequal', () {
      const a = ConstUri('https://example.com');
      const b = ConstUri('https://other.com');

      check(a == b).isFalse();
    });
  });

  group('ConstUri in hash-based collections', () {
    test('works as a Map key alongside other Uri implementations', () {
      const key = ConstUri('https://example.com');
      final lookup = Uri.parse('https://example.com');
      final map = <Uri, int>{key: 42};

      check(map[lookup]).equals(42);
    });

    test('Set deduplicates equal instances across Uri implementations', () {
      const wrapped = ConstUri('https://example.com');
      final parsed = Uri.parse('https://example.com');
      final set = <Uri>{wrapped, parsed};

      check(set).length.equals(1);
    });
  });
}
