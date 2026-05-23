import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/foundation.dart';
import 'package:pmvvm/pmvvm.dart';

final class OneShotViewModel extends ViewModel {
  final _connection = InternetConnection();
  final _lastResultNotifier = ValueNotifier<InternetStatus?>(null);

  @override
  void init() {
    attachObserver(_connection.events, const PrintingConnectivityObserver(name: 'one_shot'));
  }

  ValueListenable<InternetStatus?> get lastResultListenable => _lastResultNotifier;

  Future<void> onRunCheckPressed() async {
    _lastResultNotifier.value = await _connection.checkOnce();
  }

  @override
  void dispose() {
    _lastResultNotifier.dispose();
    unawaited(_connection.dispose());
    super.dispose();
  }
}
