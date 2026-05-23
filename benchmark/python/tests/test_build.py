"""Tests for `bicc_bench.subcommands.build` freshness helpers.

The build subcommand's main work is calling `dart compile exe`, which we do
not exercise here (slow + depends on Dart being installed). Instead we test
the pure-Python decision logic that picks which sources need rebuilding -
the part that was historically wrong (`out.exists()`-only check skipped
every rebuild after the first).
"""

from __future__ import annotations

import os
from pathlib import Path

import pytest

from bicc_bench.subcommands import build as build_mod
from bicc_bench.subcommands.build import _is_exe_fresh, _max_source_mtime


class TestIsExeFresh:
    def test_nonexistent_exe_is_stale(self, tmp_path: Path) -> None:
        out = tmp_path / "does_not_exist"
        assert not _is_exe_fresh(out, max_src_mtime=12_345.0)

    def test_exe_newer_than_sources_is_fresh(self, tmp_path: Path) -> None:
        out = tmp_path / "exe"
        out.write_bytes(b"")
        os.utime(out, (20_000.0, 20_000.0))

        assert _is_exe_fresh(out, max_src_mtime=10_000.0)

    def test_exe_older_than_sources_is_stale(self, tmp_path: Path) -> None:
        out = tmp_path / "exe"
        out.write_bytes(b"")
        os.utime(out, (10_000.0, 10_000.0))

        assert not _is_exe_fresh(out, max_src_mtime=20_000.0)

    def test_exe_equal_to_sources_is_fresh(self, tmp_path: Path) -> None:
        out = tmp_path / "exe"
        out.write_bytes(b"")
        os.utime(out, (12_345.0, 12_345.0))

        assert _is_exe_fresh(out, max_src_mtime=12_345.0)


class TestMaxSourceMtime:
    def test_returns_zero_when_no_roots_exist(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        monkeypatch.setattr(build_mod, "_SOURCE_ROOTS", [tmp_path / "missing"])

        assert _max_source_mtime() == 0.0

    def test_returns_zero_when_roots_have_no_dart_files(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        empty = tmp_path / "empty"
        empty.mkdir()
        (empty / "readme.txt").write_text("not a .dart file")
        monkeypatch.setattr(build_mod, "_SOURCE_ROOTS", [empty])

        assert _max_source_mtime() == 0.0

    def test_picks_max_across_a_single_root(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        root = tmp_path / "lib"
        root.mkdir()
        (root / "old.dart").write_text("")
        os.utime(root / "old.dart", (1_000.0, 1_000.0))
        (root / "new.dart").write_text("")
        os.utime(root / "new.dart", (5_000.0, 5_000.0))
        monkeypatch.setattr(build_mod, "_SOURCE_ROOTS", [root])

        assert _max_source_mtime() == 5_000.0

    def test_picks_global_max_across_roots(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        a = tmp_path / "a"
        b = tmp_path / "b"
        a.mkdir()
        b.mkdir()
        (a / "x.dart").write_text("")
        os.utime(a / "x.dart", (1_000.0, 1_000.0))
        (b / "y.dart").write_text("")
        os.utime(b / "y.dart", (9_000.0, 9_000.0))
        monkeypatch.setattr(build_mod, "_SOURCE_ROOTS", [a, b])

        assert _max_source_mtime() == 9_000.0

    def test_recurses_into_nested_directories(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        root = tmp_path / "lib"
        nested = root / "src" / "internal"
        nested.mkdir(parents=True)
        (nested / "deep.dart").write_text("")
        os.utime(nested / "deep.dart", (7_000.0, 7_000.0))
        monkeypatch.setattr(build_mod, "_SOURCE_ROOTS", [root])

        assert _max_source_mtime() == 7_000.0

    def test_ignores_non_dart_files(
        self,
        tmp_path: Path,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        root = tmp_path / "lib"
        root.mkdir()
        (root / "a.dart").write_text("")
        os.utime(root / "a.dart", (1_000.0, 1_000.0))
        (root / "b.txt").write_text("")
        os.utime(root / "b.txt", (9_999.0, 9_999.0))
        monkeypatch.setattr(build_mod, "_SOURCE_ROOTS", [root])

        # .txt is ignored; .dart wins even though it has the older mtime.
        assert _max_source_mtime() == 1_000.0
