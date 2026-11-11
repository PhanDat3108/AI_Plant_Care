import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/home.dart';
import '../features/my_garden/presentation/garden.dart';
import '../features/profile/presentation/profile.dart';
import '../features/plant_care/presentation/schedule.dart';
import '../features/plant_scan/presentation/scan.dart';
import '../features/plant_scan/presentation/result.dart';
import '../features/plant_scan/data/scan.dart';

final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, s) => const Home()),
    GoRoute(path: '/scan', builder: (_, s) => const Scan()),
    GoRoute(path: '/result', builder: (_, s) => Result(s.extra as ScanResult?)),
    GoRoute(path: '/garden', builder: (_, s) => const Garden()),
    GoRoute(
      path: '/garden/:id',
      builder: (_, s) => PlantDetail(s.pathParameters['id']!),
    ),
    GoRoute(path: '/care', builder: (_, s) => const Schedule()),
    GoRoute(path: '/profile', builder: (_, s) => const Profile()),
  ],
);

class PlantApp extends StatelessWidget {
  const PlantApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'AI Plant Care',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff346d49)),
    ),
    routerConfig: router,
  );
}
