import 'package:flutter_test/flutter_test.dart';

import 'package:urban_easy_property_flutter_app/src/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UrbanEasyFlatsApp());
    await tester.pump();
  });
}
