import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/features/authentication/data/in_memory_auth_repository.dart';
import 'package:secure_files_application/features/authentication/presentation/session_cubit.dart';

void main() {
  const pin = '482915';
  final phrase = List.generate(12, (i) => 'word$i');
  late DateTime now;
  late SessionCubit session;

  setUp(() async {
    now = DateTime(2026, 11, 3, 10);
    session = SessionCubit(InMemoryAuthRepository(), clock: () => now);
    await session.createVault(pin: pin, phrase: phrase);
    session.lock();
  });

  tearDown(() => session.close());

  Future<void> failTimes(int n) async {
    for (var i = 0; i < n; i++) {
      await session.unlockWithPin('000001');
    }
  }

  test('correct PIN unlocks', () async {
    expect(await session.unlockWithPin(pin), UnlockResult.success);
    expect(session.state.status, VaultStatus.unlocked);
  });

  test('four wrong PINs are free, the fifth starts a 30 s lockout', () async {
    await failTimes(4);
    expect(session.state.lockedOutUntil, isNull);
    expect(session.attemptsLeft, 1);

    expect(await session.unlockWithPin('000001'), UnlockResult.lockedOut);
    expect(session.state.lockedOutUntil, now.add(const Duration(seconds: 30)));
  });

  test('even the correct PIN is refused during a lockout', () async {
    await failTimes(5);
    expect(await session.unlockWithPin(pin), UnlockResult.lockedOut);

    now = now.add(const Duration(seconds: 31));
    expect(await session.unlockWithPin(pin), UnlockResult.success);
  });

  test('lockout doubles with each further failure', () async {
    await failTimes(5);
    now = now.add(const Duration(seconds: 31));
    await session.unlockWithPin('000001');
    expect(session.state.lockedOutUntil, now.add(const Duration(seconds: 60)));
  });

  test('success resets the failure counter', () async {
    await failTimes(3);
    await session.unlockWithPin(pin);
    expect(session.state.failedAttempts, 0);
  });

  test('recovery phrase replaces a forgotten PIN', () async {
    expect(await session.recover(words: phrase, newPin: '305718'), isTrue);
    session.lock();
    expect(await session.unlockWithPin('305718'), UnlockResult.success);
  });

  test('wrong recovery phrase is rejected', () async {
    final wrong = [...phrase]..[0] = 'nope';
    expect(await session.recover(words: wrong, newPin: '305718'), isFalse);
    expect(session.state.status, VaultStatus.locked);
  });
}
