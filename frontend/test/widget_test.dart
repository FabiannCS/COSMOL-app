import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cosmol_app/main.dart';

void main() {
  testWidgets('CosmolApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CosmolApp(),
      ),
    );

    expect(find.byType(CosmolApp), findsOneWidget);
  });
}
