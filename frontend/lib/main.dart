import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Settings.hasAuth) {
    await Supabase.initialize(
      url: Settings.supabaseUrl,
      publishableKey: Settings.publicKey,
    );
  }
  runApp(const ProviderScope(child: PlantApp()));
}
