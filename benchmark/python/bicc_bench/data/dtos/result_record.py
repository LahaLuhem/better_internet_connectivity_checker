"""Result-record type alias + the canonical record-flatten helper.

`ResultRecord` is the in-memory shape of one JSON object emitted by a
scenario binary. We narrow `dict[str, Any]` rather than reaching for
TypedDict / pydantic - the schema is internal and stable, validation
ceremony adds no value for a tool we control end-to-end.
"""

from __future__ import annotations

from typing import Any

# One JSON-decoded record from `<scenario>/iterations.json`. See
# `harness/result_writer.dart` for the writer; the shape is:
#
#   {
#     "scenario": str,
#     "iteration": int,
#     "sdk_version": str,
#     "package_version": str,
#     "git_sha": str,
#     "started_at": ISO-8601 str,
#     "samples": dict[str, list[number]],   # raw per-tick measurements
#     "summary": dict[str, number],          # pre-computed aggregates
#   }
ResultRecord = dict[str, Any]


def flatten_records(records: list[ResultRecord]) -> list[dict[str, Any]]:
    """Flatten each record's `summary` block into a single row.

    Per-iteration raw `samples` arrays stay in the record; for chart
    rendering we use the pre-computed summary metrics (median, peak, etc).
    Metadata columns (`scenario`, `iteration`, `git_sha`, ...) always
    come first so they survive even when a record is missing a `summary`.
    """
    out: list[dict[str, Any]] = []
    for rec in records:
        flat: dict[str, Any] = {
            "scenario": rec.get("scenario", "?"),
            "iteration": rec.get("iteration", -1),
            "git_sha": rec.get("git_sha", "?"),
            "package_version": rec.get("package_version", "?"),
            "sdk_version": rec.get("sdk_version", "?"),
        }
        summary: dict[str, Any] = rec.get("summary", {})
        flat.update(summary)
        out.append(flat)
    return out
