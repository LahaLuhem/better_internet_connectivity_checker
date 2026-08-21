import 'package:better_internet_connectivity_checker/src/data/values.dart';
import 'package:checks/checks.dart';

import '../support/bdd.dart';

void main() {
  // The list's whole job is spreading risk, and #34 was the claim rotting unnoticed.
  feature('Values.defaultProbeTargets', () {
    scenario('probes one endpoint per operator, none repeated', () {
      final hosts = Values.defaultProbeTargets.map((target) => target.uri.host);

      check(hosts).length.equals(3);
      check(hosts.toSet()).length.equals(3);
    });

    scenario('sticks to HTTPS, so an interception cannot answer in place of a target', () {
      check(Values.defaultProbeTargets.map((probeTarget) => probeTarget.uri.scheme))
          .every((schemeSubject) => schemeSubject.equals('https'));
    });
  });

  feature('noopWithVal', () {
    scenario('returns a function that discards any argument without throwing', () {
      final fn = noopWithVal;

      fn(42);
      fn('any');
      fn(null);
      fn(Object());

      check(fn).isA<void Function(Object?)>();
    });
  });
}
