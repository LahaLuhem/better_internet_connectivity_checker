# `benchmark/` — performance & memory measurement framework

Reproducible benchmarks for `better_internet_connectivity_checker`. Used to
empirically verify perf/memory claims before they ship in a release — no
"trust me, it's faster".

## Layout

```
benchmark/
├── README.md                  this file
├── harness/                   shared Dart utilities for both layers
├── micro/                     benchmark_harness-based micro-benches
├── scenarios/                 long-running stateful scenarios
├── python/                    orchestration + analysis + reporting
├── charts/
│   └── reference/             committed maintainer reference charts (PNG + SUMMARY.md)
├── results-local/             contributor-local run outputs (gitignored)
├── results/                   legacy run-output dir (gitignored; kept for older workflows)
└── build/                     AOT-compiled scenario exes (gitignored)
```

The `benchmark/` directory is excluded from the published pub.dev tarball via
[`.pubignore`](../.pubignore) — none of the source ships to downstream users.
The reference PNGs under `charts/reference/` are referenced from the package
README via GitHub raw URLs (see [Reference charts](#reference-charts) below).

## Two layers

| Layer | Purpose | Tool |
|---|---|---|
| **Micro** (`micro/`) | Coordinator-only overhead — event dispatch, dedup, scheduling. Probe is faked (instant). Isolates µs-scale signal from network noise. | [`package:benchmark_harness`](https://pub.dev/packages/benchmark_harness) |
| **Scenario** (`scenarios/`) | Realistic client usage over time. Full stack with localhost HTTP server. Long-running, stateful. | Custom Dart programs, AOT-compiled, orchestrated by Python |

## Prerequisites

- Dart SDK matching the project's [`.fvmrc`](../.fvmrc) pin. Different SDK = baseline JSON must be re-captured.
- [`uv`](https://docs.astral.sh/uv/) for the Python orchestrator (`brew install uv` on macOS, or see upstream install docs). Pins Python via `python/.python-version` (3.12), creates `.venv`, manages deps from `python/pyproject.toml`, locks them in `python/uv.lock` (checked in for reproducibility).
- `dart pub get` at the repo root (picks up `benchmark_harness` from `dev_dependencies`).
- `cd benchmark/python && uv sync` (one-time — creates `.venv`, installs `numpy`, `scipy`, `polars`, `matplotlib`, `seaborn`, `jinja2`, `ruff`). Seaborn pulls `pandas` transitively — used only at the seaborn-API boundary in the chart helpers; everything else stays in polars.

## Running

All commands below run from `benchmark/python/`. `uv run` automatically uses the project's `.venv`.

```bash
# 1. Build all scenario .dart files to AOT exes.
#    Parallelised across cores; cap with --workers if you're memory-bound.
uv run python run.py build

# 2. Run all scenarios + micro-benches, default N=10 iterations.
#    Each scenario binary now accepts --iterations and emits N records from
#    one subprocess invocation — saves N-1 process startups per scenario.
uv run python run.py run --iterations 10 --out=../results-local/current/

# 3. Compare two runs (Mann-Whitney U significance test).
uv run python run.py compare ../results-local/baseline/aggregated.json \
                              ../results-local/current/aggregated.json

# 4. Generate PNG charts + SUMMARY.md from aggregated.json.
#    Default output: <aggregated parent>/charts/ (next to the JSON, gitignored).
uv run python run.py report ../results-local/current/aggregated.json
```

### Parallelism — what is and isn't parallel

| Stage | Parallel? | Why |
|---|---|---|
| `build` (AOT compile) | Yes (threads) | Compilation does no measurement; speed up freely. |
| `run` (measurement) | **No** | CPU contention destroys the signal. Iterations stay serial within a scenario; scenarios stay serial across each other. |
| `compare` / `report` | N/A | I/O-bound; fast already. |

Iteration *batching* (one subprocess per scenario instead of per iteration)
is a different optimisation — it preserves measurement isolation because
each iteration still runs alone in the process, with `forceGc` + a 100 ms
settle between iterations.

### Linting the Python side

The orchestrator is held to the same bar as the Dart side. Run before committing:

```bash
cd benchmark/python
uv run ruff format .       # format
uv run ruff check .        # lint
```

Config lives in [`python/pyproject.toml`](python/pyproject.toml) under `[tool.ruff]`.

## Methodology — non-negotiable

These rules make results reproducible. Violating any of them means the numbers
can't be defended.

- **AOT compile**, not JIT. `dart compile exe` produces deterministic warmup
  characteristics; `dart run` does not.
- **SDK pinned** via [`.fvmrc`](../.fvmrc). Any bump invalidates the baseline.
- **N ≥ 10 iterations** per scenario. Report **median + IQR**, never mean —
  GC outliers skew means heavily on a single-threaded VM.
- **Mann-Whitney U** (`scipy.stats.mannwhitneyu`) for significance claims.
  Nonparametric, robust to GC outliers, doesn't assume normality. p < 0.05
  for "significant difference" claims.
- **Warmup iterations discarded** — first 2 of every 10.
- **GC forced before each measurement window** via a pressure-allocation
  helper (`harness/result_writer.dart`'s `forceGc()`).
- **AC power, no competing apps.** Dart VM is single-threaded; CPU
  contention shows up directly as wall-clock drift.
- **Localhost only** — no DNS, no real network. All HTTP probes hit a
  configurable `HttpServer.bind('127.0.0.1', 0)` (`harness/local_http_server.dart`).

## Metrics tracked

See [`~/Desktop/bicc-benchmark-plan-2026-05-21.md`](file:///Users/mehul/Desktop/bicc-benchmark-plan-2026-05-21.md)
§3 for the finalised metrics list. Summary:

- **Memory**: static footprint, active footprint, allocation rate per tick, RSS delta over long runs.
- **Time**: coordinator overhead per tick, tier-1/tier-2 emission latency, per-event cost vs subscribers, dispose latency.
- **Concurrency**: throughput ceiling, trigger storm response, subscriber-count scaling.
- **Event-loop blocking**: max sync-chunk duration via `tick_drift_meter.dart`.

The **headline metric** is the `slow_observer` scenario — measures whether a
slow observer/subscriber stalls the scheduler. This is the bug the upcoming
event-bus refactor fixes; the before/after chart for this scenario is the PR's
main exhibit.

## Result JSON schema

Each scenario writes one JSON file per run, conforming to:

```json
{
  "scenario": "<name>",
  "iteration": <int>,
  "sdk_version": "<string>",
  "package_version": "<string>",
  "git_sha": "<string>",
  "started_at": "<ISO-8601 UTC>",
  "samples": {
    "<metric>": [<numbers>, ...]
  },
  "summary": {
    "<aggregate>": <number>
  }
}
```

See `harness/result_writer.dart` for the canonical writer.

## When to re-baseline

The baseline JSON in `results/baseline-dart-<sdk>.json` is the anchor for all
"this PR makes things X% better" claims. Re-capture it when:

- The Dart SDK pin moves (`.fvmrc` change).
- A non-perf-related change to `lib/src/internet_connection.dart` lands that
  could affect the numbers (e.g. a logic fix that adds a code path).
- Hardware changes (running on a different machine — but baselines are
  machine-specific anyway; check the machine identifier in the JSON header).

Document each baseline capture in this README (date, machine, SDK version,
git SHA).

## Baselines — per-machine, never committed

There is no canonical baseline JSON in this repo. Perf numbers are sensitive
to CPU, GC tuning, OS scheduler, thermal state, and other apps competing for
the core — comparing across machines is misleading. Every contributor
captures their own baseline locally before measuring the delta from a change.

`benchmark/results/` and `benchmark/results-local/` are both gitignored.
Capture metadata (SDK version, git SHA, capture date) is embedded in every
record so each file is self-describing on its own machine.

### Per-contributor workflow

```bash
cd benchmark/python

# 1. Capture YOUR baseline on a clean working tree.
uv run python run.py run --iterations 10 --out ../results-local/baseline/

# 2. Make your change. Commit it on a branch.

# 3. Capture a new run with the change applied.
uv run python run.py run --iterations 10 --out ../results-local/after/

# 4. Compare YOUR baseline to YOUR after-run (same machine, same SDK).
uv run python run.py compare \
  ../results-local/baseline/aggregated.json \
  ../results-local/after/aggregated.json
```

The output flags every (scenario, metric) where the after-run differs
significantly (p < 0.05, Mann-Whitney U). Paste the relevant rows + a chart
into the PR description as evidence.

### Charts

`report` renders four PNGs + a `SUMMARY.md` alongside the JSON:

- `headline_tick_drift.png` — box plot of `max_drift_microseconds` per
  scenario on a log y-axis. `slow_observer` should tower above the rest;
  that gap is the bug the upcoming refactor fixes.
- `memory_peak_rss.png` — peak RSS per scenario in MB.
- `scenario_stability.png` — `max_drift_microseconds` per scenario with
  `slow_observer` excluded so the noise floor is readable. Narrow boxes =
  reproducible.
- `subscriber_scaling.png` — broadcast cost per emission vs subscriber
  count, from the `status_emission` micro.

`SUMMARY.md` has a summary table above each chart, formatted so the
maintainer can drop the relevant sections into the package README.

## Reference charts

`benchmark/charts/reference/` is the **committed** maintainer reference
set. These PNGs are linked from the package README to give pub.dev viewers
a visual sense of the package's perf shape without having to clone +
build. Update them by passing `--reference` to `report`:

```bash
# (after capturing a clean baseline + producing aggregated.json)
uv run python run.py report ../results-local/baseline/aggregated.json --reference
```

This writes to `benchmark/charts/reference/`. Treat the regeneration as
an explicit step — only the maintainer should run it, only after a
deliberate baseline capture. Contributor runs land in `results-local/`
and never touch the reference set unless `--reference` is passed.

<details>
<summary><strong>Reference run — 2026-05-22, Apple Silicon macOS, Dart 3.11.5, N=10</strong> (maintainer's machine; your numbers WILL differ)</summary>

These figures are a sanity check, not a target. "Am I in the right ballpark?"
not "did I beat the baseline?". Treat them as approximate.

| Scenario / N | Metric | Median |
|---|---|---|
| **`slow_observer`** | **`max_drift_microseconds`** | **1,790,228 µs (~1.79 s)** |
| `slow_observer` | `median_drift_microseconds` | 927,326 µs (~927 ms) |
| `quiet_app` | `max_drift_microseconds` | 4,049 µs (~4 ms) |
| `quiet_app` | `dispose_microseconds` | 7.5 µs |
| `check_once_overhead` (micro) | `microseconds_per_check` | 0.40 µs |
| `observer_dispatch` (micro) | `microseconds_per_dispatch` | 0.01 µs |
| `status_emission` N=1 (micro) | `microseconds_per_emission` | 0.13 µs |
| `status_emission` N=10 (micro) | `microseconds_per_emission` | 1.02 µs |
| `status_emission` N=100 (micro) | `microseconds_per_emission` | 8.95 µs |
| `trigger_storm` | `emissions_per_trigger` | 0.002 |
| `many_subscribers` N=100 | `max_drift_microseconds` | 8,404 µs |
| `flapping_network` (9 s) | `emission_count` | 3 (2 reachable + 1 unreachable) |
| `long_running` (30 s smoke) | `rss_growth_bytes_per_minute` | ~35 MB/min (dominated by startup) |

The `slow_observer.max_drift_microseconds` figure (~1.79 s of sustained
scheduler stall) is the empirical proof of the bug the upcoming refactor
fixes — on this machine, on this SDK. Your machine will see a comparable
order of magnitude but a different exact number.

</details>
