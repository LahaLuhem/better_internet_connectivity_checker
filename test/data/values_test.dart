import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('noopWithVal', () {
    test('returns a function that discards any argument without throwing', () {
      final fn = noopWithVal;

      fn(42);
      fn('any');
      fn(null);
      fn(Object());

      check(fn).isA<void Function(Object?)>();
    });
  });
}
