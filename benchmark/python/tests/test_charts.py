"""Tests for `bicc_bench.data.utils.charts`.

Pixel content stays untested, which is what `.ai/AGENTS.md` means by brittle.
Byte *reproducibility* is a different claim and worth a gate: the four report
PNGs under `benchmark/reports/` are committed, so a renderer drawing from an
unseeded RNG rewrites them on every `report` run and buries the real diffs.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path
from typing import Final

import matplotlib
import polars as pl
import pytest

from bicc_bench.data.dtos.result_record import ResultRecord, flatten_records
from bicc_bench.data.utils import charts

matplotlib.use("Agg")

ReportPlot = Callable[[pl.DataFrame, Path], Path | None]

COMMITTED_REPORT_PLOTS: Final[list[ReportPlot]] = [
    charts.plot_headline_max_stall,
    charts.plot_memory_peak_rss_delta,
    charts.plot_scenario_stability,
    charts.plot_subscriber_scaling,
]
"""The renderers `cmd_report` writes to `benchmark/reports/`, in that order."""


def _frame(records: list[ResultRecord]) -> pl.DataFrame:
    """Mirror how `cmd_report` builds the frame it hands the renderers."""
    return pl.DataFrame(flatten_records(records), infer_schema_length=None)


class TestRenderDeterminism:
    @pytest.mark.parametrize("plot", COMMITTED_REPORT_PLOTS, ids=lambda p: p.__name__)
    def test_same_data_renders_the_same_bytes(
        self,
        plot: ReportPlot,
        sample_records: list[ResultRecord],
        tmp_path: Path,
    ) -> None:
        charts.set_default_theme()
        frame = _frame(sample_records)

        first = plot(frame, tmp_path / "first.png")
        second = plot(frame, tmp_path / "second.png")

        assert first is not None, "fixture stopped feeding this chart any data"
        assert second is not None
        assert first.read_bytes() == second.read_bytes()

    def test_changed_data_renders_different_bytes(
        self,
        sample_records: list[ResultRecord],
        tmp_path: Path,
    ) -> None:
        """Without this, the equality above would also hold for a renderer that
        ignored its input, or fell back to the 'no data' placeholder."""
        charts.set_default_theme()
        nudged = [
            {**rec, "summary": {**rec["summary"], "max_stall_microseconds": 9_999}}
            if rec["scenario"] == "quiet_app"
            else rec
            for rec in sample_records
        ]

        before = charts.plot_scenario_stability(_frame(sample_records), tmp_path / "before.png")
        after = charts.plot_scenario_stability(_frame(nudged), tmp_path / "after.png")

        assert before.read_bytes() != after.read_bytes()
