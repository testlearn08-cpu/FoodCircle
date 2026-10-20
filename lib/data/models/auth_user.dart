import 'package:flutter/foundation.dart';

/// The small, client-safe identity the app needs from an authenticated session.
///
/// Access tokens and refresh tokens deliberately stay inside the Supabase SDK; UI code never
/// receives them. In demo mode this model is backed by an in-memory identity, not a real account.
@immutable
class AuthUser {
  const AuthUser({required this.id, this.email});

  final String id;
  final String? email;
}
