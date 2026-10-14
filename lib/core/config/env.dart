/// Build-time configuration.
///
/// Supplied with `--dart-define`, never committed:
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<project>.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=<anon key>
/// ```
///
/// Only the **anon** key belongs in a client build. The `service_role` key bypasses every RLS
/// policy in `supabase/migrations` — shipping it would hand the whole database to anyone who
/// unpacks the app.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Whether a Supabase project was configured at build time.
  ///
  /// When it was not, the app runs against in-memory repositories: every screen works and
  /// nothing is persisted. That is what the web preview in CI and the widget tests use, so the
  /// UI never depends on a project existing.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
