import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_plant_care/screens/navigation_bottombar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ai_plant_care/screens/my_garden_screen.dart';
import 'package:ai_plant_care/screens/tasks/tasks_screen.dart';
import 'package:ai_plant_care/screens/notifications/notification_screen.dart';
import 'package:ai_plant_care/screens/profile_screen.dart';
import 'package:ai_plant_care/screens/ai_scan/scan_screen.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets('Starts in garden and switches between all navigation tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: NavigationBottomBar()));
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
    await tester.pumpWidget(const MaterialApp(home: NavigationBottomBar()));
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.byType(ProfileScreen), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
