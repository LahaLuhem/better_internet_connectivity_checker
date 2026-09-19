/// A thin Gherkin vocabulary over `package:test`, no dependencies. The point is the shape: tests
/// that read as a specification rather than a pile of `group` and `test` calls.
library;

import 'dart:async';

import 'package:test/scaffolding.dart';

/// Groups the scenarios describing one unit under test. Reads as `Feature: <description>` in output.
void feature(String description, void Function() body) => group('Feature: $description', body);

/// One behaviour of the unit under test. Reads as `Scenario: <description>`, and [body] is the
/// Given/When/Then flow.
void scenario(String description, FutureOr<void> Function() body) =>
    test('Scenario: $description', body);

/// A scenario run once per row of an examples table.
///
/// [examples] maps each row's name to a record of its inputs and expected outcome, so the cases read
/// as a table. Each row becomes its own test, so a failure names the row that broke.
void scenarioOutline<Row>(
  String description, {
  required Map<String, Row> examples,
  required FutureOr<void> Function(Row example) outline,
}) => group('Scenario Outline: $description', () {
  for (final MapEntry(key: name, value: row) in examples.entries) {
    test(name, () => outline(row));
  }
});
