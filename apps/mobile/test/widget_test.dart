import 'package:ai_plant_care/app/app.dart';
import 'package:ai_plant_care/features/plant_scan/data/scan.dart';
import 'package:ai_plant_care/features/plant_scan/presentation/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Trang chủ mở trình quét ảnh', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: PlantApp()));
    await tester.tap(find.text('Quét ảnh cây'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn từ thư viện'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Phân tích ảnh'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('Kết quả phân biệt dữ liệu minh họa', (tester) async {
    final r = ScanResult.fromJson({
      'isMock': true,
      'species': {'name': 'Epipremnum aureum', 'probability': 0.94},
      'diseases': [],
      'care': 'Ánh sáng gián tiếp',
    });
    await tester.pumpWidget(MaterialApp(home: Result(r)));
    expect(find.text('Dữ liệu giả lập'), findsOneWidget);
    expect(find.text('Epipremnum aureum • 94%'), findsOneWidget);
  });
}
