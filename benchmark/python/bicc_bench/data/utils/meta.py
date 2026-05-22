"""Metadata helpers - capture context about a run (git, version, duration).

These read from the working environment (git, pubspec.yaml) or transform
CLI inputs (duration overrides). Pure-ish - subprocess + file I/O - but
all deterministic for a given environment.
"""

from __future__ import annotations

import subprocess
import sys
from datetime import datetime, timezone

from bicc_bench.config import FALLBACK_DURATION, PROJECT_ROOT, SCENARIO_DURATIONS
from bicc_bench.data.dtos.result_record import ResultRecord
from bicc_bench.data.utils.stats import records_per_scenario


def current_git_sha() -> str:
    """Return the current git HEAD short SHA, or 'unknown' if git is unavailable."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "unknown"
    return result.stdout.strip() or "unknown"


def current_package_version() -> str:
    """Read the `version:` field from the root `pubspec.yaml`.

    Avoids pulling in `pyyaml` for one field - a line-prefix scan is enough.
    Returns 'unknown' if pubspec is missing or the field isn't present.
    """
    pubspec = PROJECT_ROOT / "pubspec.yaml"
    if not pubspec.exists():
        return "unknown"
    for line in pubspec.read_text().splitlines():
        if line.startswith("version:"):
            return line.split(":", 1)[1].strip()
    return "unknown"


def summary_metadata(records: list[ResultRecord]) -> dict[str, str]:
    """Pull captured-at + version metadata from the first record for the header.

    All values stringified - this dict feeds straight into f-strings in
    SUMMARY.md / COMPARE.md. `date` is "today" (UTC), not the per-record
    `started_at` - we want one date per report, not per-record noise.
    """
    first = records[0] if records else {}
    return {
        "date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "git_sha": str(first.get("git_sha", "unknown")),
        "package_version": str(first.get("package_version", "unknown")),
        "sdk_version": str(first.get("sdk_version", "unknown")),
        "iterations": str(records_per_scenario(records)),
    }


def parse_duration_overrides(raw: list[str] | None) -> dict[str, int]:
    """Parse `--duration scenario=N` flag values into a `{scenario: seconds}` map.

    Exits the process on malformed input (CLI convenience - callers expect
    a clean dict or process death, never a half-parsed map).
    """
    if not raw:
        return {}
    out: dict[str, int] = {}
    for entry in raw:
        if "=" not in entry:
            print(f"--duration expects scenario=N, got: {entry}", file=sys.stderr)
            sys.exit(64)
        scenario, value = entry.split("=", 1)
        try:
            out[scenario.strip()] = int(value)
        except ValueError:
            print(f"--duration value must be int, got: {value}", file=sys.stderr)
            sys.exit(64)
    return out


def resolve_duration(
    scenario: str,
    *,
    global_override: int | None,
    per_scenario: dict[str, int],
) -> int:
    """Per-scenario duration resolution: per-scenario > global > map default > fallback."""
    if scenario in per_scenario:
        return per_scenario[scenario]
    if global_override is not None:
        return global_override
    return SCENARIO_DURATIONS.get(scenario, FALLBACK_DURATION)
