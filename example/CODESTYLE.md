Example-app code style.
Library-package style lives in [`../CODESTYLE.md`](../CODESTYLE.md);
project facts and scope live in [`.ai/AGENTS.md`](./.ai/AGENTS.md).

Each heading below carries an explicit `<a id="…">` anchor. Link by anchor, not by
heading text, so renames don't break callers.

<!-- TOC start (generated with https://github.com/derlin/bitdowntoc) -->

- [MVVM architecture](#mvvm-architecture)
- [Reactivity (ValueNotifier-first)](#reactivity-valuenotifier-first)
- [Naming](#naming)
    * [Boolean fields — modal verbs](#boolean-fields-modal-verbs)
    * [Callback methods — view-event suffix](#callback-methods-view-event-suffix)
- [ViewModel member ordering](#viewmodel-member-ordering)
- [Separation of concerns](#separation-of-concerns)
- [Widget composition](#widget-composition)
    * [Native widget parameters](#native-widget-parameters)
    * [Spacing — rule of 8](#spacing-rule-of-8)
- [Async-action buttons](#async-action-buttons)

<!-- TOC end -->

Example-app code style.
Library-package style lives in [`../CODESTYLE.md`](../CODESTYLE.md);
project facts and scope live in [`.ai/AGENTS.md`](./.ai/AGENTS.md).

Each heading below carries an explicit `<a id="…">` anchor. Link by anchor, not by
heading text, so renames don't break callers.

<a id="mvvm"></a>
<!-- TOC --><a name="mvvm-architecture"></a>
## MVVM architecture

The example uses [pmvvm](https://pub.dev/packages/pmvvm) —
`MVVM.builder(viewModel: …, viewBuilder: …)` binds a `ViewModel` to a
`StatelessWidget` view. Each feature is a pair:
`lib/features/<feature>/<feature>_view.dart` + `<feature>_view_model.dart`.

---

<a id="reactivity"></a>
<!-- TOC --><a name="reactivity-valuenotifier-first"></a>
## Reactivity (ValueNotifier-first)

All observable VM state is exposed as `ValueListenable<T>`, backed by a private
`ValueNotifier<T>`. Views subscribe via `ValueListenableBuilder`.

- **No `notifyListeners()`.** Every state-mutating method writes
  `_xNotifier.value = …` on the relevant notifier. `MVVM.builder`'s outer
  `viewBuilder` becomes a static frame; pmvvm earns its keep as DI + lifecycle, not as
  a rebuild trigger.
- **Naming: `_xNotifier` for the private field, `xListenable` for the public getter.**

  ```dart
  final _probeMethodNotifier = ValueNotifier(ProbeMethod.head);

  ValueListenable<ProbeMethod> get probeMethodListenable => _probeMethodNotifier;
  ```

  The suffixes make it unambiguous which side reads vs. writes, and prevent the
  bare-noun field from colliding with the getter name. The view binds the getter; it
  cannot mutate.
- **Omit the obvious `<T>` on `ValueNotifier(…)`.** When the initial value pins the
  type, drop the explicit type argument (`ValueNotifier(true)`,
  `ValueNotifier(ProbeMethod.head)`). Keep it only when the initial value is `null`
  and inference cannot recover the type (`ValueNotifier<InternetStatus?>(null)`).
- **Group co-updated fields into one notifier with a record type.** Fields that are
  always written together — `(status, targetUrl)`,
  `(currentStatus, transitions, lastUpdate)` — share one `ValueNotifier<({…})?>`. One
  write per logical update, one tick per rebuild. Splitting them costs extra notifier
  ceremony and extra ticks for zero gain when they always move in lockstep. Promote
  the record to a top-level `typedef` so the public listenable's type does not fail
  the `library_private_types_in_public_api` lint.
- **Dispose every notifier in `dispose()`** before `super.dispose()`.
- **VM-internal state stays plain.** Fields no widget observes (e.g. `_connection`,
  `_subscription`, `_slowThreshold`) are plain Dart fields — no notifier ceremony.

---

<a id="naming"></a>
<!-- TOC --><a name="naming"></a>
## Naming

<a id="naming-booleans"></a>
<!-- TOC --><a name="boolean-fields-modal-verbs"></a>
### Boolean fields — modal verbs

For boolean values and their derivatives (notifiers, listenables, getters), prefix
the identifier with a **modal verb** — `should`, `can`, `may`, `would`, `must` — to
make the read-site speak plain English. The bare-noun form (`acceptAnyTwoXx`,
`includeBogusTarget`) reads as a noun and forces the reader to mentally add the verb.

- ★ Default to `should` for user preferences and UI toggle state — declarative,
  expresses the intent the user is encoding.
- Reach for `can` when the bool gates a capability rather than a preference, `may`
  when it gates permission, `would` for hypothetical intent in unrun branches.

| Bad                  | Good                                                                      |
|----------------------|---------------------------------------------------------------------------|
| `acceptAnyTwoXx`     | `shouldAcceptAnyTwoXx`                                                    |
| `includeBogusTarget` | `shouldIncludeBogusTarget`                                                |
| `isRunning`          | (removed — view-local; [Async-action buttons](#async-action-buttons))     |

This applies to the field, its notifier, and its listenable getter together — they
refer to the same concept, so the modal-prefix stays consistent across the trio.
Callback method names (e.g. `onAcceptAnyTwoXxToggled`) describe the **event** and
continue to match the UI label, so they keep the bare-noun form even when they mutate
a `shouldXxx` field — the event and the state describe different things.

<a id="naming-callbacks"></a>
<!-- TOC --><a name="callback-methods-view-event-suffix"></a>
### Callback methods — view-event suffix

VM methods invoked from the view are named **from the view's perspective**: what the
user did, not what the VM does in response. Pattern: `on<Event>` with a suffix
matching the widget kind that produced the event.

| Widget                | Suffix     | Example                              |
|-----------------------|------------|--------------------------------------|
| Button (`onPressed`)  | `Pressed`  | `onRunCheckPressed`                  |
| `SwitchListTile`      | `Toggled`  | `onAcceptAnyTwoXxToggled`            |
| `Slider.onChanged`    | `Changed`  | `onSlowThresholdSliderChanged`       |
| `Slider.onChangeEnd`  | `Released` | `onSlowThresholdSliderReleased`      |
| `DropdownButton`      | `Selected` | `onMethodSelected`                   |
| `TextField.onChanged` | `Changed`  | `onUrlChanged`                       |

Avoid VM-leaking names like `setX`, `runX`, `commitX`, `forceX` — those describe what
the VM does internally. The VM is still free to do whatever it likes inside the
method body (mutate notifiers, rebuild a connection, show a snackbar); only the
method *name* must reflect the view event.

**Named-arg style** — keep the parameter name on the call site when the type is
bare-`bool` (and elsewhere where `avoid_positional_boolean_parameters` would fire on
the VM signature):

```dart
// VM
void onAcceptAnyTwoXxToggled({required bool value}) =>
    _shouldAcceptAnyTwoXxNotifier.value = value;

// View
onChanged: (value) => viewModel.onAcceptAnyTwoXxToggled(value: value),
```

---

<a id="vm-member-ordering"></a>
<!-- TOC --><a name="viewmodel-member-ordering"></a>
## ViewModel member ordering

Apply this ordering to every `ViewModel` subclass. It lets a reader scan dependencies
→ construction → state → lifecycle entry → reads → writes → teardown without
backtracking.

1. **External-ref fields** — DI / services held by reference (none in the example
   today).
2. **Constructors** — unnamed first, then factories. Constructors assign to the
   external-ref fields.
3. **State fields** — notifiers, controllers, `late` connections, subscriptions.
   Static class-level constants live with this group at the top.
4. **`init()`** — lifecycle entry; sets up streams / triggers.
5. **Getters** — the `xListenable` getters and any other pure reads.
6. **Getter-like methods** — pure / near-pure reads expressed as methods (rare).
7. **Logic methods** — `on<Event>` handlers and complex orchestration. Simplest first
   if you can rank them; otherwise grouped by feature.
8. **Private helpers** — `_attemptCheck`, `_buildConnection`, `_parseAllowedMethod`.
   Static helpers go at the end of this group.
9. **`dispose()`** — teardown, last.

---

<a id="separation-of-concerns"></a>
<!-- TOC --><a name="separation-of-concerns"></a>
## Separation of concerns

- **The view is agnostic to the VM's inner workings.** It reads VM state, invokes VM
  callbacks, renders widgets. It does NOT know *how* the VM implements an action —
  only *what event* it is reporting.
- **Widget-state holding domain input belongs on the VM.** `TextEditingController`,
  `ScrollController`, `FocusNode` — these carry user input the VM operates on
  (validates a URL, scrolls to an offset on save). The VM owns construction and
  disposal; the view binds directly (`controller: viewModel.urlController`). They ARE
  the state, not implementation that should be hidden.
- **Widget-state describing pure UI presentation belongs on the view.** "This button
  is mid-async, show a spinner" is purely visual — no VM logic and no other widget
  consume it. Use `tap_debouncer` (via `AsyncIconActionButton`) so the view tracks its
  own in-flight gate. Do NOT add an `isRunning` field on the VM for this — that was
  the previous pattern and is now considered a regression.

---

<a id="widget-composition"></a>
<!-- TOC --><a name="widget-composition"></a>
## Widget composition

<a id="widget-native-params"></a>
<!-- TOC --><a name="native-widget-parameters"></a>
### Native widget parameters

When a widget exposes a native parameter for what you need, use it. Do not reinvent
it with extra children, padding wrappers, or string tricks.

- **`Row(spacing:)` / `Column(spacing:)` over interleaved `Gap` / `SizedBox`.** Use
  whenever the gap should be uniform between every adjacent child pair — including
  cases where some pairs are currently flush; lean toward making the rhythm
  consistent.
- **`spacing:` over trailing whitespace in label strings.** A `Text('HTTP method:  ')`
  with magic trailing spaces is a hack; `Row(spacing: 8, children: [Text('HTTP method:'), …])`
  is the intended primitive.
- **`Gap` stays for `ListView` children** (no `spacing` parameter available) and for
  genuinely non-uniform sequences (e.g. a `Column` that interleaves `Divider`s where
  the spacing-around-divider differs from spacing-between-other-children).

```dart
// Prefer:
Column(
  crossAxisAlignment: .start,
  spacing: 8,
  children: [Text(...), StatusBadge(...), _ResultDetail(...)],
)

// Over:
Column(
  crossAxisAlignment: .start,
  children: [Text(...), const Gap(8), StatusBadge(...), const Gap(8), _ResultDetail(...)],
)
```

<a id="widget-spacing"></a>
<!-- TOC --><a name="spacing-rule-of-8"></a>
### Spacing — rule of 8

All spacing values (`Gap`, `spacing:`, `Padding`, `EdgeInsets`, margins) follow an
8-pixel grid. This keeps the UI visually consistent and stops ad-hoc values from
drifting in.

- **Default ladder: `8 → 16 → 24 → 32 …`** — multiples of 8 for any spacing ≥ 8.
- **Sub-8 escape hatch: `2`, `4`, `8`.** Used only when an 8-grid value would be too
  generous (tight typography, internal row padding, list-card vertical margin). Other
  sub-8 values (3, 5, 6, 7) are effectively never right.
- **`12` is rare** and almost always a sign of someone splitting the difference
  between 8 and 16. Convert to 8 or 16 unless there is a concrete reason 12 is
  required (a third-party widget pinning a specific dimension, alignment to an
  external mockup that itself is on a non-8 grid). When you keep a 12, drop a
  one-line `//` comment explaining why.
- **Card content `Padding`: `.all(16)`** by default — matches Material 3's standard
  content padding.
- **Card vertical margin in a list: `4`** is fine (8 total between cards). Horizontal
  margin: `16` for screen-edge inset.

When in doubt, prefer the smaller 8-grid neighbour over the larger sub-8 value. `8`
over `4` for breathing room; `16` over `12` for section separation.

---

<a id="async-action-buttons"></a>
<!-- TOC --><a name="async-action-buttons"></a>
## Async-action buttons

Every async button in the example uses `AsyncIconActionButton`
(`lib/features/core/widgets/async_icon_action_button.dart`), which wraps
`tap_debouncer` with `cooldown: Duration.zero` and `ElevatedButton.icon`. This:

- Removes the need for an `isRunning` field on the VM.
- Locks the button while the async work is in flight and re-arms immediately on
  completion (no post-completion cooldown).
- Standardises the busy state (spinner + busy label) across every feature.

```dart
AsyncIconActionButton(
  onPressed: viewModel.onProbePressed,
  idleIcon: Icons.send,
  idleLabel: 'Probe URL',
  busyLabel: 'Probing…',
)
```

Add a flexible (builder-based) variant only when a real non-icon caller appears.


<a id="mvvm"></a>
## MVVM architecture

The example uses [pmvvm](https://pub.dev/packages/pmvvm) —
`MVVM.builder(viewModel: …, viewBuilder: …)` binds a `ViewModel` to a
`StatelessWidget` view. Each feature is a pair:
`lib/features/<feature>/<feature>_view.dart` + `<feature>_view_model.dart`.

---

<a id="reactivity"></a>
## Reactivity (ValueNotifier-first)

All observable VM state is exposed as `ValueListenable<T>`, backed by a private
`ValueNotifier<T>`. Views subscribe via `ValueListenableBuilder`.

- **No `notifyListeners()`.** Every state-mutating method writes
  `_xNotifier.value = …` on the relevant notifier. `MVVM.builder`'s outer
  `viewBuilder` becomes a static frame; pmvvm earns its keep as DI + lifecycle, not as
  a rebuild trigger.
- **Naming: `_xNotifier` for the private field, `xListenable` for the public getter.**

  ```dart
  final _probeMethodNotifier = ValueNotifier(ProbeMethod.head);

  ValueListenable<ProbeMethod> get probeMethodListenable => _probeMethodNotifier;
  ```

  The suffixes make it unambiguous which side reads vs. writes, and prevent the
  bare-noun field from colliding with the getter name. The view binds the getter; it
  cannot mutate.
- **Omit the obvious `<T>` on `ValueNotifier(…)`.** When the initial value pins the
  type, drop the explicit type argument (`ValueNotifier(true)`,
  `ValueNotifier(ProbeMethod.head)`). Keep it only when the initial value is `null`
  and inference cannot recover the type (`ValueNotifier<InternetStatus?>(null)`).
- **Group co-updated fields into one notifier with a record type.** Fields that are
  always written together — `(status, targetUrl)`,
  `(currentStatus, transitions, lastUpdate)` — share one `ValueNotifier<({…})?>`. One
  write per logical update, one tick per rebuild. Splitting them costs extra notifier
  ceremony and extra ticks for zero gain when they always move in lockstep. Promote
  the record to a top-level `typedef` so the public listenable's type does not fail
  the `library_private_types_in_public_api` lint.
- **Dispose every notifier in `dispose()`** before `super.dispose()`.
- **VM-internal state stays plain.** Fields no widget observes (e.g. `_connection`,
  `_subscription`, `_slowThreshold`) are plain Dart fields — no notifier ceremony.

---

<a id="naming"></a>
## Naming

<a id="naming-booleans"></a>
### Boolean fields — modal verbs

For boolean values and their derivatives (notifiers, listenables, getters), prefix
the identifier with a **modal verb** — `should`, `can`, `may`, `would`, `must` — to
make the read-site speak plain English. The bare-noun form (`acceptAnyTwoXx`,
`includeBogusTarget`) reads as a noun and forces the reader to mentally add the verb.

- ★ Default to `should` for user preferences and UI toggle state — declarative,
  expresses the intent the user is encoding.
- Reach for `can` when the bool gates a capability rather than a preference, `may`
  when it gates permission, `would` for hypothetical intent in unrun branches.

| Bad                  | Good                                                                      |
|----------------------|---------------------------------------------------------------------------|
| `acceptAnyTwoXx`     | `shouldAcceptAnyTwoXx`                                                    |
| `includeBogusTarget` | `shouldIncludeBogusTarget`                                                |
| `isRunning`          | (removed — view-local; [Async-action buttons](#async-action-buttons))     |

This applies to the field, its notifier, and its listenable getter together — they
refer to the same concept, so the modal-prefix stays consistent across the trio.
Callback method names (e.g. `onAcceptAnyTwoXxToggled`) describe the **event** and
continue to match the UI label, so they keep the bare-noun form even when they mutate
a `shouldXxx` field — the event and the state describe different things.

<a id="naming-callbacks"></a>
### Callback methods — view-event suffix

VM methods invoked from the view are named **from the view's perspective**: what the
user did, not what the VM does in response. Pattern: `on<Event>` with a suffix
matching the widget kind that produced the event.

| Widget                | Suffix     | Example                              |
|-----------------------|------------|--------------------------------------|
| Button (`onPressed`)  | `Pressed`  | `onRunCheckPressed`                  |
| `SwitchListTile`      | `Toggled`  | `onAcceptAnyTwoXxToggled`            |
| `Slider.onChanged`    | `Changed`  | `onSlowThresholdSliderChanged`       |
| `Slider.onChangeEnd`  | `Released` | `onSlowThresholdSliderReleased`      |
| `DropdownButton`      | `Selected` | `onMethodSelected`                   |
| `TextField.onChanged` | `Changed`  | `onUrlChanged`                       |

Avoid VM-leaking names like `setX`, `runX`, `commitX`, `forceX` — those describe what
the VM does internally. The VM is still free to do whatever it likes inside the
method body (mutate notifiers, rebuild a connection, show a snackbar); only the
method *name* must reflect the view event.

**Named-arg style** — keep the parameter name on the call site when the type is
bare-`bool` (and elsewhere where `avoid_positional_boolean_parameters` would fire on
the VM signature):

```dart
// VM
void onAcceptAnyTwoXxToggled({required bool value}) =>
    _shouldAcceptAnyTwoXxNotifier.value = value;

// View
onChanged: (value) => viewModel.onAcceptAnyTwoXxToggled(value: value),
```

---

<a id="vm-member-ordering"></a>
## ViewModel member ordering

Apply this ordering to every `ViewModel` subclass. It lets a reader scan dependencies
→ construction → state → lifecycle entry → reads → writes → teardown without
backtracking.

1. **External-ref fields** — DI / services held by reference (none in the example
   today).
2. **Constructors** — unnamed first, then factories. Constructors assign to the
   external-ref fields.
3. **State fields** — notifiers, controllers, `late` connections, subscriptions.
   Static class-level constants live with this group at the top.
4. **`init()`** — lifecycle entry; sets up streams / triggers.
5. **Getters** — the `xListenable` getters and any other pure reads.
6. **Getter-like methods** — pure / near-pure reads expressed as methods (rare).
7. **Logic methods** — `on<Event>` handlers and complex orchestration. Simplest first
   if you can rank them; otherwise grouped by feature.
8. **Private helpers** — `_attemptCheck`, `_buildConnection`, `_parseAllowedMethod`.
   Static helpers go at the end of this group.
9. **`dispose()`** — teardown, last.

---

<a id="separation-of-concerns"></a>
## Separation of concerns

- **The view is agnostic to the VM's inner workings.** It reads VM state, invokes VM
  callbacks, renders widgets. It does NOT know *how* the VM implements an action —
  only *what event* it is reporting.
- **Widget-state holding domain input belongs on the VM.** `TextEditingController`,
  `ScrollController`, `FocusNode` — these carry user input the VM operates on
  (validates a URL, scrolls to an offset on save). The VM owns construction and
  disposal; the view binds directly (`controller: viewModel.urlController`). They ARE
  the state, not implementation that should be hidden.
- **Widget-state describing pure UI presentation belongs on the view.** "This button
  is mid-async, show a spinner" is purely visual — no VM logic and no other widget
  consume it. Use `tap_debouncer` (via `AsyncIconActionButton`) so the view tracks its
  own in-flight gate. Do NOT add an `isRunning` field on the VM for this — that was
  the previous pattern and is now considered a regression.

---

<a id="widget-composition"></a>
## Widget composition

<a id="widget-native-params"></a>
### Native widget parameters

When a widget exposes a native parameter for what you need, use it. Do not reinvent
it with extra children, padding wrappers, or string tricks.

- **`Row(spacing:)` / `Column(spacing:)` over interleaved `Gap` / `SizedBox`.** Use
  whenever the gap should be uniform between every adjacent child pair — including
  cases where some pairs are currently flush; lean toward making the rhythm
  consistent.
- **`spacing:` over trailing whitespace in label strings.** A `Text('HTTP method:  ')`
  with magic trailing spaces is a hack; `Row(spacing: 8, children: [Text('HTTP method:'), …])`
  is the intended primitive.
- **`Gap` stays for `ListView` children** (no `spacing` parameter available) and for
  genuinely non-uniform sequences (e.g. a `Column` that interleaves `Divider`s where
  the spacing-around-divider differs from spacing-between-other-children).

```dart
// Prefer:
Column(
  crossAxisAlignment: .start,
  spacing: 8,
  children: [Text(...), StatusBadge(...), _ResultDetail(...)],
)

// Over:
Column(
  crossAxisAlignment: .start,
  children: [Text(...), const Gap(8), StatusBadge(...), const Gap(8), _ResultDetail(...)],
)
```

<a id="widget-spacing"></a>
### Spacing — rule of 8

All spacing values (`Gap`, `spacing:`, `Padding`, `EdgeInsets`, margins) follow an
8-pixel grid. This keeps the UI visually consistent and stops ad-hoc values from
drifting in.

- **Default ladder: `8 → 16 → 24 → 32 …`** — multiples of 8 for any spacing ≥ 8.
- **Sub-8 escape hatch: `2`, `4`, `8`.** Used only when an 8-grid value would be too
  generous (tight typography, internal row padding, list-card vertical margin). Other
  sub-8 values (3, 5, 6, 7) are effectively never right.
- **`12` is rare** and almost always a sign of someone splitting the difference
  between 8 and 16. Convert to 8 or 16 unless there is a concrete reason 12 is
  required (a third-party widget pinning a specific dimension, alignment to an
  external mockup that itself is on a non-8 grid). When you keep a 12, drop a
  one-line `//` comment explaining why.
- **Card content `Padding`: `.all(16)`** by default — matches Material 3's standard
  content padding.
- **Card vertical margin in a list: `4`** is fine (8 total between cards). Horizontal
  margin: `16` for screen-edge inset.

When in doubt, prefer the smaller 8-grid neighbour over the larger sub-8 value. `8`
over `4` for breathing room; `16` over `12` for section separation.

---

<a id="async-action-buttons"></a>
## Async-action buttons

Every async button in the example uses `AsyncIconActionButton`
(`lib/features/core/widgets/async_icon_action_button.dart`), which wraps
`tap_debouncer` with `cooldown: Duration.zero` and `ElevatedButton.icon`. This:

- Removes the need for an `isRunning` field on the VM.
- Locks the button while the async work is in flight and re-arms immediately on
  completion (no post-completion cooldown).
- Standardises the busy state (spinner + busy label) across every feature.

```dart
AsyncIconActionButton(
  onPressed: viewModel.onProbePressed,
  idleIcon: Icons.send,
  idleLabel: 'Probe URL',
  busyLabel: 'Probing…',
)
```

Add a flexible (builder-based) variant only when a real non-icon caller appears.
