import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/model_picker/bloc/model_picker_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockModels extends Mock implements ModelRepository {}

class MockConversations extends Mock implements ConversationRepository {}

const _e4b = LlmModel(
    name: 'gemma4:e4b', family: 'gemma4', parameterSize: '7.5B', quantization: 'Q4_K_M', sizeBytes: 1,
    capabilities: ['completion', 'vision', 'audio', 'tools', 'thinking'], selectable: true, isDefault: false);
const _gemma2b = LlmModel(
    name: 'gemma:2b', family: 'gemma', parameterSize: '3B', quantization: 'Q4_0', sizeBytes: 1,
    capabilities: ['completion'], selectable: true, isDefault: true);
const _embed = LlmModel(
    name: 'nomic-embed-text:latest', family: 'nomic-bert', parameterSize: '137M', quantization: 'F16', sizeBytes: 1,
    capabilities: ['embedding'], selectable: false, isDefault: false);
const _list = ModelList(defaultModel: 'gemma:2b', preferenceOrder: ['gemma4:e4b', 'gemma:2b'], models: [_e4b, _gemma2b, _embed]);

void main() {
  late MockModels models;
  late MockConversations conversations;

  setUp(() {
    models = MockModels();
    conversations = MockConversations();
    when(() => models.listModels(refresh: any(named: 'refresh'))).thenAnswer((_) async => _list);
  });

  group('ModelPickerCubit', () {
    blocTest<ModelPickerCubit, ModelPickerState>(
      'loads models with capabilities from the API; default from default_model',
      build: () => ModelPickerCubit(models, conversations),
      act: (c) => c.load(),
      expect: () => [
        const ModelPickerState(status: ModelPickerStatus.loading),
        const ModelPickerState(status: ModelPickerStatus.ready, models: [_e4b, _gemma2b, _embed], defaultModel: 'gemma:2b'),
      ],
      verify: (c) {
        expect(c.state.effective, 'gemma:2b');
        expect(c.state.effectiveModel?.capabilities, ['completion']);
      },
    );

    blocTest<ModelPickerCubit, ModelPickerState>(
      'refresh passes refresh=true',
      build: () => ModelPickerCubit(models, conversations),
      act: (c) => c.load(refresh: true),
      verify: (_) => verify(() => models.listModels(refresh: true)).called(1),
    );

    blocTest<ModelPickerCubit, ModelPickerState>(
      'error → failure',
      build: () {
        when(() => models.listModels(refresh: any(named: 'refresh')))
            .thenThrow(const ApiError(code: 'service_unavailable', message: 'Ollama down', status: 503));
        return ModelPickerCubit(models, conversations);
      },
      act: (c) => c.load(),
      expect: () => [
        const ModelPickerState(status: ModelPickerStatus.loading),
        const ModelPickerState(
            status: ModelPickerStatus.failure,
            error: ApiError(code: 'service_unavailable', message: 'Ollama down', status: 503)),
      ],
    );

    blocTest<ModelPickerCubit, ModelPickerState>(
      'select before a conversation exists keeps the choice locally',
      build: () => ModelPickerCubit(models, conversations),
      act: (c) async {
        await c.load();
        await c.select('gemma4:e4b');
      },
      verify: (c) {
        expect(c.state.selected, 'gemma4:e4b');
        verifyNever(() => conversations.update(any(), model: any(named: 'model')));
      },
    );

    blocTest<ModelPickerCubit, ModelPickerState>(
      'select with a conversation PATCHes the session model',
      build: () {
        when(() => conversations.update('c1', model: 'gemma4:e4b')).thenAnswer((_) async => Conversation(
            id: 'c1', channel: 'web', phone: null, lang: 'fr', model: 'gemma4:e4b', status: 'active', startedAt: DateTime.utc(2026)));
        return ModelPickerCubit(models, conversations);
      },
      act: (c) async {
        await c.load();
        await c.attachConversation('c1');
        await c.select('gemma4:e4b');
      },
      verify: (c) {
        verify(() => conversations.update('c1', model: 'gemma4:e4b')).called(1);
        expect(c.state.selected, 'gemma4:e4b');
        expect(c.state.updating, isFalse);
      },
    );

    blocTest<ModelPickerCubit, ModelPickerState>(
      'failed PATCH reverts the choice and reports the error',
      build: () {
        when(() => conversations.update(any(), model: any(named: 'model')))
            .thenThrow(const ApiError(code: 'not_found', message: 'gone', status: 404));
        return ModelPickerCubit(models, conversations);
      },
      act: (c) async {
        await c.load();
        await c.attachConversation('c1');
        await c.select('gemma4:e4b');
      },
      verify: (c) {
        expect(c.state.selected, isNull);
        expect(c.state.error?.code, 'not_found');
      },
    );

    blocTest<ModelPickerCubit, ModelPickerState>(
      'embedding-only (selectable=false) models cannot be chosen',
      build: () => ModelPickerCubit(models, conversations),
      act: (c) async {
        await c.load();
        await c.select('nomic-embed-text:latest');
      },
      verify: (c) => expect(c.state.selected, isNull),
    );
  });
}
