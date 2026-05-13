import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show ScaffoldMessenger, SnackBar;
import 'package:pmvvm/pmvvm.dart';

import '../core/data/constants/core_constants.dart';
import 'data/enums/probe_method.dart';
import 'method_aware_probe.dart';

typedef ProbeOutcome = ({InternetStatus status, String targetUrl});

final class CustomTargetsViewModel extends ViewModel {
  final urlController = TextEditingController(text: 'https://api.github.com/zen');

  final _shouldAcceptAnyTwoXxNotifier = ValueNotifier(true);
  final _probeMethodNotifier = ValueNotifier(ProbeMethod.head);
  final _timeoutSecondsNotifier = ValueNotifier(
    ConstDurations.defaultCustomTargetsProbeTimeout.inSeconds.toDouble(),
  );
  final _lastOutcomeNotifier = ValueNotifier<ProbeOutcome?>(null);
  final _urlErrorNotifier = ValueNotifier<String?>(null);

  ValueListenable<bool> get shouldAcceptAnyTwoXxListenable => _shouldAcceptAnyTwoXxNotifier;

  ValueListenable<ProbeMethod> get probeMethodListenable => _probeMethodNotifier;

  ValueListenable<double> get timeoutSecondsListenable => _timeoutSecondsNotifier;

  ValueListenable<ProbeOutcome?> get lastOutcomeListenable => _lastOutcomeNotifier;

  ValueListenable<String?> get urlErrorListenable => _urlErrorNotifier;

  void onAcceptAnyTwoXxToggled({required bool value}) =>
      _shouldAcceptAnyTwoXxNotifier.value = value;

  void onMethodSelected(ProbeMethod value) => _probeMethodNotifier.value = value;

  void onTimeoutChanged(double value) => _timeoutSecondsNotifier.value = value;

  Future<void> onProbePressed() async {
    final rawUrlText = urlController.text.trim();
    final uri = Uri.tryParse(rawUrlText);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      _urlErrorNotifier.value = 'Enter an absolute URL with scheme (https://…)';

      return;
    }

    _urlErrorNotifier.value = null;

    final target = ProbeTarget(
      uri: uri,
      timeout: Duration(
        milliseconds: (_timeoutSecondsNotifier.value * Duration.millisecondsPerSecond).round(),
      ),
      isSuccess: _shouldAcceptAnyTwoXxNotifier.value
          ? (response) =>
                response.statusCode >= ConstValues.httpStatusOk &&
                response.statusCode < ConstValues.httpStatusMultipleChoices
          : (response) => response.statusCode == ConstValues.httpStatusOk,
    );

    await _attemptCheck(target, allowRetry: true);
  }

  Future<void> _attemptCheck(ProbeTarget target, {required bool allowRetry}) async {
    String? allowSeen;
    final probe = MethodAwareProbe(
      probeMethod: _probeMethodNotifier.value,
      onAllowHeader: (value) => allowSeen = value,
    );

    final connection = InternetConnection(targets: [target], probe: probe);
    InternetStatus status;
    try {
      status = await connection.checkOnce();
    } finally {
      await connection.dispose();
    }

    _lastOutcomeNotifier.value = (status: status, targetUrl: target.uri.toString());

    if (status is! Unreachable || allowSeen == null) return;

    final suggestedProbeMethod = _parseAllowedMethod(allowSeen!);
    if (suggestedProbeMethod == null || suggestedProbeMethod == _probeMethodNotifier.value) return;

    final previousLabel = _probeMethodNotifier.value.label;
    _probeMethodNotifier.value = suggestedProbeMethod;

    if (!disposed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Server replied 405 with allow: $allowSeen — switched '
            '$previousLabel → ${suggestedProbeMethod.label}'
            '${allowRetry ? ' and retrying.' : '.'}',
          ),
        ),
      );
    }

    if (allowRetry) await _attemptCheck(target, allowRetry: false);
  }

  static ProbeMethod? _parseAllowedMethod(String allow) {
    final probeMethodNames = allow.split(',').map((method) => method.trim().toUpperCase()).toSet();
    for (final candidate in ProbeMethod.values) {
      if (probeMethodNames.contains(candidate.label)) return candidate;
    }

    return null;
  }

  @override
  void dispose() {
    urlController.dispose();
    _shouldAcceptAnyTwoXxNotifier.dispose();
    _probeMethodNotifier.dispose();
    _timeoutSecondsNotifier.dispose();
    _lastOutcomeNotifier.dispose();
    _urlErrorNotifier.dispose();
    super.dispose();
  }
}
