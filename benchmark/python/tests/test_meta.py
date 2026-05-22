"""Tests for `bicc_bench.data.utils.meta`.

Focuses on the pure helpers (duration parsing, summary_metadata).
`current_git_sha` and `current_package_version` touch the filesystem /
subprocess - covered by the end-to-end smoke test in CI, not unit tests.
"""

from __future__ import annotations

import pytest

from bicc_bench.data.dtos.result_record import ResultRecord
from bicc_bench.data.utils.meta import (
    parse_duration_overrides,
    resolve_duration,
    summary_metadata,
)


class TestParseDurationOverrides:
    def test_none_returns_empty(self) -> None:
        assert parse_duration_overrides(None) == {}

    def test_empty_list_returns_empty(self) -> None:
        assert parse_duration_overrides([]) == {}

    def test_single_override(self) -> None:
        assert parse_duration_overrides(["quiet_app=30"]) == {"quiet_app": 30}

    def test_multiple_overrides(self) -> None:
        assert parse_duration_overrides(["a=1", "b=2", "c=3"]) == {"a": 1, "b": 2, "c": 3}

    def test_whitespace_in_scenario_name_stripped(self) -> None:
        assert parse_duration_overrides(["  quiet_app  =30"]) == {"quiet_app": 30}

    def test_missing_equals_exits(self) -> None:
        # CLI convenience: malformed input -> sys.exit(64), not a half-parsed dict.
        with pytest.raises(SystemExit) as exc_info:
            parse_duration_overrides(["malformed"])
        assert exc_info.value.code == 64

    def test_non_int_value_exits(self) -> None:
        with pytest.raises(SystemExit) as exc_info:
            parse_duration_overrides(["scenario=not_a_number"])
        assert exc_info.value.code == 64


class TestResolveDuration:
    def test_per_scenario_wins(self) -> None:
        result = resolve_duration(
            "quiet_app",
            global_override=99,
            per_scenario={"quiet_app": 7},
        )
        assert result == 7

    def test_global_override_when_no_per_scenario(self) -> None:
        result = resolve_duration(
            "quiet_app",
            global_override=99,
            per_scenario={},
        )
        assert result == 99

    def test_scenario_default_when_no_overrides(self) -> None:
        # SCENARIO_DURATIONS["quiet_app"] = 5
        result = resolve_duration(
            "quiet_app",
            global_override=None,
            per_scenario={},
        )
        assert result == 5

    def test_fallback_for_unknown_scenario(self) -> None:
        # FALLBACK_DURATION = 10
        result = resolve_duration(
            "scenario_we_dont_know_about",
            global_override=None,
            per_scenario={},
        )
        assert result == 10

    def test_global_override_of_zero_still_applies(self) -> None:
        # Edge case: --duration-seconds 0 should override the scenario default,
        # not fall through to it (0 is falsy in Python but is a valid override).
        result = resolve_duration(
            "quiet_app",
            global_override=0,
            per_scenario={},
        )
        assert result == 0


class TestSummaryMetadata:
    def test_empty_records(self) -> None:
        meta = summary_metadata([])
        assert meta["git_sha"] == "unknown"
        assert meta["package_version"] == "unknown"
        assert meta["sdk_version"] == "unknown"
        assert meta["iterations"] == "0"
        # date is "today" - just check it's non-empty + ISO-ish
        assert len(meta["date"]) == 10  # YYYY-MM-DD

    def test_extracts_from_first_record(
        self,
        sample_records: list[ResultRecord],
    ) -> None:
        meta = summary_metadata(sample_records)
        assert meta["git_sha"] == "abc1234"
        assert meta["package_version"] == "0.2.0"
        assert meta["sdk_version"] == "3.11.5"
        # quiet_app has 3 records (highest scalar count); status_emission is multi-record.
        assert meta["iterations"] == "3"

    def test_all_values_are_strings(
        self,
        sample_records: list[ResultRecord],
    ) -> None:
        # Downstream uses these in f-strings - everything must be str.
        meta = summary_metadata(sample_records)
        assert all(isinstance(v, str) for v in meta.values())
