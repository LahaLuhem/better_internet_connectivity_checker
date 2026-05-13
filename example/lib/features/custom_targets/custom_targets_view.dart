import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart'
    show
        AppBar,
        Card,
        DropdownButton,
        DropdownMenuItem,
        Icon,
        Icons,
        InputDecoration,
        OutlineInputBorder,
        Scaffold,
        Slider,
        SwitchListTile,
        TextField,
        Theme;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '../core/data/const_formatters.dart';
import '../core/data/constants/core_constants.dart';
import '../core/widgets/core_widgets.dart';
import 'custom_targets_view_model.dart';
import 'data/enums/probe_method.dart';

class CustomTargetsView extends StatelessWidget {
  const CustomTargetsView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: CustomTargetsViewModel(),
    viewBuilder: (context, viewModel) => Scaffold(
      appBar: AppBar(title: const Text('Custom targets')),
      body: ListView(
        padding: const .all(16),
        children: [
          const DemoIntro(
            title: 'ProbeTarget + ResponseAcceptor',
            description:
                'Override the default reliability endpoints with your own URL '
                'and decide what counts as a healthy response.',
          ),
          const Gap(16),
          ValueListenableBuilder(
            valueListenable: viewModel.urlErrorListenable,
            builder: (context, urlError, _) => ValueListenableBuilder(
              valueListenable: viewModel.probeMethodListenable,
              builder: (context, probeMethod, _) => TextField(
                controller: viewModel.urlController,
                decoration: InputDecoration(
                  labelText: 'Target URL',
                  border: const OutlineInputBorder(),
                  errorText: urlError,
                  helperText: 'A ${probeMethod.label} request will be sent to this URL',
                ),
                keyboardType: .url,
                autocorrect: false,
              ),
            ),
          ),
          const Gap(16),
          Row(
            spacing: 8,
            children: [
              const Text('HTTP method:'),
              ValueListenableBuilder(
                valueListenable: viewModel.probeMethodListenable,
                builder: (context, probeMethod, _) => DropdownButton(
                  value: probeMethod,
                  items: [
                    for (final method in ProbeMethod.values)
                      DropdownMenuItem(value: method, child: Text(method.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) viewModel.onMethodSelected(value);
                  },
                ),
              ),
            ],
          ),
          ValueListenableBuilder(
            valueListenable: viewModel.timeoutSecondsListenable,
            builder: (context, timeoutSeconds, _) => Row(
              children: [
                Text('Timeout: ${timeoutSeconds.round()} s'),
                Expanded(
                  child: Slider(
                    min: ConstDurations.minSelectableCustomTargetsTimeout.inSeconds.toDouble(),
                    max: ConstDurations.maxSelectableCustomTargetsTimeout.inSeconds.toDouble(),
                    divisions: ConstValues.customTargetsTimeoutSliderDivisions,
                    value: timeoutSeconds,
                    label: '${timeoutSeconds.round()} s',
                    onChanged: viewModel.onTimeoutChanged,
                  ),
                ),
              ],
            ),
          ),
          const _AutoSwitchInfoCard(),
          ValueListenableBuilder(
            valueListenable: viewModel.shouldAcceptAnyTwoXxListenable,
            builder: (context, shouldAcceptAnyTwoXx, _) => SwitchListTile(
              title: const Text('Accept any 2xx'),
              subtitle: Text(
                shouldAcceptAnyTwoXx
                    ? 'isSuccess: (response) => '
                          'response.statusCode >= 200 && response.statusCode < 300'
                    : 'isSuccess: default — statusCode == 200',
              ),
              value: shouldAcceptAnyTwoXx,
              onChanged: (value) => viewModel.onAcceptAnyTwoXxToggled(value: value),
            ),
          ),
          const Gap(16),
          AsyncIconActionButton(
            onPressed: viewModel.onProbePressed,
            idleIcon: Icons.send,
            idleLabel: 'Probe URL',
            busyLabel: 'Probing…',
          ),
          const Gap(16),
          ValueListenableBuilder(
            valueListenable: viewModel.lastOutcomeListenable,
            builder: (context, outcome, _) {
              if (outcome == null) return const SizedBox.shrink();

              return Card(
                child: Padding(
                  padding: const .all(16),
                  child: Column(
                    crossAxisAlignment: .start,
                    spacing: 8,
                    children: [
                      Text(
                        'Probed ${outcome.targetUrl}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      StatusBadge(internetStatus: outcome.status),
                      _ResultDetail(result: outcome.status),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _AutoSwitchInfoCard extends StatelessWidget {
  const _AutoSwitchInfoCard();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const .all(16),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 16,
        children: [
          const Icon(Icons.info_outline, size: 20),
          Expanded(
            child: Text(
              'If the server replies 405 Method Not Allowed with an Allow header, '
              'this demo switches the dropdown to a supported method and retries '
              'once. Powered by an inline MethodAwareProbe — see method_aware_probe.dart '
              'for the ConnectivityProbe implementation.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ResultDetail extends StatelessWidget {
  final InternetStatus result;

  const _ResultDetail({required this.result});

  @override
  Widget build(BuildContext context) => switch (result) {
    Reachable(:final responseTime) => Text(
      'Predicate accepted the response in ${ConstFormatters.humanReadableDuration(responseTime)}.',
    ),
    Unreachable(:final failedProbes) => Column(
      crossAxisAlignment: .start,
      children: [
        Text(
          'Probe failed in ${ConstFormatters.humanReadableDuration(failedProbes.first.responseTime)}.',
        ),
        Text('Cause: ${ConstFormatters.describeProbeError(failedProbes.first.error)}'),
      ],
    ),
  };
}
