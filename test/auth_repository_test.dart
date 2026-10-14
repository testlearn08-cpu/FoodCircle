import 'package:flutter_test/flutter_test.dart';
import 'package:foodcircle/data/models/auth_user.dart';
import 'package:foodcircle/data/repositories/auth_repository.dart';
import 'package:foodcircle/data/repositories/in_memory_auth_repository.dart';

void main() {
  group('InMemoryAuthRepository', () {
    late InMemoryAuthRepository repository;

    setUp(() {
      repository = InMemoryAuthRepository();
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('sign-up creates an ephemeral user and emits the session', () async {
      final events = <AuthUser?>[];
      final subscription = repository.userChanges.listen(events.add);

      final result = await repository.signUp(
        email: 'cook@example.com',
        password: 'demo-password',
        username: 'home_cook',
      );

      expect(result.requiresEmailConfirmation, isFalse);
      expect(repository.currentUser?.email, 'cook@example.com');
      expect(events, hasLength(1));
      expect(events.single?.email, 'cook@example.com');

      await subscription.cancel();
    });

    test('sign-in and sign-out publish the current identity', () async {
      final events = <String?>[];
      final subscription = repository.userChanges.listen(
        (user) => events.add(user?.email),
      );

      await repository.signIn(
        email: 'cook@example.com',
        password: 'demo-password',
      );
      expect(repository.currentUser?.email, 'cook@example.com');

      await repository.signOut();
      expect(repository.currentUser, isNull);
      expect(events, ['cook@example.com', null]);

      await subscription.cancel();
    });

    test(
      'rejects empty credentials rather than creating a signed-in state',
      () async {
        await expectLater(
          repository.signIn(email: ' ', password: ''),
          throwsA(isA<AuthFailure>()),
        );
        expect(repository.currentUser, isNull);
      },
    );

    test('rejects sign-up without a username', () async {
      await expectLater(
        repository.signUp(
          email: 'cook@example.com',
          password: 'demo-password',
          username: ' ',
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(repository.currentUser, isNull);
    });
  });
}
