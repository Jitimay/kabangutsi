import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/document_scan/bloc/document_scan_cubit.dart';
import 'package:mocktail/mocktail.dart';

import 'doc_fixtures.dart';

class MockDocumentRepository extends Mock implements DocumentRepository {}

void main() {
  late MockDocumentRepository repo;
  const conv = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';

  setUpAll(() => registerFallbackValue(jpeg()));
  setUp(() => repo = MockDocumentRepository());

  group('file checks before upload', () {
    blocTest<DocumentScanCubit, DocumentScanState>(
      'jpeg photo → ready',
      build: () => DocumentScanCubit(repo),
      act: (c) => c.filePicked(jpeg()),
      expect: () => [DocumentScanState(status: DocScanStatus.ready, file: jpeg())],
    );

    blocTest<DocumentScanCubit, DocumentScanState>(
      'PDF → pdf explanation, nothing kept, no upload',
      build: () => DocumentScanCubit(repo),
      act: (c) => c.filePicked(pdf()),
      expect: () => [const DocumentScanState(status: DocScanStatus.failure, error: DocScanError.pdf)],
      verify: (_) => verifyNever(() => repo.extract(image: any(named: 'image'), lang: any(named: 'lang'))),
    );

    blocTest<DocumentScanCubit, DocumentScanState>(
      'a PDF renamed .jpg is still detected as PDF (magic bytes)',
      build: () => DocumentScanCubit(repo),
      act: (c) => c.filePicked(FileUpload(bytes: pdfBytes, filename: 'scan.jpg', mime: 'image/jpeg')),
      expect: () => [const DocumentScanState(status: DocScanStatus.failure, error: DocScanError.pdf)],
    );

    blocTest<DocumentScanCubit, DocumentScanState>(
      'webp with no declared type → ready as image/webp',
      build: () => DocumentScanCubit(repo),
      act: (c) => c.filePicked(FileUpload(bytes: webpBytes, filename: 'photo', mime: '')),
      expect: () => [DocumentScanState(status: DocScanStatus.ready, file: FileUpload(bytes: webpBytes, filename: 'photo', mime: 'image/webp'))],
    );

    blocTest<DocumentScanCubit, DocumentScanState>(
      'other file type (gif / docx) → unsupported',
      build: () => DocumentScanCubit(repo),
      act: (c) => c.filePicked(FileUpload(bytes: Uint8List.fromList('GIF89a'.codeUnits), filename: 'a.gif', mime: 'image/gif')),
      expect: () => [const DocumentScanState(status: DocScanStatus.failure, error: DocScanError.unsupported)],
    );

    blocTest<DocumentScanCubit, DocumentScanState>(
      'over 10 MB → tooLarge',
      build: () => DocumentScanCubit(repo),
      act: (c) {
        final big = Uint8List(kDocMaxBytes + 1)..setAll(0, jpegBytes);
        c.filePicked(FileUpload(bytes: big, filename: 'big.jpg', mime: 'image/jpeg'));
      },
      expect: () => [const DocumentScanState(status: DocScanStatus.failure, error: DocScanError.tooLarge)],
    );
  });

  test('detectDocumentMime', () {
    expect(detectDocumentMime(pngBytes, 'x', null), 'image/png');
    expect(detectDocumentMime(Uint8List(0), 'x.JPG', null), 'image/jpeg');
    expect(detectDocumentMime(Uint8List(0), 'x.pdf', 'application/octet-stream'), 'application/pdf');
    expect(detectDocumentMime(Uint8List(0), 'x', 'image/jpg'), 'image/jpeg');
  });

  group('submit', () {
    blocTest<DocumentScanCubit, DocumentScanState>(
      'auto → doc_type omitted; result with fields; agent review in a chat',
      setUp: () => when(() => repo.extract(
            image: any(named: 'image'),
            docType: any(named: 'docType'),
            lang: any(named: 'lang'),
            conversationId: any(named: 'conversationId'),
          )).thenAnswer((_) async => cniResult),
      build: () => DocumentScanCubit(repo, conversationId: conv),
      act: (c) async {
        c.filePicked(jpeg());
        await c.submit('rn');
      },
      skip: 1,
      expect: () => [
        DocumentScanState(status: DocScanStatus.sending, file: jpeg()),
        DocumentScanState(status: DocScanStatus.done, file: jpeg(), result: cniResult),
      ],
      verify: (c) {
        verify(() => repo.extract(image: jpeg(), docType: null, lang: 'rn', conversationId: conv)).called(1);
        expect(c.agentReview, isTrue);
      },
    );

    blocTest<DocumentScanCubit, DocumentScanState>(
      'chosen type is sent; without a conversation there is no agent review',
      setUp: () => when(() => repo.extract(
            image: any(named: 'image'),
            docType: any(named: 'docType'),
            lang: any(named: 'lang'),
            conversationId: any(named: 'conversationId'),
          )).thenAnswer((_) async => cniResult),
      build: () => DocumentScanCubit(repo, initialDocType: 'cni'),
      act: (c) async {
        c.filePicked(jpeg());
        await c.submit('fr');
      },
      verify: (c) {
        verify(() => repo.extract(image: jpeg(), docType: 'cni', lang: 'fr', conversationId: null)).called(1);
        expect(c.state.result, cniResult);
        expect(c.agentReview, isFalse);
      },
    );

    for (final (err, expected) in [
      (const ApiError(code: 'service_unavailable', message: 'OCR service unavailable', status: 503), DocScanError.unavailable),
      (const ApiError(code: 'too_large', message: 'x', status: 413), DocScanError.tooLarge),
      (const ApiError(code: 'unsupported_media_type', message: 'x', status: 415), DocScanError.unsupported),
      (const ApiError(code: 'validation_error', message: 'x', status: 422), DocScanError.invalid),
      (ApiError.network, DocScanError.network),
      (const ApiError(code: 'internal_error', message: 'x', status: 500), DocScanError.generic),
    ]) {
      blocTest<DocumentScanCubit, DocumentScanState>(
        '${err.status ?? err.code} → $expected, file kept for a retry',
        setUp: () => when(() => repo.extract(
              image: any(named: 'image'),
              docType: any(named: 'docType'),
              lang: any(named: 'lang'),
              conversationId: any(named: 'conversationId'),
            )).thenThrow(err),
        build: () => DocumentScanCubit(repo),
        act: (c) async {
          c.filePicked(jpeg());
          await c.submit('en');
        },
        verify: (c) {
          expect(c.state.status, DocScanStatus.failure);
          expect(c.state.error, expected);
          expect(c.state.file, jpeg());
        },
      );
    }

    blocTest<DocumentScanCubit, DocumentScanState>(
      'reset keeps the chosen type',
      build: () => DocumentScanCubit(repo, initialDocType: 'coffee_receipt'),
      act: (c) {
        c.filePicked(jpeg());
        c.reset();
      },
      skip: 1,
      expect: () => [const DocumentScanState(docType: 'coffee_receipt')],
    );
  });
}
