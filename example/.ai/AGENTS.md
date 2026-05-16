# AGENTS.md — `example/`

Tool-agnostic brief for the runnable demo app under `example/`. Library-package
conventions live in the parent [`AGENTS.md`](../../.ai/AGENTS.md);
example-specific code style (MVVM, naming, widget composition, …) lives in
[`CODESTYLE.md`](../CODESTYLE.md). Read both before working in this
subdirectory.

## Scope
- Runnable demo of `better_internet_connectivity_checker` — exercises the package
  against real probes and showcases recommended usage patterns.
- Not published to pub.dev. No semver discipline. Freely depends on Flutter.
- Layout: each feature is a pair under `lib/features/<feature>/` —
  `<feature>_view.dart` + `<feature>_view_model.dart`. The MVVM scaffold uses
  [pmvvm](https://pub.dev/packages/pmvvm); see
  [`CODESTYLE.md#mvvm`](../CODESTYLE.md#mvvm) for the conventions that govern
  how the pair is wired.
