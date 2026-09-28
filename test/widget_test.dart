import 'package:flutter_test/flutter_test.dart';
import 'package:akmusic_flutter/main.dart';

void main() {
  testWidgets('AK Music App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AkMusicApp());
    expect(find.text('AK Music Engine Ready'), findsOneWidget);
  });
}
