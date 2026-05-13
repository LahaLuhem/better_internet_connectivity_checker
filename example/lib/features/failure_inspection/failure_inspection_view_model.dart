import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/foundation.dart';
import 'package:pmvvm/pmvvm.dart';

import '../core/data/constants/core_constants.dart';

final class FailureInspectionViewModel extends ViewModel {
  static final _unreachableTargets = [
    ProbeTarget(uri: Uri.parse('https://nope-1.invalid/')),
    ProbeTarget(
      uri: Uri.parse('https://nope-2.invalid/'),
      timeout: ConstDurations.failureInspectionShortProbeTimeout,
    ),
    ProbeTarget(uri: Uri.parse('https://nope-3.invalid/')),
  ];

  final _lastResultNotifier = ValueNotifier<InternetStatus?>(null);

  ValueListenable<InternetStatus?> get lastResultListenable => _lastResultNotifier;

  Future<void> onRunCheckPressed() async {
    _lastResultNotifier.value = null;

    final connection = InternetConnection(
      targets: _unreachableTargets,
      policy: const AllReachablePolicy(),
    );
    try {
      _lastResultNotifier.value = await connection.checkOnce();
    } finally {
      await connection.dispose();
    }
  }

  @override
  void dispose() {
    _lastResultNotifier.dispose();
    super.dispose();
  }
}
