# APPENDIX — `ultimate_internet_connectivity_checker`

Consolidated source of truth for design decisions, rejected paths, and non-obvious
technical trade-offs.

READMEs and `.ai/AGENTS.md` reference sections here by anchor (e.g.
`APPENDIX.md#pure-dart-not-flutter`). **Headings below are load-bearing** — each carries
an explicit `<a id="…">` anchor immediately above it. When renaming a heading, keep the
anchor stable or grep-and-update every caller.

---

<a id="ai-files-symlinked"></a>
## `AGENTS.md` and `CLAUDE.md` are symlinks into `.ai/`

- **Decision:** the canonical text for both files lives under `.ai/`. The repo root holds
  symlinks (`AGENTS.md → .ai/AGENTS.md`, `CLAUDE.md → .ai/CLAUDE.md`).
- **Why:** Claude Code (and most other coding agents) auto-discover `CLAUDE.md` /
  `AGENTS.md` at the project root, but two more loose Markdown files at the root add
  visual noise to the file tree. Scoping the agent-guidance files under `.ai/` keeps them
  together; the root symlinks preserve auto-discovery.
- **Cross-platform note:** symlinks survive `git clone` on macOS/Linux. On Windows hosts
  without symlink support enabled, the file may show up as a small text file containing
  the link target. If that ever bites a contributor, the fallback is to drop the symlinks
  and keep real files at root, hand-syncing the content (or to delete the duplicates
  under `.ai/`).

---

<a id="pure-dart-not-flutter"></a>
## Pure-Dart package, no Flutter dependency

- **Chosen:** zero Flutter dependency. `pubspec.yaml` declares only a Dart SDK constraint
  (`sdk: ^3.11.0`); no `flutter:` block.
- **Why:** connectivity checking is fundamentally an HTTP / DNS / TCP problem, none of
  which need platform channels. Keeping the package Flutter-free means it works equally
  on Dart server, CLI, web, and Flutter — not just Flutter apps — and avoids pulling a
  Flutter dep tree into non-Flutter users' transitive closure.
- **If platform channels ever become necessary** (e.g. iOS reachability API integration),
  the right move is a sibling Flutter-plugin package that depends on this one, not adding
  Flutter to this `pubspec.yaml`.
- **`.fvmrc` exists** for local SDK pinning, but FVM is a build-time tool, not a runtime
  dep — it doesn't show up in `pubspec.yaml` and doesn't affect downstream consumers.

---

<a id="public-api-via-single-export-file"></a>
## Public API funnelled through `lib/<package>.dart`

- **Chosen:** `lib/ultimate_internet_connectivity_checker.dart` is the only file callers
  import. Implementation lives in `lib/src/`; nothing in `src/` is intended to be
  imported directly. The entry file consists almost entirely of `export 'src/…' show …;`
  lines.
- **Why:** Dart doesn't have a hard public/private boundary between library files —
  anything under `lib/` is importable. The single-entry + `lib/src/` convention is how
  the ecosystem signals private intent. It also gives one place to audit the public
  surface when planning a release, and one place to control re-exports with `show` /
  `hide`.
- **Implication for refactors:** moving code *within* `lib/src/` is free (private).
  Moving anything *into or out of* the re-export list is a semver-visible change — minor
  for additions, major for removals or signature changes.
