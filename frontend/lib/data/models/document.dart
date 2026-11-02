import 'package:equatable/equatable.dart';

import 'json.dart';

/// Document types of the OCR registry (`contracts/ocr_api.yaml` DocType ids).
/// `auto` is a UI choice only: `doc_type` is then omitted (auto-detect).
const kDocTypes = ['cni', 'loan_application', 'coffee_receipt', 'complaint_photo'];
const kDocTypeAuto = 'auto';

/// Images accepted by `POST /v1/documents/extract` (jpeg, png or webp, max 10 MB).
const kDocImageMimes = ['image/jpeg', 'image/png', 'image/webp'];
const kDocMaxBytes = 10 * 1024 * 1024;

/// `ExtractedField` of ocr_api.yaml.
class ExtractedField extends Equatable {
  const ExtractedField({
    required this.name,
    required this.value,
    required this.confidence,
    required this.valid,
    required this.needsReview,
  });

  factory ExtractedField.fromJson(Json j) => ExtractedField(
        name: j['name'] as String,
        value: j['value'],
        confidence: toDouble(j['confidence']),
        valid: j['valid'] as bool,
        needsReview: j['needs_review'] as bool,
      );

  final String name;

  /// string | number | integer | null
  final Object? value;
  final double confidence;
  final bool valid;
  final bool needsReview;

  Json toJson() => {'name': name, 'value': value, 'confidence': confidence, 'valid': valid, 'needs_review': needsReview};

  @override
  List<Object?> get props => [name, value, confidence, valid, needsReview];
}

/// `ExtractResult` of ocr_api.yaml, returned by `POST /v1/documents/extract`.
class ExtractResult extends Equatable {
  const ExtractResult({
    required this.docType,
    required this.docTypeConfidence,
    required this.fields,
    required this.needsReview,
    required this.routeTo,
    required this.processingMs,
    required this.engine,
    this.rawText,
  });

  factory ExtractResult.fromJson(Json j) => ExtractResult(
        docType: j['doc_type'] as String,
        docTypeConfidence: toDouble(j['doc_type_confidence']),
        fields: parseList(j['fields'], ExtractedField.fromJson),
        needsReview: j['needs_review'] as bool,
        routeTo: j['route_to'] as String,
        rawText: j['raw_text'] as String?,
        processingMs: j['processing_ms'] as int,
        engine: j['engine'] as String,
      );

  final String docType;
  final double docTypeConfidence;
  final List<ExtractedField> fields;
  final bool needsReview;
  final String routeTo;
  final String? rawText;
  final int processingMs;

  /// paddleocr | tesseract
  final String engine;

  Json toJson() => {
        'doc_type': docType,
        'doc_type_confidence': docTypeConfidence,
        'fields': [for (final f in fields) f.toJson()],
        'needs_review': needsReview,
        'route_to': routeTo,
        if (rawText != null) 'raw_text': rawText,
        'processing_ms': processingMs,
        'engine': engine,
      };

  @override
  List<Object?> get props => [docType, docTypeConfidence, fields, needsReview, routeTo, rawText, processingMs, engine];
}
