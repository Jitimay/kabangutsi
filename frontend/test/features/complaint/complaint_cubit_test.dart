import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/complaint/bloc/complaint_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockTicketRepository extends Mock implements TicketRepository {}

class MockFileRepository extends Mock implements FileRepository {}

void main() {
  final photo = FileUpload(bytes: Uint8List.fromList([1, 2, 3]), filename: 'atm.jpg', mime: 'image/jpeg');
  final fileRef = FileRef(
    id: '7d1f6a52-3c1e-4f0b-9a7e-2b6f0d4c8e11',
    url: '/v1/files/7d1f6a52-3c1e-4f0b-9a7e-2b6f0d4c8e11',
    type: 'image',
    mime: 'image/jpeg',
    sizeBytes: 3,
    createdAt: DateTime.utc(2026, 11, 2),
  );
  final ticket = Ticket(
    id: 'c9d0e1f2-a3b4-4c5d-8e6f-7a8b9c0d1e2f',
    number: 'TCK-2026-00042',
    callId: null,
    phone: '+25779000110',
    category: 'atm',
    urgency: 'high',
    summary: 'ATM swallowed the card.',
    status: 'open',
    lang: 'fr',
    createdAt: DateTime.utc(2026, 11, 2),
    updatedAt: DateTime.utc(2026, 11, 2),
  );
  late MockTicketRepository tickets;
  late MockFileRepository files;

  setUpAll(() {
    registerFallbackValue(const TicketCreate(category: 'other', urgency: 'low', description: 'x', lang: 'fr'));
    registerFallbackValue(FileUpload(bytes: Uint8List(0), filename: 'f', mime: 'image/jpeg'));
  });
  setUp(() {
    tickets = MockTicketRepository();
    files = MockFileRepository();
  });

  blocTest<ComplaintCubit, ComplaintState>(
    'uploads the photo, creates the ticket and shows its number',
    setUp: () {
      when(() => files.upload(any())).thenAnswer((_) async => fileRef);
      when(() => tickets.create(any())).thenAnswer((_) async => ticket);
    },
    build: () => ComplaintCubit(tickets, files),
    act: (c) async {
      c
        ..selectCategory('atm')
        ..selectUrgency('high')
        ..setPhoto(photo);
      await c.submit(description: '  Le GAB a avalé ma carte  ', phone: '+25779000110', lang: 'fr');
    },
    skip: 3,
    expect: () => [
      ComplaintState(status: ComplaintStatus.submitting, category: 'atm', urgency: 'high', photo: photo),
      ComplaintState(status: ComplaintStatus.success, category: 'atm', urgency: 'high', photo: photo, ticket: ticket),
    ],
    verify: (_) {
      final created = verify(() => tickets.create(captureAny())).captured.single as TicketCreate;
      expect(created.category, 'atm');
      expect(created.urgency, 'high');
      expect(created.description, 'Le GAB a avalé ma carte');
      expect(created.phone, '+25779000110');
      expect(created.attachments.single.url, fileRef.url);
    },
  );

  blocTest<ComplaintCubit, ComplaintState>(
    'no photo → no upload; empty phone sent as null',
    setUp: () => when(() => tickets.create(any())).thenAnswer((_) async => ticket),
    build: () => ComplaintCubit(tickets, files),
    act: (c) => c.submit(description: 'Frais prélevés deux fois', phone: '', lang: 'fr'),
    skip: 1,
    expect: () => [ComplaintState(status: ComplaintStatus.success, ticket: ticket)],
    verify: (_) {
      verifyNever(() => files.upload(any()));
      final created = verify(() => tickets.create(captureAny())).captured.single as TicketCreate;
      expect(created.phone, isNull);
      expect(created.urgency, 'medium');
    },
  );

  blocTest<ComplaintCubit, ComplaintState>(
    'upload failure → upload error, no ticket created',
    setUp: () =>
        when(() => files.upload(any())).thenThrow(const ApiError(code: 'too_large', message: 'Too large', status: 413)),
    build: () => ComplaintCubit(tickets, files),
    seed: () => ComplaintState(photo: photo),
    act: (c) => c.submit(description: 'Photo', lang: 'en'),
    skip: 1,
    expect: () => [
      ComplaintState(
        status: ComplaintStatus.failure,
        photo: photo,
        failure: ComplaintFailure.upload,
        error: const ApiError(code: 'too_large', message: 'Too large', status: 413),
      ),
    ],
    verify: (_) => verifyNever(() => tickets.create(any())),
  );

  blocTest<ComplaintCubit, ComplaintState>(
    'create failure → generic error',
    setUp: () => when(() => tickets.create(any())).thenThrow(ApiError.network),
    build: () => ComplaintCubit(tickets, files),
    act: (c) => c.submit(description: 'Service lent', lang: 'rn'),
    skip: 1,
    expect: () => [
      const ComplaintState(status: ComplaintStatus.failure, failure: ComplaintFailure.generic, error: ApiError.network),
    ],
  );

  test('phone pattern', () {
    expect(ComplaintCubit.phonePattern.hasMatch('+25779000110'), isTrue);
    expect(ComplaintCubit.phonePattern.hasMatch('79000110'), isFalse);
  });
}
