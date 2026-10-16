import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../models/auth_user.dart';
import 'auth_repository.dart';

/// Supabase Auth adapter. `supabase_flutter` owns and persists the session on-device.
///
/// The client is initialized with the publishable/anon key in `main.dart`; the privileged
/// `service_role` key must never be supplied to a client build.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get userChanges => _client.auth.onAuthStateChange.map(
        (state) => _mapUser(state.session?.user),
      );

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'username': username.trim()},
      );
      return AuthSignUpResult(
        requiresEmailConfirmation: response.session == null,
      );
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw AuthFailure(error.message);
    }
  }

  static AuthUser? _mapUser(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email);
}
