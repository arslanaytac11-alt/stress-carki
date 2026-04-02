import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:stress_carki/main.dart';

void main() {
  testWidgets('App smoke test', (tester) async {
    await tester.pumpWidget(StressCarkiApp(initialLocale: const Locale('tr')));
    await tester.pump();
  });
}
