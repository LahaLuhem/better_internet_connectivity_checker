"""Tests for `bicc_bench.data.utils.meta`.

Covers the pure helpers (duration parsing, summary_metadata, resolve)
plus the environment readers (`current_git_sha`, `current_package_version`)
- the latter use the real repo for happy-paths and monkeypatch subprocess /
PROJECT_ROOT for the fallback branches.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest

from bicc_bench.data.dtos.result_record import ResultRecord
from bicc_bench.data.utils.meta import (
    current_git_sha,
    current_package_version,
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


class TestCurrentGitSha:
    def test_returns_short_sha_in_real_repo(self) -> None:
        # Tests run inside the bicc repo - git rev-parse succeeds and
        # returns a non-empty short SHA (7+ hex chars).
        sha = current_git_sha()
        assert sha != "unknown"
        assert len(sha) >= 7
        assert all(c in "0123456789abcdef" for c in sha)

    def test_returns_unknown_when_git_missing(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        def raise_file_not_found(*_args: object, **_kwargs: object) -> object:
            raise FileNotFoundError("mocked: git binary not on PATH")

        monkeypatch.setattr(subprocess, "run", raise_file_not_found)
        assert current_git_sha() == "unknown"

    def test_returns_unknown_on_called_process_error(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        def raise_called_process_error(*_args: object, **_kwargs: object) -> object:
            raise subprocess.CalledProcessError(returncode=128, cmd=["git"])

        monkeypatch.setattr(subprocess, "run", raise_called_process_error)
        assert current_git_sha() == "unknown"

    def test_returns_unknown_on_blank_stdout(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        # git can in theory exit 0 with empty stdout - coerce to "unknown"
        # rather than returning "" downstream.
        class _Result:
            stdout = "\n"

        monkeypatch.setattr(subprocess, "run", lambda *_a, **_kw: _Result())
        assert current_git_sha() == "unknown"


class TestCurrentPackageVersion:
    def test_returns_version_from_real_pubspec(self) -> None:
        # Tests run inside the bicc repo - the root pubspec.yaml has a
        # `version:` line. Should return a non-"unknown" semver-shaped string.
        version = current_package_version()
        assert version != "unknown"
        # semver-ish: starts with a digit
        assert version[0].isdigit()

    def test_returns_unknown_when_pubspec_missing(
        self,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: Path,
    ) -> None:
        # Point PROJECT_ROOT at an empty tmp dir - no pubspec.yaml present.
        monkeypatch.setattr("bicc_bench.data.utils.meta.PROJECT_ROOT", tmp_path)
        assert current_package_version() == "unknown"

    def test_returns_unknown_when_version_line_absent(
        self,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: Path,
    ) -> None:
        # pubspec exists but has no `version:` line - line-prefix scan
        # falls through to the trailing "unknown".
        (tmp_path / "pubspec.yaml").write_text("name: fake_pkg\ndescription: no version here\n")
        monkeypatch.setattr("bicc_bench.data.utils.meta.PROJECT_ROOT", tmp_path)
        assert current_package_version() == "unknown"

    def test_parses_version_from_synthetic_pubspec(
        self,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: Path,
    ) -> None:
        (tmp_path / "pubspec.yaml").write_text("name: fake\nversion: 1.2.3\nother: 99\n")
        monkeypatch.setattr("bicc_bench.data.utils.meta.PROJECT_ROOT", tmp_path)
        assert current_package_version() == "1.2.3"
