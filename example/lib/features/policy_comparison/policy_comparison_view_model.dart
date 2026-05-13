import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/foundation.dart';
import 'package:pmvvm/pmvvm.dart';

typedef PolicyResults = ({InternetStatus any, InternetStatus all});

final class PolicyComparisonViewModel extends ViewModel {
  static final _baseTargets = [
    ProbeTarget(uri: Uri.parse('https://one.one.one.one')),
    ProbeTarget(uri: Uri.parse('https://icanhazip.com/')),
  ];

  static final _bogusTarget = ProbeTarget(
    uri: Uri.parse('https://this-domain-definitely-does-not-resolve.invalid/'),
  );

  final _shouldIncludeBogusTargetNotifier = ValueNotifier(true);
  final _resultsNotifier = ValueNotifier<PolicyResults?>(null);

  ValueListenable<bool> get shouldIncludeBogusTargetListenable => _shouldIncludeBogusTargetNotifier;

  ValueListenable<PolicyResults?> get resultsListenable => _resultsNotifier;

  void onIncludeBogusTargetToggled({required bool value}) {
    _shouldIncludeBogusTargetNotifier.value = value;
    _resultsNotifier.value = null;
  }

  Future<void> onRunBothPressed() async {
    _resultsNotifier.value = null;

    final targets = [..._baseTargets, if (_shouldIncludeBogusTargetNotifier.value) _bogusTarget];
    final anyConnection = InternetConnection(targets: targets);
    final allConnection = InternetConnection(targets: targets, policy: const AllReachablePolicy());

    try {
      final (anyStatus, allStatus) = await (
        anyConnection.checkOnce(),
        allConnection.checkOnce(),
      ).wait;
      _resultsNotifier.value = (any: anyStatus, all: allStatus);
    } finally {
      await anyConnection.dispose();
      await allConnection.dispose();
    }
  }

  @override
  void dispose() {
    _shouldIncludeBogusTargetNotifier.dispose();
    _resultsNotifier.dispose();
    super.dispose();
  }
}
