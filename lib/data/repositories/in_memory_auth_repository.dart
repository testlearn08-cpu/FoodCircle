import 'dart:async';

import '../models/auth_user.dart';
import 'auth_repository.dart';

/// Demo-only auth for builds without Supabase configuration.
///
/// It accepts any non-empty email/password pair and keeps only an ephemeral identity in memory.
/// It is intentionally not a credential store or an authentication boundary. The UI labels this
/// mode clearly; a configured build uses the Supabase auth adapter instead.
class InMemoryAuthRepository implements AuthRepository {
  InMemoryAuthRepository({AuthUser? initialUser}) : _currentUser = initialUser;

  /// The identity every demo sign-in becomes.
  ///
  /// Deliberately the same id as the seeded demo author in [InMemoryRecipeRepository.seeded], so
  /// that a demo build hangs together: signing in makes you the author of the recipes already in
  /// the feed, which is what makes "create a recipe, then see it in your recipe box" demoable
  /// without a Supabase project. It is not a UUID and does not need to be — nothing on this path
  /// talks to Postgres, where the column is a real `uuid`.
  static const String demoUserId = 'demo-ana';

  final StreamController<AuthUser?> _userChanges =
      StreamController<AuthUser?>.broadcast(sync: true);

  AuthUser? _currentUser;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get userChanges => _userChanges.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || password.isEmpty) {
      throw const AuthFailure('Enter an email address and password.');
    }

    _setCurrentUser(AuthUser(id: demoUserId, email: normalizedEmail));
  }

  @override
  Future<AuthSignUpResult> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedUsername = username.trim();
    if (normalizedEmail.isEmpty ||
        normalizedUsername.isEmpty ||
        password.isEmpty) {
      throw const AuthFailure('Complete all fields to create an account.');
    }

    _setCurrentUser(AuthUser(id: demoUserId, email: normalizedEmail));
    return const AuthSignUpResult(requiresEmailConfirmation: false);
  }

  @override
  Future<void> signOut() async {
    _setCurrentUser(null);
  }

  /// Disposes the demo stream when its Riverpod provider is disposed.
  Future<void> dispose() => _userChanges.close();

  void _setCurrentUser(AuthUser? user) {
    _currentUser = user;
    if (!_userChanges.isClosed) _userChanges.add(user);
  }
}
