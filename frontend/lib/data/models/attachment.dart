import 'package:equatable/equatable.dart';

import 'json.dart';

/// `Attachment` of message.schema.json.
class Attachment extends Equatable {
  const Attachment({required this.type, required this.url, required this.mime, this.name, this.sizeBytes, this.durationMs});

  factory Attachment.fromJson(Json j) => Attachment(
        type: j['type'] as String,
        url: j['url'] as String,
        mime: j['mime'] as String,
        name: j['name'] as String?,
        sizeBytes: j['size_bytes'] as int?,
        durationMs: j['duration_ms'] as int?,
      );

  /// image | audio | pdf
  final String type;
  final String url;
  final String mime;
  final String? name;
  final int? sizeBytes;
  final int? durationMs;

  Json toJson() => {
        'type': type,
        'url': url,
        'mime': mime,
        if (name != null) 'name': name,
        if (sizeBytes != null) 'size_bytes': sizeBytes,
        if (durationMs != null) 'duration_ms': durationMs,
      };

  @override
  List<Object?> get props => [type, url, mime, name, sizeBytes, durationMs];
}

/// `FileRef` of openapi.yaml.
class FileRef extends Equatable {
  const FileRef({required this.id, required this.url, required this.type, required this.mime, required this.sizeBytes, required this.createdAt});

  factory FileRef.fromJson(Json j) => FileRef(
        id: j['id'] as String,
        url: j['url'] as String,
        type: j['type'] as String,
        mime: j['mime'] as String,
        sizeBytes: j['size_bytes'] as int,
        createdAt: parseTs(j['created_at']),
      );

  final String id;
  final String url;
  final String type;
  final String mime;
  final int sizeBytes;
  final DateTime createdAt;

  Attachment toAttachment({String? name}) =>
      Attachment(type: type, url: url, mime: mime, name: name, sizeBytes: sizeBytes);

  Json toJson() => {'id': id, 'url': url, 'type': type, 'mime': mime, 'size_bytes': sizeBytes, 'created_at': tsOf(createdAt)};

  @override
  List<Object?> get props => [id, url, type, mime, sizeBytes, createdAt];
}
