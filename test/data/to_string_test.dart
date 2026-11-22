/// "Connection closed before full header was received" here is not this file. Coverage runs load
/// every suite over a loopback socket, and the handshake drops on a random one:
/// https://github.com/dart-lang/native/issues/3738. Re-run it. Lowering CI's `dart test`
/// concurrency reduces the load that triggers it, if it ever turns regular.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:checks/checks.dart';

import '../support/bdd.dart';

/// Its `toString` forwards to the wrapped [Uri], so it renders no field of its own.
const _delegatingToStringClassNames = {'ConstUri'};

/// A multi-line dump has no place in a one-line diagnostic, so the convention leaves it out.
const _opaqueTypeNames = {'StackTrace'};

typedef _Sample = ({Object value, Map<String, Object?> shownValuesByField});

final _target = ProbeTarget(uri: Uri.https('example.com', '/healthz'));
const _reachable = Reachable(responseTime: Duration(milliseconds: 250), quality: .good);
const _unreachable = Unreachable(failedProbes: []);
const _scheduleContext = ScheduleContext(
  baseInterval: Duration(seconds: 10),
  consecutiveFailures: 2,
  lastStatus: _unreachable,
);

/// One table, because the check against the source reads it whole.
final _samplesByClassName = <String, _Sample>{
  'CheckCompletedEvent': _sample(
    const CheckCompletedEvent(_reachable),
    (event) => {'result': event.result},
  ),
  'CheckIntervalChangedEvent': _sample(
    const CheckIntervalChangedEvent(previous: Duration(seconds: 5), next: Duration(seconds: 3)),
    (event) => {'previous': event.previous, 'next': event.next},
  ),
  'ExternalTriggerErrorEvent': _sample(
    const ExternalTriggerErrorEvent(FormatException('bad signal'), StackTrace.empty),
    (event) => {'error': event.error},
  ),
  'NextCheckScheduledEvent': _sample(
    const NextCheckScheduledEvent(delay: Duration(seconds: 8), scheduleContext: _scheduleContext),
    (event) => {'delay': event.delay, 'scheduleContext': event.scheduleContext},
  ),
  'ProbeResult': _sample(
    ProbeResult.failure(
      target: _target,
      responseTime: const Duration(milliseconds: 100),
      error: const FormatException('boom'),
    ),
    (result) => {
      'target': result.target,
      'isSuccess': result.isSuccess,
      'responseTime': result.responseTime,
      'error': result.error,
    },
  ),
  'ProbeTarget': _sample(
    _target,
    (target) => {
      'uri': target.uri,
      'timeout': target.timeout,
      'followRedirects': target.followRedirects,
      'headers': target.headers,
    },
  ),
  'Reachable': _sample(
    _reachable,
    (status) => {'responseTime': status.responseTime, 'quality': status.quality},
  ),
  'ScheduleContext': _sample(
    _scheduleContext,
    (context) => {
      'baseInterval': context.baseInterval,
      'consecutiveFailures': context.consecutiveFailures,
      'lastStatus': context.lastStatus,
    },
  ),
  'SlowThresholdChangedEvent': _sample(
    const SlowThresholdChangedEvent(previous: Duration(milliseconds: 200), next: null),
    (event) => {'previous': event.previous, 'next': event.next},
  ),
  'StatusEmittedEvent': _sample(
    const StatusEmittedEvent(previous: _unreachable, next: _reachable),
    (event) => {'previous': event.previous, 'next': event.next},
  ),
  'Unreachable': _sample(
    Unreachable(
      failedProbes: [
        ProbeResult.failure(target: _target, responseTime: const Duration(seconds: 1)),
      ],
    ),
    (status) => {'failedProbes': status.failedProbes},
  ),
};

_Sample _sample<T extends Object>(T value, Map<String, Object?> Function(T) shownValuesByField) =>
    (value: value, shownValuesByField: shownValuesByField(value));

void main() {
  feature('Value type toString', () {
    scenario('every class with a toString shows each of its fields as name: value', () {
      check(_shownFieldNamesFromSource()).deepEquals(
        _samplesByClassName.map(
          (name, sample) => MapEntry(name, sample.shownValuesByField.keys.toSet()),
        ),
      );

      final hiddenFieldsByClassName = Map.fromEntries(
        _samplesByClassName.entries
            .map(
              (entry) => MapEntry(
                entry.key,
                entry.value.shownValuesByField.entries
                    .where(
                      (field) => !'${entry.value.value}'.contains('${field.key}: ${field.value}'),
                    )
                    .map((field) => field.key)
                    .toSet(),
              ),
            )
            .where((entry) => entry.value.isNotEmpty),
      );

      check(hiddenFieldsByClassName).isEmpty;
    });
  });
}

/// Every class under `lib/src` that declares its own `toString`, mapped to the fields it must show.
Map<String, Set<String>> _shownFieldNamesFromSource() {
  final units = Directory('lib/src')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map(
        (file) => parseString(
          content: file.readAsStringSync(),
          featureSet: .latestLanguageVersion(),
        ).unit,
      )
      .toList(growable: false);

  // A function-typed field is opaque: its toString is `Closure: ...`, so the convention omits it.
  final functionTypedefNames = units
      .expand((unit) => unit.declarations.whereType<GenericTypeAlias>())
      .where((alias) => alias.type is GenericFunctionType)
      .map((alias) => alias.name.lexeme)
      .toSet();

  bool isShown(TypeAnnotation? type) =>
      type is! GenericFunctionType &&
      !(type is NamedType &&
          (functionTypedefNames.contains(type.name.lexeme) ||
              _opaqueTypeNames.contains(type.name.lexeme)));

  return Map.fromEntries(
    units
        .expand((unit) => unit.declarations.whereType<ClassDeclaration>())
        .where(
          (declaration) =>
              declaration.body.members.whereType<MethodDeclaration>().any(
                (member) => member.name.lexeme == 'toString',
              ) &&
              !_delegatingToStringClassNames.contains(declaration.namePart.typeName.lexeme),
        )
        .map((declaration) {
          final namePart = declaration.namePart;
          final fieldNames = namePart is PrimaryConstructorDeclaration
              ? namePart.formalParameters.parameters
                    .where((parameter) => isShown(parameter.type))
                    // A private header field is read through its underscore-stripped getter, which
                    // is the name toString prints.
                    .map((parameter) => parameter.name?.lexeme.replaceFirst(RegExp('^_'), ''))
                    .nonNulls
              : const <String>[];

          return MapEntry(namePart.typeName.lexeme, fieldNames.toSet());
        })
        .where((entry) => entry.value.isNotEmpty),
  );
}
