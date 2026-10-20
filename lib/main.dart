import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No project configured (no --dart-define, or the preview and test builds) is a supported
  // state, not an error: the app then runs against the in-memory repositories and says so in
  // the UI. See lib/core/providers.dart.
  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // The SDK renamed this parameter; the value is the same publishable/"anon" key the
      // Supabase dashboard shows for a project.
      publishableKey: Env.supabaseKey,
    );
  }

  runApp(const ProviderScope(child: FoodCircleApp()));
}
