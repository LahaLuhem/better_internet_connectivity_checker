import 'package:better_internet_conn_check_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
