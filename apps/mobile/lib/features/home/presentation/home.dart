import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/page.dart';

class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext context) => PlantPage('AI Plant Care', [
    Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xff184d37),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.eco, color: Color(0xffc4eaaa), size: 38),
          SizedBox(height: 14),
          Text(
            'Chăm cây mỗi ngày',
            style: TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Chụp một chiếc lá để tìm hiểu loài cây và cách chăm sóc.',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    FilledButton.icon(
      onPressed: () => context.push('/scan'),
      icon: const Icon(Icons.camera_alt_outlined),
      label: const Text('Quét ảnh cây'),
    ),
    for (final item in [
      (Icons.yard_outlined, 'Vườn của tôi', '/garden'),
      (Icons.calendar_month_outlined, 'Lịch chăm sóc', '/care'),
      (Icons.person_outline, 'Tài khoản', '/profile'),
    ])
      Card(
        child: ListTile(
          leading: Icon(item.$1),
          title: Text(item.$2),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(item.$3),
        ),
      ),
  ]);
}
