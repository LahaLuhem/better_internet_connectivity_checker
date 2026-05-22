# `benchmark/python/` — agent brief

Tool-agnostic brief for any coding agent (Copilot, Cursor, Codex, Claude Code,
…) working in the Python orchestrator. The parent project is a pure Dart
package; this directory is the only Python surface and exists purely as
maintainer-only tooling (excluded from `dart pub publish`).

## Style: Python as strongly typed

House rules — Python written closer to typed Dart than to dynamic-Python idiom:

- **Annotate every function signature and every module-level constant.**
  No bare `def foo(x)`. No bare `FOO = 10`.
- **Use `Final` for module-level constants** and anything that shouldn't be
  reassigned: `DEFAULT_ITERATIONS: Final[int] = 10`.
- **Make nullability explicit** via `T | None` (preferred, modern) or
  `Optional[T]`. Never rely on "missing = None" implicitly.
- **`from __future__ import annotations`** at the top of every module.
- **Prefer `@dataclass(frozen=True)`** for value objects. Mutable models
  are the exception, not the default.
- **Return concrete types, not `Any`.** If you reach for `Any`, justify it
  in a comment immediately above the annotation. (Example here: `ResultRecord
  = dict[str, Any]` in [`bicc_bench/data/dtos/result_record.py`](../bicc_bench/data/dtos/result_record.py)
  — JSON decoding is inherently dynamic, and we validate at boundaries rather
  than ceremony with TypedDict.)
- **No Java patterns.** No getters/setters, no interface-per-class, no
  "Abstract…Factory". Use protocols / dataclasses / TypedDicts only when
  they add clarity, never as ceremony.
- **Docstrings: short, "why" over "what".** The type system carries "what".
- **Abbreviations, not initialisms, for domain terms.** Write
  `parser_compare` not `p_cmp`, `iteration_count` not `iter_cnt`. Universal
  CS / OS / stats abbreviations (`json`, `gc`, `rss`, `aot`, `iqr`,
  `Mann-Whitney U`) are fine — the rule targets *project-invented* shorthand,
  not established terminology.

## Tooling

- **`uv`** (https://docs.astral.sh/uv/) manages env + deps. `uv.lock` is
  checked into the repo for reproducibility.
- **`ruff`** for both lint and format (replaces black + flake8 + isort).
  Config in [`pyproject.toml`](../pyproject.toml) under `[tool.ruff]`.
- **`pytest`** for the test suite under [`tests/`](../tests/). Config in
  [`pyproject.toml`](../pyproject.toml) under `[tool.pytest.ini_options]`.
- **Python pinned to 3.12** via [`.python-version`](../.python-version). Match
  via `uv sync` (uv reads `.python-version` automatically).

## Package layout

See [`bicc_bench/__init__.py`](../bicc_bench/__init__.py) for the live tour.

```
benchmark/python/
├── run.py                      # thin entry: argparse + dispatch
├── bicc_bench/
│   ├── config.py               # paths, SCENARIO_DURATIONS, chart constants
│   ├── subcommands/            # one module per CLI verb
│   │   ├── build.py            # cmd_build
│   │   ├── runner.py           # cmd_run (renamed to avoid run.py shadow)
│   │   ├── compare.py          # cmd_compare + _print_compare_table
│   │   └── report.py           # cmd_report
│   └── data/
│       ├── dtos/               # frozen value classes, one per file
│       │   ├── compare_row.py
│       │   └── result_record.py
│       └── utils/              # stateless helpers
│           ├── stats.py        # median, group_samples, compute_compare_rows
│           ├── meta.py         # git_sha, version, duration parsing
│           ├── io.py           # source discovery + JSON load + filter
│           ├── charts.py       # 4 report + 4 paired + forest plot
│           └── markdown.py     # SUMMARY.md / COMPARE.md + value_formatter
└── tests/                      # pytest; one test_<module>.py per source module
```

### Conventions
- **Drop the underscore prefix on names exported to other modules** in the
  package. Functions stay underscore-prefixed only when they're purely
  module-local (e.g. `_print_compare_table` in `subcommands/compare.py`,
  `_compile_one` in `subcommands/build.py`, `_forest_colour` in `charts.py`).
- **One value class per file under `data/dtos/`** — keeps the data-class
  hierarchy flat and obvious to navigate.
- **Subcommands import helpers from `data/utils/`**; helpers never import
  from `subcommands/`. Acyclic.
- **`config.py` imports nothing from `bicc_bench`** — it's the leaf module
  everything else can depend on.

## Tests

- `uv run pytest` runs the whole suite. `uv run pytest -q` for quiet mode.
- One test file per source module, mirroring the package layout (e.g.
  `tests/test_stats.py` ↔ `bicc_bench/data/utils/stats.py`).
- Shared fixtures live in [`tests/conftest.py`](../tests/conftest.py) -
  synthetic `ResultRecord` lists, not on-disk fixture JSON files.
- **Test the deterministic surface**: math, formatting, table rendering,
  CLI arg parsing. Skip chart PNG comparison (brittle); the end-to-end
  smoke run covers chart rendering.
- **Coverage scope** is configured in [`pyproject.toml`](../pyproject.toml)
  under `[tool.coverage.run]`. `charts.py` and `subcommands/*` are
  `omit`-ed because they are smoke-only by design — they don't appear in
  either the numerator OR the denominator. Everything else (config,
  data/dtos, data/utils minus charts) sits inside the scope and is
  expected to be unit-tested. **CI gate is 95%** (`--cov-fail-under=95`
  in [`.github/workflows/benchmark.yml`](../../../.github/workflows/benchmark.yml)).
  If you add a new module that is ALSO smoke-only, append it to the
  `omit` list with a one-line rationale; do not lower the gate to
  accommodate untested code.

## Before claiming done

Definition-of-done for any Python change in this directory:

- [ ] `uv run pytest` — all tests passing.
- [ ] `uv run ruff check .` — clean.
- [ ] `uv run ruff format --check .` — clean.
- [ ] Type annotations on every function signature + module constant you
      added or changed. Mypy not currently wired in — ruff doesn't type-check
      yet (RUF rules cover style only). If the type stack grows, add `pyright`
      or `mypy` here.
- [ ] If you added or changed a runtime dep: `uv sync` was re-run and
      `uv.lock` is staged.
- [ ] **Tests for new logic** in `data/utils/` or `data/dtos/`. Subcommand
      modules are integration-tested via the end-to-end smoke; unit tests
      target the pure helpers.
- [ ] **Coverage ≥ 95%** on the in-scope surface. `uv run pytest` prints
      the table locally; CI gate enforces. Don't add new code to
      `data/utils/` or `data/dtos/` without a matching `tests/test_<module>.py`.

## Hard rules

- **Never edit `uv.lock` by hand.** Run `uv sync` / `uv add` / `uv lock` to
  regenerate.
- **Never commit `.venv/` or `__pycache__/`.** [`benchmark/.gitignore`](../../.gitignore)
  already excludes both.
- **Never use `pip install` directly.** Always go through `uv`. Mixed
  `pip`/`uv` envs are subtly broken.
- **Bash only for `uv`, `ruff`, `python`, `git`.** Use Read/Edit/Grep/Glob for
  source-file work (matches the parent project's
  [`.ai/CLAUDE.md`](../../../.ai/CLAUDE.md) tool-preference rule).
