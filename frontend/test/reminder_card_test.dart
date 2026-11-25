import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_plant_care/screens/plant_detail/plant_detail_cards.dart';
import 'package:ai_plant_care/services/plant_care_service.dart';

void main() {
  testWidgets(
    'Edit remains available when reminder is off and does not toggle it',
    (tester) async {
      var edits = 0;
      var toggles = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToggleReminderCard(
              icon: Icons.water_drop,
              iconColor: Colors.blue,
              title: 'Tưới nước',
              subtitle: 'Mỗi 7 ngày',
              value: false,
              onEdit: () => edits++,
              onChanged: (_) => toggles++,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Chỉnh sửa'));
      expect(edits, 1);
      expect(toggles, 0);
      await tester.tap(find.byType(Switch));
      expect(toggles, 1);
    },
  );

  test('Sync preserves actual due date, baseline and weather explanation', () {
    final result = CarePlanSyncResult.fromJson({
      'warnings': [],
      'weather_source': 'open-meteo',
      'tasks': [
        {
          'id': 'task-1',
          'plant_id': 'plant-1',
          'kind': 'water',
          'due_at': '2026-11-27T01:00:00Z',
          'original_due_at': '2026-11-26T01:00:00Z',
          'adjustment_reason': 'Dự báo mưa: lùi nhắc 1 ngày.',
        },
      ],
    });
    expect(result.tasks.single.dueAt!.toUtc(), DateTime.utc(2026, 11, 27, 1));
    expect(
      result.tasks.single.originalDueAt!.toUtc(),
      DateTime.utc(2026, 11, 26, 1),
    );
    expect(result.tasks.single.adjustmentReason, contains('lùi nhắc'));
    expect(CarePlanSyncResult.fromJson({'warnings': []}).tasks, isEmpty);
  });
}
