import 'package:better_internet_conn_check_example/features/core/widgets/status_badge.dart';
import 'package:better_internet_conn_check_example/main.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/widgets.dart' show ListView;
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart'
    show PlatformApp, PlatformScaffold;

void main() {
  testWidgets('home screen lists every demo', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('better_internet_connectivity_checker'), findsOneWidget);
    expect(find.text('Live status stream'), findsOneWidget);
    expect(find.text('One-shot check'), findsOneWidget);
    expect(find.text('Custom targets'), findsOneWidget);
    expect(find.text('Policy comparison'), findsOneWidget);
    expect(find.text('Failure inspection'), findsOneWidget);
  });

  // Regression: on iOS, PlatformScaffold renders a CupertinoPageScaffold whose
  // body sits *behind* the translucent navigation bar — so the ListView starts
  // at y=0 and its top tiles hide under the bar unless the body is wrapped in a
  // SafeArea. Android's Scaffold insets the body for us, so this only regresses
  // on iOS. Asserting the list top clears y=0 proves the SafeArea wrap is doing
  // its job.
  testWidgets('iOS insets the scrolling body below the navigation bar', (tester) async {
    // Reset in a finally (not addTearDown) — the framework's end-of-body
    // invariant check runs before tearDowns and fails if the override leaks.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      await tester.pumpWidget(const MyApp());

      expect(tester.getTopLeft(find.byType(ListView)).dy, greaterThan(0));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // Regression: StatusBadge's chip is a Material widget with no Platform
  // equivalent. On iOS a bare Material Chip throws "No Material widget found"
  // under CupertinoPageScaffold (no Material ancestor), so it must render the
  // PlatformChip gap widget instead. Pumping the badge inside a PlatformApp +
  // PlatformScaffold on iOS exercises exactly that ancestor-less path.
  testWidgets('iOS renders the status badge without a Material ancestor', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      await tester.pumpWidget(
        const PlatformApp(home: PlatformScaffold(body: StatusBadge(internetStatus: null))),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Not yet checked'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
