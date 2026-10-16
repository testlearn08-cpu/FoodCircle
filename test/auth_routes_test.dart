import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/core/router/auth_routes.dart';

void main() {
  group('auth route helpers', () {
    test('allows a same-app protected destination', () {
      expect(safeNextLocation('/profile'), '/profile');
      expect(safeNextLocation('/recipes?filter=mine'), '/recipes?filter=mine');
    });

    test('rejects external, protocol-relative, and auth-loop targets', () {
      expect(safeNextLocation('https://example.com'), isNull);
      expect(safeNextLocation('//example.com/profile'), isNull);
      expect(safeNextLocation(r'/\\example.com/profile'), isNull);
      expect(safeNextLocation('/sign-in'), isNull);
      expect(safeNextLocation('/sign-up?next=/profile'), isNull);
    });

    test('encodes a return path into an auth route', () {
      expect(
        authRoute(kSignInPath, nextLocation: '/recipes?filter=mine'),
        '/sign-in?next=%2Frecipes%3Ffilter%3Dmine',
      );
    });
  });
}
