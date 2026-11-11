import 'package:flutter/material.dart';

import 'api.dart';
import 'page.dart';
import 'resource.dart';

class Schedule extends StatelessWidget {
  const Schedule({super.key});
  @override
  Widget build(BuildContext context) => PlantPage('Lịch chăm sóc', [
    Resource('/care-schedules', (data) {
      final rows = (data as List).cast<Json>();
      return rows.isEmpty
          ? const Text('Chưa có lịch chăm sóc.')
          : Column(
              children: [
                for (final r in rows)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.water_drop_outlined),
                      title: Text(r['task']),
                      subtitle: Text(
                        "${r['plant']['name']} • ${MaterialLocalizations.of(context).formatShortDate(DateTime.parse(r['dueAt']).toLocal())}",
                      ),
                    ),
                  ),
              ],
            );
    }),
  ]);
}
