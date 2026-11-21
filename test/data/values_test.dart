import 'dart:async';

import 'package:better_internet_connectivity_checker/src/data/values.dart';
import 'package:checks/checks.dart';

import '../support/bdd.dart';

void main() {
  // The list's whole job is spreading risk, and #34 was the claim rotting unnoticed.
  feature('Values.defaultProbeTargets', () {
    scenario('probes one endpoint per operator, none repeated', () {
      final hosts = Values.defaultProbeTargets.map((target) => target.uri.host);

      check(hosts).length.isGreaterThan(1);
      check(hosts.toSet()).length.equals(hosts.length);
    });

    scenario('sticks to HTTPS, so an interception cannot answer in place of a target', () {
      check(Values.defaultProbeTargets.map((probeTarget) => probeTarget.uri.scheme))
          .every(.it()..equals('https'));
    });
  });

  feature('noopWithVal', () {
    scenario('maps a stream of anything to a void stream that still ticks', () async {
      final source = Stream<Object?>.fromIterable([42, 'any', null, Object()]);

      check(await source.map(noopWithVal).length).equals(4);
    });
  });
}
