import 'package:better_internet_connectivity_checker/better_internet_connectivity_checker.dart';
import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart' show InputDecoration, OutlineInputBorder, Theme;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart';
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
    viewBuilder: (context, viewModel) => PlatformScaffold(
      appBarData: const PlatformAppBar(title: Text('Custom targets')),
      body: SafeArea(
        child: ListView(
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
                builder: (context, probeMethod, _) => PlatformTextField(
                  controller: viewModel.urlController,
                  keyboardType: .url,
                  autocorrect: false,
                  cupertinoTextFieldData: const CupertinoTextFieldData(placeholder: 'Target URL'),
                  materialTextFieldData: MaterialTextFieldData(
                    decoration: InputDecoration(
                      labelText: 'Target URL',
                      border: const OutlineInputBorder(),
                      errorText: urlError,
                      helperText: 'A ${probeMethod.label} request will be sent to this URL',
                    ),
                  ),
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
                  builder: (context, probeMethod, _) => PlatformSegmentButton<ProbeMethod>(
                    choices: ProbeMethod.values,
                    selectedChoice: probeMethod,
                    segmentBuilder: (method) => Text(method.label),
                    onSelectionChanged: (method) {
                      if (method != null) viewModel.onMethodSelected(method);
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
                    child: PlatformSlider(
                      min: ConstDurations.minSelectableCustomTargetsTimeout.inSeconds.toDouble(),
                      max: ConstDurations.maxSelectableCustomTargetsTimeout.inSeconds.toDouble(),
                      divisions: ConstValues.customTargetsTimeoutSliderDivisions,
                      value: timeoutSeconds,
                      onChanged: viewModel.onTimeoutChanged,
                      materialSliderData: MaterialSliderData(label: '${timeoutSeconds.round()} s'),
                    ),
                  ),
                ],
              ),
            ),
            const _AutoSwitchInfoCard(),
            ValueListenableBuilder(
              valueListenable: viewModel.shouldAcceptAnyTwoXxListenable,
              builder: (context, shouldAcceptAnyTwoXx, _) => PlatformListTile(
                title: const Text('Accept any 2xx'),
                subtitle: Text(
                  shouldAcceptAnyTwoXx
                      ? 'isSuccess: (response) => '
                            'response.statusCode >= 200 && response.statusCode < 300'
                      : 'isSuccess: default — statusCode == 200',
                ),
                trailing: PlatformSwitch(
                  value: shouldAcceptAnyTwoXx,
                  onChanged: (value) => viewModel.onAcceptAnyTwoXxToggled(value: value),
                ),
                onTap: () => viewModel.onAcceptAnyTwoXxToggled(value: !shouldAcceptAnyTwoXx),
              ),
            ),
            const Gap(16),
            AsyncIconActionButton(
              onPressed: viewModel.onProbePressed,
              idleIcon: PlatformIcons.send,
              idleLabel: 'Probe URL',
              busyLabel: 'Probing…',
            ),
            const Gap(16),
            ValueListenableBuilder(
              valueListenable: viewModel.lastOutcomeListenable,
              builder: (context, outcome, _) {
                if (outcome == null) return const SizedBox.shrink();

                return PlatformCard(
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
    ),
  );
}

class _AutoSwitchInfoCard extends StatelessWidget {
  const _AutoSwitchInfoCard();

  @override
  Widget build(BuildContext context) => PlatformCard(
    child: Padding(
      padding: const .all(16),
      child: Row(
        crossAxisAlignment: .start,
        spacing: 16,
        children: [
          const PlatformIcon(PlatformIcons.info, size: 20),
          Expanded(
            child: Text(
              'Main probing uses the built-in HttpProbe.head() / HttpProbe.get(). '
              'On Unreachable, the demo re-fetches via an inline MethodAwareProbe '
              'to read the response’s Allow header — ProbeResult is intentionally '
              'protocol-agnostic, so HTTP-specific data must be surfaced on the '
              'probe itself. If Allow names a supported method, the dropdown '
              'switches and retries once. See method_aware_probe.dart.',
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
