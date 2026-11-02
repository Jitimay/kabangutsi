import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/call/bloc/call_bloc.dart';
import 'package:kabangutsi/features/call/services/audio_player_service.dart';
import 'package:kabangutsi/features/call/services/audio_recorder_service.dart';
import 'package:mocktail/mocktail.dart';

import 'call_fixtures.dart';

class MockRepo extends Mock implements ConversationRepository {}

class MockRecorder extends Mock implements AudioRecorderService {}

class MockPlayer extends Mock implements AudioPlayerService {}

void main() {
  late MockRepo repo;
  late MockRecorder recorder;
  late MockPlayer player;

  setUpAll(() => registerFallbackValue(const MessageInput()));

  setUp(() {
    repo = MockRepo();
    recorder = MockRecorder();
    player = MockPlayer();
    when(() => recorder.hasPermission()).thenAnswer((_) async => true);
    when(() => recorder.start()).thenAnswer((_) async {});
    when(() => recorder.stop()).thenAnswer((_) async => wavUpload);
    when(() => recorder.cancel()).thenAnswer((_) async {});
    when(() => recorder.dispose()).thenAnswer((_) async {});
    when(() => player.play(any())).thenAnswer((_) async {});
    when(() => player.stop()).thenAnswer((_) async {});
    when(() => player.dispose()).thenAnswer((_) async {});
    when(() => repo.end(any())).thenAnswer((_) async => call());
  });

  CallBloc build() => CallBloc(repository: repo, recorder: recorder, player: player, readDelay: (_) => Duration.zero);

  const ready = CallState(phase: CallPhase.ready, conversationId: convId);

  group('start', () {
    blocTest<CallBloc, CallState>(
      'creates a phone conversation and plays the greeting',
      setUp: () => when(() => repo.create(channel: 'phone', phone: any(named: 'phone'), lang: 'rn'))
          .thenAnswer((_) async => conversation(greeting: reply('Murakaza neza', attachments: const [
                Attachment(type: 'audio', url: '/v1/files/g', mime: 'audio/wav'),
              ]))),
      build: build,
      act: (b) => b.add(const CallStarted('rn')),
      expect: () => const [
        CallState(phase: CallPhase.connecting),
        ready,
        CallState(phase: CallPhase.speaking, conversationId: convId, lines: [CallLine('ai', 'Murakaza neza')]),
        CallState(phase: CallPhase.ready, conversationId: convId, lines: [CallLine('ai', 'Murakaza neza')]),
      ],
      verify: (_) => verify(() => player.play('/v1/files/g')).called(1),
    );

    blocTest<CallBloc, CallState>(
      'goes to error when the backend is unreachable',
      setUp: () => when(() => repo.create(channel: any(named: 'channel'), phone: any(named: 'phone'), lang: any(named: 'lang')))
          .thenThrow(ApiError.network),
      build: build,
      act: (b) => b.add(const CallStarted('fr')),
      expect: () => const [
        CallState(phase: CallPhase.connecting),
        CallState(phase: CallPhase.error, error: CallErrors.startFailed),
      ],
    );
  });

  group('turn', () {
    blocTest<CallBloc, CallState>(
      'record → send audio → thinking → speaking sentence by sentence → ready',
      setUp: () => when(() => repo.sendMessage(convId, any())).thenAnswer((_) => Stream.fromIterable([
            StreamTurn(turn('Agence de Ngozi ?')),
            const StreamToken('Elle'),
            const StreamSentence(0, 'Elle ouvre à 8 h.', '/v1/files/s0'),
            const StreamSentence(1, 'Fermée le dimanche.', null),
            StreamDone(reply('Elle ouvre à 8 h. Fermée le dimanche.')),
          ])),
      build: build,
      seed: () => ready,
      act: (b) async {
        b.add(const CallTalkToggled());
        await Future<void>.delayed(Duration.zero);
        b.add(const CallTalkToggled());
      },
      wait: const Duration(milliseconds: 20),
      // Speaking starts as soon as the first sentence arrives, while the rest still streams.
      expect: () => containsAllInOrder(const [
        CallState(phase: CallPhase.listening, conversationId: convId),
        CallState(phase: CallPhase.thinking, conversationId: convId),
        CallState(phase: CallPhase.thinking, conversationId: convId, lines: [CallLine('customer', 'Agence de Ngozi ?')]),
        CallState(phase: CallPhase.thinking, conversationId: convId, lines: [CallLine('customer', 'Agence de Ngozi ?'), CallLine('ai', 'Elle ouvre à 8 h.')]),
        CallState(phase: CallPhase.speaking, conversationId: convId, lines: [CallLine('customer', 'Agence de Ngozi ?'), CallLine('ai', 'Elle ouvre à 8 h. Fermée le dimanche.')]),
        CallState(phase: CallPhase.ready, conversationId: convId, lines: [CallLine('customer', 'Agence de Ngozi ?'), CallLine('ai', 'Elle ouvre à 8 h. Fermée le dimanche.')]),
      ]),
      verify: (_) {
        final sent = verify(() => repo.sendMessage(convId, captureAny())).captured.single as MessageInput;
        expect(sent.voice, isTrue);
        expect(sent.audio, wavUpload);
        verify(() => player.play('/v1/files/s0')).called(1);
      },
    );

    blocTest<CallBloc, CallState>(
      'shows the model switch notice',
      setUp: () => when(() => repo.sendMessage(convId, any())).thenAnswer((_) => Stream.fromIterable([
            StreamModelSwitched(ModelSwitch(
              id: 'f2a3b4c5-d6e7-4f8a-9b9c-0d1e2f3a4b5c', callId: convId, requestedModel: 'gemma:2b', usedModel: 'gemma4:e4b',
              capabilityNeeded: 'audio', reason: 'capability_missing', fallbackPath: null,
              notice: 'Modèle changé pour gemma4:e4b', lang: 'fr', ts: t0)),
            StreamDone(reply('')),
          ])),
      build: build,
      seed: () => const CallState(phase: CallPhase.listening, conversationId: convId),
      act: (b) => b.add(const CallTalkToggled()),
      skip: 2,
      expect: () => const [
        CallState(phase: CallPhase.ready, conversationId: convId, lines: [CallLine('notice', 'Modèle changé pour gemma4:e4b')]),
      ],
    );

    blocTest<CallBloc, CallState>(
      'a failed turn returns to ready with an error',
      setUp: () => when(() => repo.sendMessage(convId, any()))
          .thenAnswer((_) => Stream.error(const ApiError(code: 'service_unavailable', message: 'down', status: 503))),
      build: build,
      seed: () => const CallState(phase: CallPhase.listening, conversationId: convId),
      act: (b) => b.add(const CallTalkToggled()),
      expect: () => const [
        CallState(phase: CallPhase.thinking, conversationId: convId),
        CallState(phase: CallPhase.ready, conversationId: convId, error: CallErrors.turnFailed),
      ],
    );

    blocTest<CallBloc, CallState>(
      'microphone refused → error, no recording',
      setUp: () => when(() => recorder.hasPermission()).thenAnswer((_) async => false),
      build: build,
      seed: () => ready,
      act: (b) => b.add(const CallTalkToggled()),
      expect: () => const [CallState(phase: CallPhase.ready, conversationId: convId, error: CallErrors.micDenied)],
      verify: (_) => verifyNever(() => recorder.start()),
    );

    blocTest<CallBloc, CallState>(
      'cancel discards the recording',
      build: build,
      seed: () => const CallState(phase: CallPhase.listening, conversationId: convId),
      act: (b) => b.add(const CallRecordingCancelled()),
      expect: () => const [ready],
      verify: (_) {
        verify(() => recorder.cancel()).called(1);
        verifyNever(() => repo.sendMessage(any(), any()));
      },
    );

    blocTest<CallBloc, CallState>(
      'reply with handoff=true moves to handedOff',
      setUp: () {
        when(() => repo.sendMessage(convId, any())).thenAnswer((_) => Stream.value(StreamDone(reply('Un conseiller arrive.', handoff: true))));
        when(() => repo.events(convId)).thenAnswer((_) => const Stream.empty());
      },
      build: build,
      seed: () => const CallState(phase: CallPhase.listening, conversationId: convId),
      act: (b) => b.add(const CallTalkToggled()),
      wait: const Duration(milliseconds: 20),
      expect: () => const [
        CallState(phase: CallPhase.thinking, conversationId: convId),
        CallState(phase: CallPhase.speaking, conversationId: convId, lines: [CallLine('ai', 'Un conseiller arrive.')]),
        CallState(phase: CallPhase.handedOff, conversationId: convId, withAgent: true, lines: [CallLine('ai', 'Un conseiller arrive.')]),
      ],
    );
  });

  group('handoff', () {
    blocTest<CallBloc, CallState>(
      'talk to an agent → handedOff → agent joins and speaks → call ended by agent',
      setUp: () {
        final live = StreamController<WsEvent>();
        when(() => repo.requestHandoff(convId)).thenAnswer((_) async => reply('Veuillez patienter.', speaker: 'system'));
        when(() => repo.events(convId)).thenAnswer((_) => live.stream);
        scheduleMicrotask(() async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          live
            ..add(CallClaimedEvent('e1', t0, call(status: 'with_agent'), 'agent-01', 'Agent Aline (demo)'))
            ..add(CallTurnEvent('e2', t0, turn('Bonjour, ici Aline.', speaker: 'agent', attachments: const [
                  Attachment(type: 'audio', url: '/v1/files/a1', mime: 'audio/wav'),
                ])));
          await Future<void>.delayed(const Duration(milliseconds: 10));
          live.add(CallEndedEvent('e3', t0, call()));
        });
      },
      build: build,
      seed: () => ready,
      act: (b) => b.add(const CallHandoffRequested()),
      wait: const Duration(milliseconds: 60),
      expect: () => const [
        CallState(phase: CallPhase.ready, conversationId: convId, lines: [CallLine('system', 'Veuillez patienter.')]),
        CallState(phase: CallPhase.handedOff, conversationId: convId, withAgent: true, lines: [CallLine('system', 'Veuillez patienter.')]),
        CallState(phase: CallPhase.handedOff, conversationId: convId, withAgent: true, agentName: 'Agent Aline (demo)', lines: [CallLine('system', 'Veuillez patienter.')]),
        CallState(phase: CallPhase.speaking, conversationId: convId, withAgent: true, agentName: 'Agent Aline (demo)', lines: [CallLine('system', 'Veuillez patienter.'), CallLine('agent', 'Bonjour, ici Aline.')]),
        CallState(phase: CallPhase.handedOff, conversationId: convId, withAgent: true, agentName: 'Agent Aline (demo)', lines: [CallLine('system', 'Veuillez patienter.'), CallLine('agent', 'Bonjour, ici Aline.')]),
        CallState(phase: CallPhase.ended, conversationId: convId, withAgent: true, agentName: 'Agent Aline (demo)', lines: [CallLine('system', 'Veuillez patienter.'), CallLine('agent', 'Bonjour, ici Aline.')]),
      ],
      verify: (_) {
        verify(() => player.play('/v1/files/a1')).called(1);
        verifyNever(() => repo.end(any())); // ended by the agent, not by the customer
      },
    );

    blocTest<CallBloc, CallState>(
      'a 409 while with an agent is not an error (message forwarded)',
      setUp: () => when(() => repo.sendMessage(convId, any()))
          .thenAnswer((_) => Stream.error(const ApiError(code: 'conflict', message: 'with agent', status: 409))),
      build: build,
      seed: () => const CallState(phase: CallPhase.listening, conversationId: convId, withAgent: true),
      act: (b) => b.add(const CallTalkToggled()),
      expect: () => const [
        CallState(phase: CallPhase.thinking, conversationId: convId, withAgent: true),
        CallState(phase: CallPhase.handedOff, conversationId: convId, withAgent: true),
      ],
    );
  });

  blocTest<CallBloc, CallState>(
    'hang up while recording → ended and conversation closed on the backend',
    build: build,
    seed: () => const CallState(phase: CallPhase.listening, conversationId: convId),
    act: (b) => b.add(const CallHungUp()),
    expect: () => const [CallState(phase: CallPhase.ended, conversationId: convId)],
    verify: (_) {
      verify(() => recorder.cancel()).called(1);
      verify(() => repo.end(convId)).called(1);
    },
  );

  test('pcmToWav writes a valid 44-byte RIFF header', () {
    final wav = pcmToWav(Uint8List(32000), sampleRate: 16000);
    expect(wav.length, 44 + 32000);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    final h = ByteData.sublistView(wav);
    expect(h.getUint32(24, Endian.little), 16000);
    expect(h.getUint16(34, Endian.little), 16);
    expect(h.getUint32(40, Endian.little), 32000);
  });

  test('read delay is ~40 ms per char, max 4 s', () {
    expect(defaultReadDelay('abc'), const Duration(milliseconds: 120));
    expect(defaultReadDelay('x' * 500), const Duration(seconds: 4));
  });
}
