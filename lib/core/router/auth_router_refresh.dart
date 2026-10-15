import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/models/auth_user.dart';

/// Bridges the auth stream into the `Listenable` that GoRouter uses to re-run redirects.
class AuthRouterRefresh extends ChangeNotifier {
  AuthRouterRefresh(Stream<AuthUser?> userChanges) {
    _subscription = userChanges.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthUser?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
