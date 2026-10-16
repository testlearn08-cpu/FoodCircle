const String kFeedPath = '/feed';
const String kRecipesPath = '/recipes';
const String kProfilePath = '/profile';
const String kSignInPath = '/sign-in';
const String kSignUpPath = '/sign-up';

/// The feed and auth pages are public; the account destinations require a session.
bool requiresAuthenticatedUser(String path) =>
    path == kRecipesPath ||
    path.startsWith('$kRecipesPath/') ||
    path == kProfilePath ||
    path.startsWith('$kProfilePath/');

/// Accept only app-local return paths. This prevents an auth link from becoming an open redirect.
String? safeNextLocation(String? candidate) {
  if (candidate == null ||
      !candidate.startsWith('/') ||
      candidate.startsWith('//') ||
      candidate.contains('\\')) {
    return null;
  }

  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (uri.path == kSignInPath || uri.path == kSignUpPath) return null;
  return candidate;
}

/// Builds an auth URL while preserving the in-app destination the user was trying to visit.
String authRoute(String path, {String? nextLocation}) {
  final safeNext = safeNextLocation(nextLocation);
  return Uri(
    path: path,
    queryParameters: safeNext == null ? null : {'next': safeNext},
  ).toString();
}
