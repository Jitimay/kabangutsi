import 'dart:async';

import 'package:just_audio/just_audio.dart';

/// Plays TTS audio (sentence WAVs, agent messages).
abstract interface class AudioPlayerService {
  /// Completes when playback has finished (or was stopped / failed).
  Future<void> play(String url);
  Future<void> stop();
  Future<void> dispose();
}

/// just_audio implementation. [resolve] turns `/v1/files/{id}` into an absolute URL.
class JustAudioPlayer implements AudioPlayerService {
  JustAudioPlayer({required this.resolve, AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final String Function(String url) resolve;
  final AudioPlayer _player;

  @override
  Future<void> play(String url) async {
    try {
      await _player.setUrl(resolve(url));
      final done = _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.completed || s == ProcessingState.idle);
      unawaited(_player.play());
      await done;
      await _player.stop();
    } catch (_) {
      // A sentence that cannot be played must not block the call.
    }
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}
