# `benchmark/python/` — agent brief

Tool-agnostic brief for any coding agent (Copilot, Cursor, Codex, Claude Code,
…) working in the Python orchestrator. The parent project is a pure Dart
package; this directory is the only Python surface and exists purely as
maintainer-only tooling (excluded from `dart pub publish`).

## Style: Python as strongly typed

House style mirrors the user's other repo
[`LahaLuhem/mysql_distillery`](https://github.com/LahaLuhem/mysql_distillery)
— specifically:

- [`.ai/AGENTS.md` § "Style (Python-as-strongly-typed)"](https://github.com/LahaLuhem/mysql_distillery/blob/main/.ai/AGENTS.md#style-python-as-strongly-typed)
- [`.ai/CLAUDE.md` § "Typing expectations (project-specific)"](https://github.com/LahaLuhem/mysql_distillery/blob/main/.ai/CLAUDE.md#typing-expectations-project-specific)

Restated inline (so this brief is self-contained — don't make agents fetch the
upstream every time):

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
  = dict[str, Any]` in `run.py` — JSON decoding is inherently dynamic, and
  we validate at boundaries rather than ceremony with TypedDict.)
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
  Config in [`pyproject.toml`](pyproject.toml) under `[tool.ruff]`.
- **Python pinned to 3.12** via [`.python-version`](.python-version). Match
  via `uv sync` (uv reads `.python-version` automatically).

## Before claiming done

Definition-of-done for any Python change in this directory:

- [ ] `uv run ruff check .` — clean.
- [ ] `uv run ruff format --check .` — clean.
- [ ] Type annotations on every function signature + module constant you
      added or changed. Mypy not currently wired in — ruff doesn't type-check
      yet (RUF rules cover style only). If the type stack grows, add `pyright`
      or `mypy` here.
- [ ] If you added or changed a runtime dep: `uv sync` was re-run and
      `uv.lock` is staged.

## Hard rules

- **Never edit `uv.lock` by hand.** Run `uv sync` / `uv add` / `uv lock` to
  regenerate.
- **Never commit `.venv/` or `__pycache__/`.** [`benchmark/.gitignore`](../.gitignore)
  already excludes both.
- **Never use `pip install` directly.** Always go through `uv`. Mixed
  `pip`/`uv` envs are subtly broken.
- **Bash only for `uv`, `ruff`, `python`, `git`.** Use Read/Edit/Grep/Glob for
  source-file work (matches the parent project's [CLAUDE.md](../../CLAUDE.md)
  tool-preference rule).
