import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api.dart';

class Resource extends ConsumerWidget {
  final String path;
  final Widget Function(dynamic data) builder;
  const Resource(this.path, this.builder, {super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(resourceProvider(path))
      .when(
        data: builder,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Column(
          children: [
            Text(explain(e)),
            TextButton(
              onPressed: () => ref.invalidate(resourceProvider(path)),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
}
