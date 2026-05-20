import 'dart:async';

import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:pmvvm/pmvvm.dart';

import '../core/data/constants/core_constants.dart';

typedef StreamState = ({InternetStatus status, int transitions, DateTime lastUpdate});

final class LiveStreamViewModel extends ViewModel {
  InternetConnection? _connection;
  StreamSubscription<InternetStatus>? _subscription;
  late final Stream<void> _externalTrigger;
  Duration? _slowThreshold = ConstDurations.defaultLiveStreamSlowThreshold;

  final _streamStateNotifier = ValueNotifier<StreamState?>(null);

  /// The slider's live value, in milliseconds. Decoupled from [_slowThreshold]
  /// so we don't recreate the connection on every drag tick — only on
  /// release (see [onSlowThresholdSliderReleased]).
  final _sliderValueMillisNotifier = ValueNotifier(
    ConstDurations.defaultLiveStreamSlowThreshold.inMilliseconds.toDouble(),
  );

  @override
  void init() {
    _externalTrigger = Connectivity().onConnectivityChanged.map(noopWithVal);
    unawaited(_buildConnection());
  }

  ValueListenable<StreamState?> get streamStateListenable => _streamStateNotifier;

  ValueListenable<double> get sliderValueMillisListenable => _sliderValueMillisNotifier;

  void onSlowThresholdSliderChanged(double valueMs) => _sliderValueMillisNotifier.value = valueMs;

  Future<void> onForceRecheckPressed() async {
    final connection = _connection;
    if (connection == null) return;

    final status = await connection.checkOnce();
    _streamStateNotifier.value = (
      status: status,
      transitions: _streamStateNotifier.value?.transitions ?? 0,
      lastUpdate: DateTime.now(),
    );
  }

  Future<void> onSlowThresholdSliderReleased(double valueMs) async {
    final newThreshold = valueMs <= 0 ? null : Duration(milliseconds: valueMs.round());
    if (newThreshold == _slowThreshold) return;

    _slowThreshold = newThreshold;
    await _buildConnection();
  }

  Future<void> _buildConnection() async {
    await _subscription?.cancel();
    await _connection?.dispose();

    final connection = InternetConnection(
      slowThreshold: _slowThreshold,
      externalRecheckTrigger: _externalTrigger,
      observer: const PrintingConnectivityObserver(name: 'live_stream'),
    );
    _connection = connection;
    _subscription = connection.onStatusChange.listen((status) {
      _streamStateNotifier.value = (
        status: status,
        transitions: (_streamStateNotifier.value?.transitions ?? 0) + 1,
        lastUpdate: DateTime.now(),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(_connection?.dispose());
    _streamStateNotifier.dispose();
    _sliderValueMillisNotifier.dispose();
    super.dispose();
  }
}
