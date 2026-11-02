import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

enum DocScanStatus { idle, ready, sending, done, failure }

enum DocScanError { pdf, unsupported, tooLarge, invalid, unavailable, network, generic }

/// F17 customer side: choose a type, take or pick a photo, read it with
/// `POST /v1/documents/extract`.
class DocumentScanState extends Equatable {
  const DocumentScanState({
    this.docType = kDocTypeAuto,
    this.status = DocScanStatus.idle,
    this.file,
    this.result,
    this.error,
  });

  /// `auto` or one of [kDocTypes].
  final String docType;
  final DocScanStatus status;
  final FileUpload? file;
  final ExtractResult? result;
  final DocScanError? error;

  DocumentScanState copyWith({
    String? docType,
    DocScanStatus? status,
    FileUpload? Function()? file,
    ExtractResult? Function()? result,
    DocScanError? Function()? error,
  }) =>
      DocumentScanState(
        docType: docType ?? this.docType,
        status: status ?? this.status,
        file: file != null ? file() : this.file,
        result: result != null ? result() : this.result,
        error: error != null ? error() : this.error,
      );

  @override
  List<Object?> get props => [docType, status, file, result, error];
}

class DocumentScanCubit extends Cubit<DocumentScanState> {
  DocumentScanCubit(this._repo, {this.conversationId, String initialDocType = kDocTypeAuto})
      : super(DocumentScanState(docType: initialDocType));

  final DocumentRepository _repo;

  /// Set when opened from a chat: a field to check hands the call to an agent.
  final String? conversationId;

  /// True when the backend handed this conversation to an agent for review.
  bool get agentReview => conversationId != null && (state.result?.needsReview ?? false);

  void selectType(String docType) {
    if (state.status == DocScanStatus.sending) return;
    emit(state.copyWith(docType: docType));
  }

  /// A photo was taken or a file chosen. Checked here before any upload:
  /// only jpeg / png / webp up to 10 MB (a PDF gets its own explanation).
  void filePicked(FileUpload picked) {
    if (state.status == DocScanStatus.sending) return;
    final mime = detectDocumentMime(picked.bytes, picked.filename, picked.mime);
    final error = switch (mime) {
      'application/pdf' => DocScanError.pdf,
      _ when !kDocImageMimes.contains(mime) => DocScanError.unsupported,
      _ when picked.bytes.length > kDocMaxBytes => DocScanError.tooLarge,
      _ when picked.bytes.isEmpty => DocScanError.invalid,
      _ => null,
    };
    if (error != null) {
      emit(state.copyWith(status: DocScanStatus.failure, error: () => error, file: () => null, result: () => null));
      return;
    }
    final file = FileUpload(bytes: picked.bytes, filename: picked.filename, mime: mime!);
    emit(state.copyWith(status: DocScanStatus.ready, file: () => file, result: () => null, error: () => null));
  }

  Future<void> submit(String lang) async {
    final file = state.file;
    if (file == null || state.status == DocScanStatus.sending) return;
    emit(state.copyWith(status: DocScanStatus.sending, error: () => null));
    try {
      final result = await _repo.extract(
        image: file,
        docType: state.docType == kDocTypeAuto ? null : state.docType,
        lang: lang,
        conversationId: conversationId,
      );
      emit(state.copyWith(status: DocScanStatus.done, result: () => result));
    } on ApiError catch (e) {
      emit(state.copyWith(status: DocScanStatus.failure, error: () => errorOf(e)));
    }
  }

  /// Back to an empty picker, keeping the chosen type.
  void reset() => emit(DocumentScanState(docType: state.docType));

  static DocScanError errorOf(ApiError e) => switch (e) {
        ApiError(status: 503) || ApiError(code: 'service_unavailable') => DocScanError.unavailable,
        ApiError(status: 413) || ApiError(code: 'too_large') => DocScanError.tooLarge,
        ApiError(status: 415) || ApiError(code: 'unsupported_media_type') => DocScanError.unsupported,
        ApiError(status: 422) || ApiError(code: 'validation_error') => DocScanError.invalid,
        ApiError(code: 'network_error') => DocScanError.network,
        _ => DocScanError.generic,
      };
}

/// Real type of a picked file: magic bytes first (browsers and pickers often
/// report nothing or a wrong type), then the declared type, then the extension.
String? detectDocumentMime(Uint8List bytes, String filename, String? declared) {
  bool starts(List<int> sig, [int at = 0]) {
    if (bytes.length < at + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[at + i] != sig[i]) return false;
    }
    return true;
  }

  if (starts([0x25, 0x50, 0x44, 0x46])) return 'application/pdf'; // %PDF
  if (starts([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (starts([0x52, 0x49, 0x46, 0x46]) && starts([0x57, 0x45, 0x42, 0x50], 8)) return 'image/webp';
  final d = declared?.split(';').first.trim().toLowerCase();
  if (d != null && d.isNotEmpty && d != 'application/octet-stream') return d == 'image/jpg' ? 'image/jpeg' : d;
  final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    '' => null,
    _ => 'application/octet-stream',
  };
}
