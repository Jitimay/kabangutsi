import 'dart:typed_data';

import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';

/// Minimal files with the right magic bytes (content is not decoded).
final jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0x10, 0x4A, 0x46, 0x49, 0x46]);
final pngBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
final webpBytes = Uint8List.fromList([0x52, 0x49, 0x46, 0x46, 1, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 0x56, 0x50]);
final pdfBytes = Uint8List.fromList('%PDF-1.7\n'.codeUnits);

FileUpload jpeg([String name = 'cni.jpg']) => FileUpload(bytes: jpegBytes, filename: name, mime: 'image/jpeg');
FileUpload pdf([String name = 'releve.pdf']) => FileUpload(bytes: pdfBytes, filename: name, mime: 'application/pdf');

const cniResult = ExtractResult(
  docType: 'cni',
  docTypeConfidence: 0.92,
  fields: [
    ExtractedField(name: 'full_name', value: 'NIYONZIMA Claudine', confidence: 0.94, valid: true, needsReview: false),
    ExtractedField(name: 'id_number', value: '0000/DEMO/123', confidence: 0.71, valid: true, needsReview: true),
  ],
  needsReview: true,
  routeTo: 'account_opening',
  processingMs: 2850,
  engine: 'paddleocr',
);
