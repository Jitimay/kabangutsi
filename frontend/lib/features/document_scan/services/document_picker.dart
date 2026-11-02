import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/repositories.dart';

/// Gets a document photo from the device. Replaced by a fake in widget tests.
abstract interface class DocumentPicker {
  /// Camera available (Android / iOS app; not web or desktop).
  bool get canUseCamera;

  Future<FileUpload?> takePhoto();

  /// File dialog. PDFs are selectable on purpose so the app can explain
  /// that only photos can be read for now.
  Future<FileUpload?> pickFile();
}

class PlatformDocumentPicker implements DocumentPicker {
  const PlatformDocumentPicker();

  @override
  bool get canUseCamera =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<FileUpload?> takePhoto() async {
    // 2400 px keeps text readable for OCR and the file well under 10 MB.
    final f = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2400, maxHeight: 2400, imageQuality: 90);
    return f == null ? null : _upload(f, 'document.jpg');
  }

  @override
  Future<FileUpload?> pickFile() async {
    const images = XTypeGroup(
      label: 'images',
      extensions: ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
      uniformTypeIdentifiers: ['public.jpeg', 'public.png', 'org.webmproject.webp'],
    );
    const pdf = XTypeGroup(
      label: 'PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );
    final f = await openFile(acceptedTypeGroups: const [images, pdf]);
    return f == null ? null : _upload(f, 'document');
  }

  static Future<FileUpload> _upload(XFile f, String fallbackName) async => FileUpload(
        bytes: await f.readAsBytes(),
        filename: f.name.isEmpty ? fallbackName : f.name,
        mime: f.mimeType ?? '',
      );
}
