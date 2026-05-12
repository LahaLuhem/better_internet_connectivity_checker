<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [What it does](#what-it-does)
- [Getting started](#getting-started)
- [Usage](#usage)
- [Project layout](#project-layout)
- [Testing](#testing)
- [Releasing](#releasing)
- [Contributing](#contributing)

<!-- TOC end -->

`ultimate_internet_connectivity_checker` is a pure-Dart package for **robust
internet-connectivity checking**. The goal is to answer "can I actually reach the public
internet right now?" — distinct from "is a network interface up?", which is what most
OS-level checks report.

**Early scaffolding.** The public API is not yet stable; version `0.0.0` ships no usable
surface. The layout, lint posture, and conventions are fixed; the API itself is still
being designed. Watch the repo / CHANGELOG for the first usable cut.

<!-- TOC --><a name="what-it-does"></a>
## What it does

TODO — fill in once the public API stabilises. Planned scope:

- Probe one or more reachability targets (HTTP / DNS / TCP) with sensible defaults and
  overrideable strategies.
- Distinguish transient failure from persistent loss of connectivity.
- Stream status-change events when connectivity transitions in or out.
- Work uniformly on every Dart platform — CLI, server, web, Flutter — with no
  platform-channel requirement.

<!-- TOC --><a name="getting-started"></a>
## Getting started

Add the package to `pubspec.yaml`:

```yaml
dependencies:
  ultimate_internet_connectivity_checker: ^0.0.0
```

Then run:

```bash
dart pub get
```

This package is **pure Dart** and does not depend on Flutter. It works in any Dart 3.11+
project — CLI, server-side, web, and Flutter alike.

<!-- TOC --><a name="usage"></a>
## Usage

TODO — replace with a real example once the API is implemented.

```dart
import 'package:ultimate_internet_connectivity_checker/ultimate_internet_connectivity_checker.dart';

void main() async {
  // Public API still under design — see APPENDIX.md for design notes.
}
```

A runnable example will live in `example/` once the API stabilises.

<!-- TOC --><a name="project-layout"></a>
## Project layout

```
ultimate_internet_connectivity_checker/
├── lib/
│   ├── ultimate_internet_connectivity_checker.dart   Public entry; exports from src/
│   └── src/                                           Private implementation
├── test/                                              `dart test` units (TBA)
├── example/                                           Runnable samples (TBA)
├── analysis_options.yaml                              Strict-mode + opinionated lints
├── pubspec.yaml                                       Deps + cider config + topics
├── .pubignore                                         Files excluded from `pub publish`
├── .fvmrc                                             FVM-pinned SDK version
├── .editorconfig                                      Text-file formatting (width, indents)
├── CHANGELOG.md                                       cider-managed; appears on pub.dev
├── README.md                                          (this file — pub.dev landing)
├── APPENDIX.md                                        Design rationale (anchor-keyed)
└── .ai/                                               Coding-agent guidance
```

[`APPENDIX.md`](./APPENDIX.md) carries design decisions, rejected paths, and non-obvious
trade-offs. [`.ai/AGENTS.md`](./.ai/AGENTS.md) is the tool-agnostic agent brief (hard
rules, style, workflow); [`.ai/CLAUDE.md`](./.ai/CLAUDE.md) covers Claude-Code session
conventions.

<!-- TOC --><a name="testing"></a>
## Testing

```bash
fvm dart test                                            # full test suite
fvm dart analyze                                         # strict-mode static analysis
fvm dart format --output=none --set-exit-if-changed .    # formatter check
```

The Dart/Flutter SDK version is pinned via [FVM](https://fvm.app/); see `.fvmrc`. Run
`fvm install` once before the first build.

<!-- TOC --><a name="releasing"></a>
## Releasing

Version bumps and CHANGELOG entries are managed via
[`cider`](https://pub.dev/packages/cider).

```bash
fvm dart pub global activate cider              # one-time
cider log add added "<user-visible change>"     # under Added / Changed / Fixed / …
cider bump patch                                # 0.0.0 → 0.0.1 (or minor / major)
fvm dart pub publish --dry-run                  # validate before pushing
fvm dart pub publish                            # actually publish — user-only action
```

Released tags follow `v<MAJOR>.<MINOR>.<PATCH>` and link to GitHub releases via the
`link_template` block in `pubspec.yaml`.

<!-- TOC --><a name="contributing"></a>
## Contributing

Issues and PRs welcome at
<https://github.com/LahaLuhem/ultimate_internet_connectivity_checker>. Read
[`.ai/AGENTS.md`](./.ai/AGENTS.md) for the house style and [`APPENDIX.md`](./APPENDIX.md)
for the design rationale before sending a non-trivial change.
