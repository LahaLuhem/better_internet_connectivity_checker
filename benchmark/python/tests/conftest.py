"""Shared fixtures for the bicc_bench test suite.

Records are synthetic - no JSON file on disk - so tests stay self-contained
and the fixtures stay readable inline. Scenario names and metric names
mirror what real scenario binaries emit so tests exercise realistic shapes.
"""

from __future__ import annotations

from typing import Any

import pytest

from bicc_bench.data.dtos.result_record import ResultRecord

_COMMON_META: dict[str, Any] = {
    "sdk_version": "3.11.5",
    "package_version": "0.2.0",
    "git_sha": "abc1234",
    "started_at": "2026-05-22T10:00:00Z",
}


def _record(
    scenario: str,
    iteration: int,
    *,
    samples: dict[str, list[float]] | None = None,
    summary: dict[str, float] | None = None,
) -> ResultRecord:
    """Compose one synthetic record with the shared metadata block."""
    return {
        **_COMMON_META,
        "scenario": scenario,
        "iteration": iteration,
        "samples": samples or {},
        "summary": summary or {},
    }


@pytest.fixture
def sample_records() -> list[ResultRecord]:
    """A small, realistic set: 3 scenarios with mixed sample/summary shapes.

    - `quiet_app`        - 3 iterations, both raw samples and summary
    - `slow_observer`    - 2 iterations, huge drift (the bug we visualise)
    - `status_emission`  - 1 iteration x 3 subscriber counts (multi-record)
    """
    return [
        _record(
            "quiet_app",
            0,
            samples={
                "rss_bytes": [30_000_000, 31_000_000, 32_000_000],
                "tick_drift_microseconds": [100, 200, 300],
            },
            summary={
                "peak_rss_bytes": 32_000_000,
                "max_drift_microseconds": 300,
                "median_drift_microseconds": 200,
            },
        ),
        _record(
            "quiet_app",
            1,
            samples={
                "rss_bytes": [30_500_000, 31_500_000, 32_500_000],
                "tick_drift_microseconds": [110, 210, 310],
            },
            summary={
                "peak_rss_bytes": 32_500_000,
                "max_drift_microseconds": 310,
                "median_drift_microseconds": 210,
            },
        ),
        _record(
            "quiet_app",
            2,
            samples={
                "rss_bytes": [31_000_000, 32_000_000, 33_000_000],
                "tick_drift_microseconds": [120, 220, 320],
            },
            summary={
                "peak_rss_bytes": 33_000_000,
                "max_drift_microseconds": 320,
                "median_drift_microseconds": 220,
            },
        ),
        _record(
            "slow_observer",
            0,
            samples={"tick_drift_microseconds": [1_800_000, 1_850_000, 1_900_000]},
            summary={"max_drift_microseconds": 1_900_000, "median_drift_microseconds": 1_850_000},
        ),
        _record(
            "slow_observer",
            1,
            samples={"tick_drift_microseconds": [1_810_000, 1_860_000, 1_910_000]},
            summary={"max_drift_microseconds": 1_910_000, "median_drift_microseconds": 1_860_000},
        ),
        # status_emission emits one record per (iteration, subscriber_count).
        _record(
            "status_emission",
            0,
            samples={"microseconds_per_emission": [0.14]},
            summary={"subscriber_count": 1, "microseconds_per_emission": 0.14},
        ),
        _record(
            "status_emission",
            0,
            samples={"microseconds_per_emission": [1.05]},
            summary={"subscriber_count": 10, "microseconds_per_emission": 1.05},
        ),
        _record(
            "status_emission",
            0,
            samples={"microseconds_per_emission": [9.0]},
            summary={"subscriber_count": 100, "microseconds_per_emission": 9.0},
        ),
    ]


@pytest.fixture
def baseline_records() -> list[ResultRecord]:
    """Synthetic baseline run - quiet_app + slow_observer, 3 iterations each."""
    return [
        _record(
            "quiet_app",
            i,
            samples={"tick_drift_microseconds": [100 + i * 10, 200 + i * 10, 300 + i * 10]},
            summary={"max_drift_microseconds": 300 + i * 10},
        )
        for i in range(3)
    ] + [
        _record(
            "slow_observer",
            i,
            samples={"tick_drift_microseconds": [1_800_000 + i * 1000] * 3},
            summary={"max_drift_microseconds": 1_800_000 + i * 1000},
        )
        for i in range(3)
    ]


@pytest.fixture
def current_records() -> list[ResultRecord]:
    """Synthetic 'after-refactor' run - slow_observer drift collapses, quiet stays."""
    return [
        _record(
            "quiet_app",
            i,
            samples={"tick_drift_microseconds": [100 + i * 10, 200 + i * 10, 300 + i * 10]},
            summary={"max_drift_microseconds": 300 + i * 10},
        )
        for i in range(3)
    ] + [
        _record(
            "slow_observer",
            i,
            # Drift dropped 100x post-refactor.
            samples={"tick_drift_microseconds": [18_000 + i * 100] * 3},
            summary={"max_drift_microseconds": 18_000 + i * 100},
        )
        for i in range(3)
    ]
