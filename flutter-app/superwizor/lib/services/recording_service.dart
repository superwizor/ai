import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum RecordingState { idle, recording, paused, stopped, error }

class AudioChunk {
  final String filePath;
  final int chunkIndex;
  final int durationMs;

  AudioChunk({required this.filePath, required this.chunkIndex, required this.durationMs});
}

class RecordingService {
  final _recorder = AudioRecorder();
  final _stateController = StreamController<RecordingState>.broadcast();
  final _chunkController = StreamController<AudioChunk>.broadcast();

  Timer? _chunkTimer;
  String? _sessionDir;
  int _chunkIndex = 0;
  DateTime? _chunkStartTime;
  RecordingState _state = RecordingState.idle;

  static const _chunkDurationSeconds = 30;

  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<AudioChunk> get chunkStream => _chunkController.stream;
  RecordingState get state => _state;

  Future<bool> hasPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startRecording(String sessionId) async {
    if (!await hasPermission()) {
      _setState(RecordingState.error);
      throw Exception('Microphone permission denied');
    }

    final docs = await getApplicationSupportDirectory();
    _sessionDir = p.join(docs.path, 'recordings', sessionId);
    await Directory(_sessionDir!).create(recursive: true);

    _chunkIndex = 0;
    await WakelockPlus.enable();

    await _startNewChunk();

    // Schedule chunk rotation
    _chunkTimer = Timer.periodic(
      const Duration(seconds: _chunkDurationSeconds),
      (_) => _rotateChunk(),
    );

    _setState(RecordingState.recording);
  }

  Future<void> _startNewChunk() async {
    final filePath = p.join(_sessionDir!, 'chunk_${_chunkIndex.toString().padLeft(4, '0')}.m4a');
    _chunkStartTime = DateTime.now();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );
  }

  Future<void> _rotateChunk() async {
    if (_state != RecordingState.recording) return;

    final oldPath = await _recorder.stop();
    final duration = DateTime.now().difference(_chunkStartTime!).inMilliseconds;
    
    if (oldPath != null) {
      _chunkController.add(AudioChunk(
        filePath: oldPath,
        chunkIndex: _chunkIndex,
        durationMs: duration,
      ));
    }

    _chunkIndex++;
    await _startNewChunk();
  }

  Future<void> pauseRecording() async {
    if (_state == RecordingState.recording) {
      await _recorder.pause();
      _chunkTimer?.cancel();
      _setState(RecordingState.paused);
    }
  }

  Future<void> resumeRecording() async {
    if (_state == RecordingState.paused) {
      await _recorder.resume();
      _chunkTimer = Timer.periodic(
        const Duration(seconds: _chunkDurationSeconds),
        (_) => _rotateChunk(),
      );
      _setState(RecordingState.recording);
    }
  }

  Future<List<String>> stopRecording() async {
    _chunkTimer?.cancel();
    
    final finalPath = await _recorder.stop();
    if (finalPath != null && _chunkStartTime != null) {
      final duration = DateTime.now().difference(_chunkStartTime!).inMilliseconds;
      _chunkController.add(AudioChunk(
        filePath: finalPath,
        chunkIndex: _chunkIndex,
        durationMs: duration,
      ));
    }

    await WakelockPlus.disable();
    _setState(RecordingState.stopped);

    if (_sessionDir == null) return [];

    final dir = Directory(_sessionDir!);
    if (!await dir.exists()) return [];

    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.m4a'))
        .map((e) => e.path)
        .toList();

    files.sort();
    return files;
  }

  Future<void> cleanSession(String sessionId) async {
    final docs = await getApplicationSupportDirectory();
    final targetDir = p.join(docs.path, 'recordings', sessionId);
    final dir = Directory(targetDir);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  void _setState(RecordingState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    _recorder.dispose();
    _stateController.close();
    _chunkController.close();
    _chunkTimer?.cancel();
  }
}
