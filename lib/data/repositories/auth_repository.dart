import 'dart:async';

import '../models/auth_user.dart';

/// The authentication operations available to the UI.
///
/// Implementations own credential handling. In particular, the UI never stores an access token
/// and never talks to Supabase directly.
abstract class AuthRepository {
  /// Current user, read synchronously so the router can make its first redirect decision.
  AuthUser? get currentUser;

  /// Emits after sign-in, sign-up, sign-out, or a restored Supabase session changes.
  Stream<AuthUser?> get userChanges;

  Future<void> signIn({required String email, required String password});

  /// Returns whether the user must confirm their email before a session is available.
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
    required String username,
  });

  Future<void> signOut();
}

class AuthSignUpResult {
  const AuthSignUpResult({required this.requiresEmailConfirmation});

  final bool requiresEmailConfirmation;
}

/// A safe-to-display error returned by an [AuthRepository].
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
