import 'package:equatable/equatable.dart';

import 'json.dart';

/// `Model` of openapi.yaml. Capabilities come from Ollama at runtime (F19).
class LlmModel extends Equatable {
  const LlmModel({
    required this.name,
    required this.family,
    required this.parameterSize,
    required this.quantization,
    required this.sizeBytes,
    required this.capabilities,
    required this.selectable,
    required this.isDefault,
  });

  factory LlmModel.fromJson(Json j) => LlmModel(
        name: j['name'] as String,
        family: j['family'] as String?,
        parameterSize: j['parameter_size'] as String?,
        quantization: j['quantization'] as String?,
        sizeBytes: j['size_bytes'] as int?,
        capabilities: parseStrings(j['capabilities']),
        selectable: j['selectable'] as bool,
        isDefault: j['is_default'] as bool,
      );

  final String name;
  final String? family;
  final String? parameterSize;
  final String? quantization;
  final int? sizeBytes;
  final List<String> capabilities;
  final bool selectable;
  final bool isDefault;

  bool can(String capability) => capabilities.contains(capability);

  @override
  List<Object?> get props => [name, family, parameterSize, quantization, sizeBytes, capabilities, selectable, isDefault];
}

/// `ModelList` of openapi.yaml.
class ModelList extends Equatable {
  const ModelList({required this.defaultModel, required this.preferenceOrder, required this.models});

  factory ModelList.fromJson(Json j) => ModelList(
        defaultModel: j['default_model'] as String,
        preferenceOrder: parseStrings(j['preference_order']),
        models: parseList(j['models'], LlmModel.fromJson),
      );

  final String defaultModel;
  final List<String> preferenceOrder;
  final List<LlmModel> models;

  @override
  List<Object?> get props => [defaultModel, preferenceOrder, models];
}
