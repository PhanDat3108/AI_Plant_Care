import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_plant_care/main.dart';
import 'package:ai_plant_care/screens/my_garden_screen.dart';
import 'package:ai_plant_care/screens/tasks_screen.dart';
import 'package:ai_plant_care/screens/notification_screen.dart';
import 'package:ai_plant_care/screens/profile_screen.dart';
import 'package:ai_plant_care/screens/scan_screen.dart';

void main() {
  testWidgets('Starts in garden and switches between all navigation tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyGardenScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);

    await tester.tap(find.text('Nhiệm vụ'));
    await tester.pumpAndSettle();
    expect(find.byType(TasksScreen), findsOneWidget);
    expect(find.byType(MyGardenScreen), findsNothing);

    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationScreen), findsOneWidget);
    expect(find.byType(TasksScreen), findsNothing);

    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.byType(NotificationScreen), findsNothing);

    await tester.tap(find.text('Vườn cây'));
    await tester.pumpAndSettle();
    expect(find.byType(MyGardenScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Opens scan and returns to the previously selected tab', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
