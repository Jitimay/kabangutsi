import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/card_block/bloc/card_block_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockCardRepository extends Mock implements CardRepository {}

void main() {
  const pin = '9731';
  const dob = '1988-04-12';
  final pending = CardBlockPending(
    confirmationId: '0c1d2e3f-4a5b-4c6d-8e7f-8a9b0c1d2e3f',
    expiresAt: DateTime.utc(2026, 11, 2, 10, 11),
    card: const CardInfo(last4: '4821', type: 'visa_debit', status: 'active'),
    message: 'Please confirm: block the Visa debit card ending in 4821?',
  );
  final result = CardBlockResult(
    reference: 'BLK-2026-00017',
    card: const CardInfo(last4: '4821', type: 'visa_debit', status: 'blocked'),
    blockedAt: DateTime.utc(2026, 11, 2, 10, 6, 30),
    message: 'Your card ending in 4821 is blocked.',
  );
  late MockCardRepository repo;

  setUpAll(
    () => registerFallbackValue(const CardBlockRequest(accountNumber: '0', pin: '0000', reason: 'lost', lang: 'en')),
  );
  setUp(() => repo = MockCardRepository());

  Future<void> submit(CardBlockCubit c, {String secret = pin}) =>
      c.verify(accountNumber: '40012345678', secret: secret, cardLast4: '4821', lang: 'en');

  blocTest<CardBlockCubit, CardBlockState>(
    'verify → confirm → done with reference',
    setUp: () {
      when(() => repo.verify(any())).thenAnswer((_) async => pending);
      when(() => repo.confirm(any())).thenAnswer((_) async => result);
    },
    build: () => CardBlockCubit(repo),
    act: (c) async {
      await submit(c);
      await c.confirm();
    },
    expect: () => [
      const CardBlockState(step: CardBlockStep.verifying),
      CardBlockState(step: CardBlockStep.confirm, pending: pending),
      CardBlockState(step: CardBlockStep.confirming, pending: pending),
      CardBlockState(step: CardBlockStep.done, result: result),
    ],
    verify: (_) {
      final req = verify_(repo);
      expect(req.pin, pin);
      expect(req.dateOfBirth, isNull);
      expect(req.cardLast4, '4821');
      verify(() => repo.confirm(pending.confirmationId)).called(1);
    },
  );

  blocTest<CardBlockCubit, CardBlockState>(
    'date of birth mode sends date_of_birth, not pin',
    setUp: () => when(() => repo.verify(any())).thenAnswer((_) async => pending),
    build: () => CardBlockCubit(repo),
    act: (c) async {
      c.toggleDateOfBirth(true);
      await submit(c, secret: dob);
    },
    skip: 2,
    expect: () => [CardBlockState(step: CardBlockStep.confirm, useDateOfBirth: true, pending: pending)],
    verify: (_) {
      final req = verify_(repo);
      expect(req.pin, isNull);
      expect(req.dateOfBirth, dob);
    },
  );

  blocTest<CardBlockCubit, CardBlockState>(
    'identity_failed shows attempts left and returns to the form',
    setUp: () => when(() => repo.verify(any())).thenThrow(
      const ApiError(
        code: 'identity_failed',
        message: 'The details do not match.',
        details: {'attempts_left': 2},
        status: 403,
      ),
    ),
    build: () => CardBlockCubit(repo),
    act: submit,
    expect: () => [
      const CardBlockState(step: CardBlockStep.verifying),
      const CardBlockState(step: CardBlockStep.form, failure: CardBlockFailure.identityFailed, attemptsLeft: 2),
    ],
  );

  blocTest<CardBlockCubit, CardBlockState>(
    '423 locked → handed to an agent, further verify ignored',
    setUp: () =>
        when(() => repo.verify(any())).thenThrow(const ApiError(code: 'locked', message: 'Locked', status: 423)),
    build: () => CardBlockCubit(repo),
    act: (c) async {
      await submit(c);
      await submit(c);
    },
    expect: () => [
      const CardBlockState(step: CardBlockStep.verifying),
      const CardBlockState(step: CardBlockStep.locked),
    ],
    verify: (_) => verify(() => repo.verify(any())).called(1),
  );

  blocTest<CardBlockCubit, CardBlockState>(
    '410 expired at confirm → back to form with expired failure',
    setUp: () {
      when(() => repo.verify(any())).thenAnswer((_) async => pending);
      when(() => repo.confirm(any())).thenThrow(const ApiError(code: 'expired', message: 'Expired', status: 410));
    },
    build: () => CardBlockCubit(repo),
    act: (c) async {
      await submit(c);
      await c.confirm();
    },
    skip: 3,
    expect: () => [const CardBlockState(step: CardBlockStep.form, failure: CardBlockFailure.expired)],
  );

  blocTest<CardBlockCubit, CardBlockState>(
    'network error keeps the form',
    setUp: () => when(() => repo.verify(any())).thenThrow(ApiError.network),
    build: () => CardBlockCubit(repo),
    act: submit,
    skip: 1,
    expect: () => [const CardBlockState(step: CardBlockStep.form, failure: CardBlockFailure.network)],
  );

  test('the PIN and date of birth never appear in any state', () async {
    when(
      () => repo.verify(any()),
    ).thenThrow(const ApiError(code: 'identity_failed', message: 'x', details: {'attempts_left': 1}, status: 403));
    final cubit = CardBlockCubit(repo);
    final states = <CardBlockState>[];
    final sub = cubit.stream.listen(states.add);
    await submit(cubit);
    cubit.toggleDateOfBirth(true);
    when(() => repo.verify(any())).thenAnswer((_) async => pending);
    await submit(cubit, secret: dob);
    await sub.cancel();
    await cubit.close();
    expect(states, isNotEmpty);
    for (final s in states) {
      final dump = '${s.props} $s';
      expect(dump.contains(pin), isFalse);
      expect(dump.contains(dob), isFalse);
    }
  });

  test('CardBlockRequest.toString redacts the secret', () {
    const r = CardBlockRequest(accountNumber: '40012345678', pin: pin, reason: 'lost', lang: 'fr');
    expect(r.toString().contains(pin), isFalse);
  });
}

CardBlockRequest verify_(MockCardRepository repo) =>
    verify(() => repo.verify(captureAny())).captured.last as CardBlockRequest;
