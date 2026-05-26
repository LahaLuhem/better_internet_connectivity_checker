# Benchmark results

Captured **2026-05-26** against `0.2.0` at `3a112e9` on Dart SDK 3.11.5. N=30 iterations per scenario.

> Per-machine measurements. Numbers below reflect *this* machine (CPU, GC, OS scheduler, thermal state). Your numbers WILL differ - capture your own local baseline before measuring a code delta.

## Headline: worst-case scheduler stall per scenario

The `slow_observer` scenario simulates a heavy synchronous observer (50 ms per callback) running against a 100 ms tick. Pre-refactor, this blocks the scheduler - the box for `slow_observer` should tower over the others on the log axis below.

| Scenario | N | Median (us) | IQR (us) | Min (us) | Max (us) |
|---|---:|---:|---:|---:|---:|
| `flapping_network` | 30 | 6,510 | 5,504 | 3,545 | 36,553 |
| `long_running` | 30 | 40,178 | 18,320 | 16,822 | 54,649 |
| `many_subscribers` | 90 | 2,280 | 3,910 | 1,353 | 17,264 |
| `quiet_app` | 30 | 7,728 | 7,225 | 1,756 | 30,646 |
| `slow_observer` | 30 | 2,746,721 | 13,970 | 2,726,355 | 2,790,382 |
| `trigger_storm` | 30 | 6,018 | 1,646 | 3,598 | 14,301 |


![Headline tick drift](headline_tick_drift.png)

## Peak resident set size per scenario

Peak RSS captured via `ProcessInfo.currentRss` sampled every 500 ms (every 250 ms in `long_running`). The package's memory footprint baseline; future refactors should not regress this without reason.

| Scenario | N | Median (MB) | IQR (MB) | Min (MB) | Max (MB) |
|---|---:|---:|---:|---:|---:|
| `flapping_network` | 30 | 74.88 | 1.86 | 27.91 | 77.19 |
| `long_running` | 30 | 54.90 | 4.36 | 29.02 | 79.11 |
| `many_subscribers` | 90 | 61.61 | 1.34 | 25.89 | 66.48 |
| `quiet_app` | 30 | 73.51 | 0.66 | 27.58 | 74.06 |
| `slow_observer` | 30 | 60.69 | 0.11 | 25.97 | 66.48 |
| `trigger_storm` | 30 | 71.68 | 0.39 | 26.42 | 71.91 |


![Memory peak RSS](memory_peak_rss.png)

## Stability: noise floor across scenarios (slow_observer excluded)

Same metric as the headline chart, but with the `slow_observer` outlier excluded so the y-scale is readable. A narrow box = the metric is reproducible iteration-to-iteration.

| Scenario | N | Median (us) | IQR (us) | Min (us) | Max (us) |
|---|---:|---:|---:|---:|---:|
| `flapping_network` | 30 | 6,510 | 5,504 | 3,545 | 36,553 |
| `long_running` | 30 | 40,178 | 18,320 | 16,822 | 54,649 |
| `many_subscribers` | 90 | 2,280 | 3,910 | 1,353 | 17,264 |
| `quiet_app` | 30 | 7,728 | 7,225 | 1,756 | 30,646 |
| `trigger_storm` | 30 | 6,018 | 1,646 | 3,598 | 14,301 |


![Scenario stability](scenario_stability.png)

## Subscriber scaling: broadcast cost vs N listeners

From the `status_emission` micro (synchronous broadcast, isolated from the rest of the package). Production `InternetConnection` uses async-default broadcast where the producer pays a constant cost regardless of N; this chart isolates the per-listener *delivery* cost.

| Subscribers | N | Median (us/emit) | IQR (us) |
|---:|---:|---:|---:|
| 1 | 30 | 0.131 | 0.001 |
| 10 | 30 | 1.00 | 0.010 |
| 100 | 30 | 8.78 | 0.031 |


![Subscriber scaling](subscriber_scaling.png)
