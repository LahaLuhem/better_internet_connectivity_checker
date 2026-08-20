# Benchmark results

Captured **2026-08-20** against `0.2.0` at `0a2a848` on Dart SDK 3.13.0. N=30 iterations per scenario.

> Per-machine measurements. Numbers below reflect *this* machine (CPU, GC, OS scheduler, thermal state). Your numbers WILL differ - capture your own local baseline before measuring a code delta.

## Headline: worst-case event-loop stall per scenario

Longest single continuous window in which synchronous work blocked the event loop (gap between 1 ms heartbeats, minus the heartbeat interval). The `slow_observer` scenario wires a deliberately-misbehaving observer that sleeps 50 ms per callback, so its box should sit at ~50k us - the observer's own blocking time, which no dispatch strategy can mask on a single-threaded isolate. The other scenarios show the package's intrinsic noise floor.

| Scenario | N | Median (us) | IQR (us) | Min (us) | Max (us) |
|---|---:|---:|---:|---:|---:|
| `backoff_recovery` | 30 | 6,198 | 4,804 | 1,649 | 29,570 |
| `flapping_network` | 30 | 4,915 | 1,655 | 3,187 | 13,353 |
| `long_running` | 30 | 12,444 | 6,743 | 5,820 | 105,012 |
| `many_subscribers` | 90 | 5,068 | 4,203 | 1,100 | 19,206 |
| `quiet_app` | 30 | 5,614 | 2,066 | 2,887 | 10,821 |
| `slow_observer` | 30 | 110,298 | 3,186 | 103,052 | 119,700 |
| `trigger_storm` | 30 | 5,606 | 4,707 | 2,645 | 16,583 |


![Headline max stall](headline_max_stall.png)

## Event-loop blocked share per scenario

`blocked_duty_ratio` is total stalled time divided by the measured window - the duration-independent 'how bad is it overall' number. For `slow_observer` expect roughly delay / check-interval (~50%); everything else should be near zero.

| Scenario | N | Median (%) | IQR (%) | Min (%) | Max (%) |
|---|---:|---:|---:|---:|---:|
| `backoff_recovery` | 30 | 0.20% | 0.15% | 0.07% | 8.19% |
| `flapping_network` | 30 | 0.11% | 0.54% | 0.04% | 1.28% |
| `long_running` | 30 | 0.86% | 1.22% | 0.32% | 14.78% |
| `many_subscribers` | 90 | 0.80% | 0.86% | 0.04% | 2.76% |
| `quiet_app` | 30 | 0.59% | 0.57% | 0.14% | 1.76% |
| `slow_observer` | 30 | 55.01% | 0.37% | 54.46% | 56.28% |
| `trigger_storm` | 30 | 0.57% | 0.77% | 0.05% | 2.21% |

## Peak resident set size per scenario

Peak RSS captured via `ProcessInfo.currentRss` sampled every 500 ms (every 250 ms in `long_running`). The package's memory footprint baseline; future refactors should not regress this without reason.

| Scenario | N | Median (MB) | IQR (MB) | Min (MB) | Max (MB) |
|---|---:|---:|---:|---:|---:|
| `backoff_recovery` | 30 | 51.99 | 2.56 | 26.89 | 60.70 |
| `flapping_network` | 30 | 73.27 | 0.14 | 27.70 | 73.48 |
| `long_running` | 30 | 52.13 | 7.94 | 28.88 | 72.23 |
| `many_subscribers` | 90 | 41.91 | 19.64 | 25.88 | 66.44 |
| `quiet_app` | 30 | 51.31 | 18.02 | 27.64 | 73.00 |
| `slow_observer` | 30 | 60.19 | 0.16 | 25.91 | 66.62 |
| `trigger_storm` | 30 | 70.38 | 15.39 | 26.73 | 72.73 |


![Memory peak RSS](memory_peak_rss.png)

## Stability: noise floor across scenarios (slow_observer excluded)

Same metric as the headline chart, but with the `slow_observer` outlier excluded so the y-scale is readable. A narrow box = the metric is reproducible iteration-to-iteration.

| Scenario | N | Median (us) | IQR (us) | Min (us) | Max (us) |
|---|---:|---:|---:|---:|---:|
| `backoff_recovery` | 30 | 6,198 | 4,804 | 1,649 | 29,570 |
| `flapping_network` | 30 | 4,915 | 1,655 | 3,187 | 13,353 |
| `long_running` | 30 | 12,444 | 6,743 | 5,820 | 105,012 |
| `many_subscribers` | 90 | 5,068 | 4,203 | 1,100 | 19,206 |
| `quiet_app` | 30 | 5,614 | 2,066 | 2,887 | 10,821 |
| `trigger_storm` | 30 | 5,606 | 4,707 | 2,645 | 16,583 |


![Scenario stability](scenario_stability.png)

## Subscriber scaling: broadcast cost vs N listeners

From the `status_emission` micro (synchronous broadcast, isolated from the rest of the package). Production `InternetConnection` uses async-default broadcast where the producer pays a constant cost regardless of N; this chart isolates the per-listener *delivery* cost.

| Subscribers | N | Median (us/emit) | IQR (us) |
|---:|---:|---:|---:|
| 1 | 30 | 0.133 | 0.004 |
| 10 | 30 | 1.00 | 0.022 |
| 25 | 30 | 2.30 | 0.065 |
| 50 | 30 | 4.47 | 0.112 |
| 100 | 30 | 8.96 | 0.218 |


![Subscriber scaling](subscriber_scaling.png)
