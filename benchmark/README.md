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
├── results/                   checked-in baseline JSONs (one per SDK ver)
└── build/                     AOT-compiled scenario exes (gitignored)
```

The `benchmark/` directory is excluded from the published pub.dev tarball via
[`.pubignore`](../.pubignore) — none of these ship to downstream users.

## Two layers

| Layer | Purpose | Tool |
|---|---|---|
| **Micro** (`micro/`) | Coordinator-only overhead — event dispatch, dedup, scheduling. Probe is faked (instant). Isolates µs-scale signal from network noise. | [`package:benchmark_harness`](https://pub.dev/packages/benchmark_harness) |
| **Scenario** (`scenarios/`) | Realistic client usage over time. Full stack with localhost HTTP server. Long-running, stateful. | Custom Dart programs, AOT-compiled, orchestrated by Python |

## Prerequisites

- Dart SDK matching the project's [`.fvmrc`](../.fvmrc) pin. Different SDK = baseline JSON must be re-captured.
- [`uv`](https://docs.astral.sh/uv/) for the Python orchestrator (`brew install uv` on macOS, or see upstream install docs). Pins Python via `python/.python-version` (3.12), creates `.venv`, manages deps from `python/pyproject.toml`, locks them in `python/uv.lock` (checked in for reproducibility).
- `dart pub get` at the repo root (picks up `benchmark_harness` from `dev_dependencies`).
- `cd benchmark/python && uv sync` (one-time — creates `.venv`, installs `numpy`, `scipy`, `polars`, `matplotlib`, `jinja2`, `ruff`).

## Running

All commands below run from `benchmark/python/`. `uv run` automatically uses the project's `.venv`.

```bash
# 1. Build all scenario .dart files to AOT exes
uv run python run.py build

# 2. Run all scenarios + micro-benches, default N=10 iterations
uv run python run.py run --out=../results-local/current/

# 3. Compare against baseline (Mann-Whitney U significance test)
uv run python run.py compare ../results/baseline-dart-<sdk>.json ../results-local/current/aggregated.json

# 4. Generate HTML report with matplotlib charts
uv run python run.py report ../results-local/current/aggregated.json --out=report.html
```

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

## Baselines

_To be populated by Phase 2 of the benchmark plan._
