/// Build-time configuration.
///
/// Supplied with `--dart-define`, never committed:
///
/// ```bash
/// flutter run \
///   --dart-define=SUPABASE_URL=https://<project>.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable ("anon") key>
/// ```
///
/// Only a **publishable** key belongs in a client build. (The dashboard has called the same
/// value the "anon key" for years, and the SDK has deprecated `anonKey` in favour of
/// `publishableKey` — either name means the key that is safe to ship.) The `service_role` key
/// bypasses every RLS policy in `supabase/migrations`: shipping *that* would hand the whole
/// database to anyone who unpacks the app.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// Whether a Supabase project was configured at build time.
  ///
  /// When it was not, the app runs against in-memory repositories: every screen works and
  /// nothing is persisted. That is what the web preview in CI and the widget tests use, so the
  /// UI never depends on a project existing.
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;
}
