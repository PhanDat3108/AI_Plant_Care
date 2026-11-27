import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_plant_care/widgets/primary_button.dart';

void main() {
  testWidgets('Loading prevents duplicate submission and recovers afterwards', (
    tester,
  ) async {
    var submissions = 0;
    Widget page(bool loading) => MaterialApp(
      home: Scaffold(
        body: PrimaryButton(
          label: 'Đăng nhập',
          loading: loading,
          onPressed: () => submissions++,
        ),
      ),
    );
    await tester.pumpWidget(page(true));
    await tester.tap(find.byType(ElevatedButton));
    expect(submissions, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(page(false));
    await tester.tap(find.text('Đăng nhập'));
    expect(submissions, 1);
  });
  testWidgets('Primary action meets Android target and label guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(label: 'Đăng nhập', onPressed: () {}),
        ),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
