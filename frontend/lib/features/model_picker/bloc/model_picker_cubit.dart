import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

enum ModelPickerStatus { initial, loading, ready, failure }

class ModelPickerState extends Equatable {
  const ModelPickerState({
    this.status = ModelPickerStatus.initial,
    this.models = const [],
    this.defaultModel,
    this.selected,
    this.conversationId,
    this.updating = false,
    this.error,
  });

  final ModelPickerStatus status;

  /// Installed models with capabilities, as returned by `GET /v1/models` (F19).
  final List<LlmModel> models;
  final String? defaultModel;

  /// The user's choice for this session; null = backend default.
  final String? selected;

  /// Conversation the choice applies to (PATCH /v1/conversations/{id}).
  final String? conversationId;
  final bool updating;
  final ApiError? error;

  /// The model actually in use for the session.
  String? get effective => selected ?? defaultModel;

  LlmModel? get effectiveModel {
    for (final m in models) {
      if (m.name == effective) return m;
    }
    return null;
  }

  ModelPickerState copyWith({
    ModelPickerStatus? status,
    List<LlmModel>? models,
    String? Function()? defaultModel,
    String? Function()? selected,
    String? Function()? conversationId,
    bool? updating,
    ApiError? Function()? error,
  }) =>
      ModelPickerState(
        status: status ?? this.status,
        models: models ?? this.models,
        defaultModel: defaultModel != null ? defaultModel() : this.defaultModel,
        selected: selected != null ? selected() : this.selected,
        conversationId: conversationId != null ? conversationId() : this.conversationId,
        updating: updating ?? this.updating,
        error: error != null ? error() : this.error,
      );

  @override
  List<Object?> get props => [status, models, defaultModel, selected, conversationId, updating, error];
}

/// F19: model picker. Models and their capability badges come from the API,
/// never hard-coded. The choice is kept per session (conversation).
class ModelPickerCubit extends Cubit<ModelPickerState> {
  ModelPickerCubit(this._models, this._conversations) : super(const ModelPickerState());

  final ModelRepository _models;
  final ConversationRepository _conversations;

  /// Used by the session holder to detect a DI reset.
  ModelRepository get modelRepository => _models;

  Future<void> load({bool refresh = false}) async {
    emit(state.copyWith(status: ModelPickerStatus.loading, error: () => null));
    try {
      final list = await _models.listModels(refresh: refresh);
      final stillThere = list.models.any((m) => m.name == state.selected && m.selectable);
      emit(state.copyWith(
        status: ModelPickerStatus.ready,
        models: list.models,
        defaultModel: () => list.defaultModel,
        selected: stillThere ? null : () => null,
      ));
    } on ApiError catch (e) {
      emit(state.copyWith(status: ModelPickerStatus.failure, error: () => e));
    }
  }

  /// Links the choice to a conversation; a choice made before the conversation
  /// existed is applied to it.
  Future<void> attachConversation(String? conversationId) async {
    if (conversationId == state.conversationId) return;
    emit(state.copyWith(conversationId: () => conversationId));
  }

  Future<void> select(String name) async {
    final model = state.models.where((m) => m.name == name).firstOrNull;
    if (model == null || !model.selectable || name == state.effective) return;
    final previous = state.selected;
    emit(state.copyWith(selected: () => name, error: () => null));
    final id = state.conversationId;
    if (id == null) return;
    emit(state.copyWith(updating: true));
    try {
      await _conversations.update(id, model: name);
      emit(state.copyWith(updating: false));
    } on ApiError catch (e) {
      emit(state.copyWith(updating: false, selected: () => previous, error: () => e));
    }
  }
}
