import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api.dart';
import '../../../shared/widgets/page.dart';
import '../../../shared/widgets/resource.dart';

class Garden extends StatelessWidget {
  const Garden({super.key});
  @override
  Widget build(BuildContext context) => PlantPage('Vườn của tôi', [
    Resource('/plants', (data) {
      final plants = (data as List).cast<Json>();
      if (plants.isEmpty) return const Text('Vườn của bạn chưa có cây.');
      return Column(
        children: [
          for (final p in plants)
            Card(
              child: ListTile(
                leading: const Icon(Icons.eco_outlined),
                title: Text(p['name']),
                subtitle: Text(p['species']?['scientificName'] ?? ''),
                onTap: () => context.push('/garden/${p['id']}'),
              ),
            ),
        ],
      );
    }),
  ]);
}

class PlantDetail extends StatelessWidget {
  final String id;
  const PlantDetail(this.id, {super.key});
  @override
  Widget build(BuildContext context) => PlantPage('Chi tiết cây', [
    Resource(
      '/plants/$id',
      (p) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p['name'], style: Theme.of(context).textTheme.headlineMedium),
          Text(p['species']?['scientificName'] ?? 'Chưa xác định loài'),
          const Divider(),
          Text(p['notes'] == '' ? 'Chưa có ghi chú.' : p['notes']),
        ],
      ),
    ),
  ]);
}
