"""Tests for `bicc_bench.data.utils.io`.

Filesystem-touching helpers are tested via `tmp_path`. Argparse-namespace
helpers use a small ad-hoc namespace stub - no need for real argparse.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from bicc_bench.config import (
    BENCHMARK_DIR,
    MICRO_DIR,
    PROJECT_ROOT,
    PYTHON_DIR,
    REPORTS_DIR,
    SCENARIOS_DIR,
)
from bicc_bench.data.utils.io import (
    discover_sources,
    filter_by_name,
    load_aggregated,
    resolve_outdir,
)


class TestFilterByName:
    def test_none_passes_through(self) -> None:
        paths = [Path("a"), Path("b"), Path("c")]
        assert filter_by_name(paths, None) == paths

    def test_empty_passes_through(self) -> None:
        paths = [Path("a"), Path("b")]
        assert filter_by_name(paths, []) == paths

    def test_restricts_by_stem(self) -> None:
        paths = [Path("foo"), Path("bar"), Path("baz")]
        assert filter_by_name(paths, ["foo", "baz"]) == [Path("foo"), Path("baz")]

    def test_unknown_names_filtered_silently(self) -> None:
        # Unknown names don't error - they just don't match anything.
        paths = [Path("foo"), Path("bar")]
        assert filter_by_name(paths, ["nonexistent"]) == []

    def test_order_preserved_from_input(self) -> None:
        paths = [Path("z"), Path("a"), Path("m")]
        # Output keeps the input order, NOT the wanted-list order.
        assert filter_by_name(paths, ["a", "z", "m"]) == [Path("z"), Path("a"), Path("m")]


class TestResolveOutdir:
    def test_default_is_reports_dir(self) -> None:
        args = argparse.Namespace(out=None)
        assert resolve_outdir(args) == REPORTS_DIR

    def test_override_resolved_to_absolute(self, tmp_path: Path) -> None:
        rel = "some/relative/path"
        args = argparse.Namespace(out=rel)
        result = resolve_outdir(args)
        # Result is absolute even though input was relative.
        assert result.is_absolute()
        assert result.name == "path"

    def test_absolute_override_preserved(self, tmp_path: Path) -> None:
        args = argparse.Namespace(out=str(tmp_path))
        assert resolve_outdir(args) == tmp_path


class TestPathConstants:
    """The path constants in `config.py` resolve relative to `THIS_FILE`.

    An off-by-one in the `.parent.parent.[parent]` chain points the constants
    at completely wrong directories and silently breaks `build` / `run` -
    the symptom is `discover_sources()` returning empty and `cmd_build`
    printing "no scenario or micro sources to build (yet)". Pin the
    relationships here so that class of bug fails loudly in CI instead.
    """

    def test_python_dir_contains_this_test_file(self) -> None:
        # If PYTHON_DIR is wrong, it won't contain `tests/test_io.py`.
        assert (PYTHON_DIR / "tests" / "test_io.py").exists()

    def test_benchmark_dir_contains_scenarios_subdir(self) -> None:
        assert (BENCHMARK_DIR / "scenarios").is_dir()

    def test_python_dir_is_one_below_benchmark_dir(self) -> None:
        assert PYTHON_DIR.parent == BENCHMARK_DIR

    def test_benchmark_dir_is_one_below_project_root(self) -> None:
        assert BENCHMARK_DIR.parent == PROJECT_ROOT

    def test_project_root_has_pubspec(self) -> None:
        # The Dart project root is identifiable by pubspec.yaml.
        assert (PROJECT_ROOT / "pubspec.yaml").is_file()

    def test_scenarios_dir_exists_and_has_dart_files(self) -> None:
        assert SCENARIOS_DIR.is_dir()
        assert any(SCENARIOS_DIR.glob("*.dart"))

    def test_micro_dir_exists_and_has_dart_files(self) -> None:
        assert MICRO_DIR.is_dir()
        assert any(MICRO_DIR.glob("*.dart"))


class TestDiscoverSources:
    """End-to-end check that `discover_sources` walks real scenario dirs.

    Complements the path-constant tests above: even if the path constants
    are right, a broken `discover_sources` would still leave `cmd_build`
    silently empty. Pin both.
    """

    def test_yields_known_scenarios(self) -> None:
        stems = {p.stem for p in discover_sources()}
        # The full scenario + micro list lives in `scenarios/` and `micro/`.
        # If this set ever shrinks the build will silently skip whatever's
        # missing - flag it here so adds/removes are conscious changes.
        expected = {
            "quiet_app",
            "slow_observer",
            "flapping_network",
            "trigger_storm",
            "many_subscribers",
            "long_running",
            "check_once_overhead",
            "observer_dispatch",
            "status_emission",
        }
        missing = expected - stems
        assert not missing, f"discover_sources missed: {missing}"


class TestLoadAggregated:
    def test_roundtrip(self, tmp_path: Path) -> None:
        records = [
            {"scenario": "x", "iteration": 0, "samples": {}, "summary": {"a": 1}},
            {"scenario": "y", "iteration": 0, "samples": {}, "summary": {"b": 2}},
        ]
        json_path = tmp_path / "aggregated.json"
        json_path.write_text(json.dumps(records))
        loaded = load_aggregated(json_path)
        assert loaded == records

    def test_accepts_string_path(self, tmp_path: Path) -> None:
        json_path = tmp_path / "data.json"
        json_path.write_text("[]")
        assert load_aggregated(str(json_path)) == []
