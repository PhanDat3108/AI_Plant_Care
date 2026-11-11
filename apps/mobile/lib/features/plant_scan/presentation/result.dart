import 'package:flutter/material.dart';

import '../data/scan.dart';
import '../../../shared/widgets/page.dart';

class Result extends StatelessWidget {
  final ScanResult? result;
  const Result(this.result, {super.key});
  @override
  Widget build(BuildContext context) {
    final r = result;
    return PlantPage(
      'Kết quả phân tích',
      r == null
          ? [const Text('Hãy chọn ảnh để phân tích.')]
          : [
              if (r.isMock)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.science_outlined),
                    title: Text('Dữ liệu giả lập'),
                    subtitle: Text('Ví dụ minh họa dùng chung cho mọi ảnh.'),
                  ),
                ),
              ListTile(
                title: const Text('Loài cây'),
                subtitle: Text(r.species.label),
              ),
              ListTile(
                title: const Text('Tình trạng nghi ngờ'),
                subtitle: Text(
                  r.diseases.isEmpty
                      ? 'Chưa ghi nhận nhãn bệnh.'
                      : r.diseases.map((p) => p.label).join('\n'),
                ),
              ),
              if (r.possibleCause != null)
                ListTile(
                  title: const Text('Nguyên nhân có thể'),
                  subtitle: Text(r.possibleCause!),
                ),
              ListTile(
                title: const Text('Cách chăm sóc'),
                subtitle: Text(r.care),
              ),
            ],
    );
  }
}
