import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../../../data/repositories/repositories.dart';

/// Records the customer's voice for one turn.
abstract interface class AudioRecorderService {
  /// False when the microphone permission is refused.
  Future<bool> hasPermission();
  Future<void> start();

  /// Stops and returns the recording as a WAV upload (null if nothing was recorded).
  Future<FileUpload?> stop();

  /// Stops and discards the recording.
  Future<void> cancel();
  Future<void> dispose();
}

const kCallSampleRate = 16000;

/// `record` implementation: streams PCM 16-bit mono 16 kHz and wraps it in a WAV
/// in memory (same code on web and Android, no file paths).
class RecordAudioRecorder implements AudioRecorderService {
  RecordAudioRecorder([AudioRecorder? recorder]) : _rec = recorder ?? AudioRecorder();

  final AudioRecorder _rec;
  final _pcm = BytesBuilder(copy: false);
  StreamSubscription<Uint8List>? _sub;

  @override
  Future<bool> hasPermission() => _rec.hasPermission();

  @override
  Future<void> start() async {
    _pcm.clear();
    final stream = await _rec.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: kCallSampleRate,
      numChannels: 1,
    ));
    _sub = stream.listen(_pcm.add);
  }

  @override
  Future<FileUpload?> stop() async {
    await _rec.stop();
    await _sub?.cancel();
    _sub = null;
    final pcm = _pcm.takeBytes();
    if (pcm.isEmpty) return null;
    return FileUpload(bytes: pcmToWav(pcm, sampleRate: kCallSampleRate), filename: 'turn.wav', mime: 'audio/wav');
  }

  @override
  Future<void> cancel() async {
    await _rec.cancel();
    await _sub?.cancel();
    _sub = null;
    _pcm.clear();
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    await _rec.dispose();
  }
}

/// Wraps raw little-endian PCM in a 44-byte RIFF/WAVE header.
Uint8List pcmToWav(Uint8List pcm, {required int sampleRate, int channels = 1, int bitsPerSample = 16}) {
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
  final blockAlign = channels * bitsPerSample ~/ 8;
  final h = ByteData(44);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      h.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  h.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  h.setUint32(16, 16, Endian.little); // PCM chunk size
  h.setUint16(20, 1, Endian.little); // format = PCM
  h.setUint16(22, channels, Endian.little);
  h.setUint32(24, sampleRate, Endian.little);
  h.setUint32(28, byteRate, Endian.little);
  h.setUint16(32, blockAlign, Endian.little);
  h.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  h.setUint32(40, pcm.length, Endian.little);
  return (BytesBuilder(copy: false)
        ..add(h.buffer.asUint8List())
        ..add(pcm))
      .takeBytes();
}
