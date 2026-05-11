// AudioConverterService — client-side WAV normalization.
//
// Chirp 3 on the eu-speech endpoint rejects 32-bit float WAV.
// This converter reads a WAV file, detects if it's 32-bit float,
// and rewrites it as 16-bit PCM WAV (which Chirp 3 supports).
//
// Pure Dart — no external dependencies, no ffmpeg.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AudioConverterService {
  /// Normalizes a WAV file to 16-bit PCM if needed.
  ///
  /// If the file is already 16-bit PCM, returns the original file unchanged.
  /// If it's 32-bit float (or 24/32-bit int), converts to 16-bit PCM.
  /// For non-WAV files, returns null (caller should upload as-is and let
  /// the backend handle it).
  ///
  /// [onProgress] — callback with progress 0.0–1.0.
  ///
  /// Returns the path to the normalized file (may be same as input if
  /// no conversion needed), or null if the format is not WAV.
  Future<File?> normalizeWav(
    String inputPath, {
    void Function(double progress)? onProgress,
  }) async {
    final inputFile = File(inputPath);
    debugPrint('[wav-norm] reading $inputPath');
    final bytes = await inputFile.readAsBytes();
    debugPrint('[wav-norm] read ${bytes.length} bytes (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB)');
    onProgress?.call(0.1);

    // Check RIFF/WAVE header
    if (bytes.length < 44) return null;
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final wave = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || wave != 'WAVE') return null;

    // Parse fmt chunk
    final fmtOffset = _findChunk(bytes, 'fmt ');
    if (fmtOffset == null) return null;

    final bd = ByteData.sublistView(bytes);
    final fmtSize = bd.getUint32(fmtOffset + 4, Endian.little);
    final audioFormat = bd.getUint16(fmtOffset + 8, Endian.little);
    final numChannels = bd.getUint16(fmtOffset + 10, Endian.little);
    final sampleRate = bd.getUint32(fmtOffset + 12, Endian.little);
    final bitsPerSample = bd.getUint16(fmtOffset + 22, Endian.little);

    debugPrint('[wav-norm] format=$audioFormat channels=$numChannels '
        'rate=$sampleRate bits=$bitsPerSample fmtSize=$fmtSize');

    // audioFormat: 1 = PCM, 3 = IEEE Float, 0xFFFE = extensible
    final isFloat = audioFormat == 3;
    final isPCM = audioFormat == 1;
    final isExtensible = audioFormat == 0xFFFE;

    // If already 16-bit PCM, no conversion needed
    if (isPCM && bitsPerSample == 16) {
      debugPrint('[wav-norm] already 16-bit PCM, no conversion needed');
      onProgress?.call(1.0);
      return inputFile;
    }

    // For extensible format, check sub-format
    int effectiveFormat = audioFormat;
    if (isExtensible && fmtSize >= 40) {
      // SubFormat GUID starts at offset 24 in fmt chunk data
      // PCM: 01 00 00 00 00 00 10 00 80 00 00 AA 00 38 9B 71
      // Float: 03 00 00 00 00 00 10 00 80 00 00 AA 00 38 9B 71
      effectiveFormat = bd.getUint16(fmtOffset + 32, Endian.little);
    }

    final effectiveIsFloat = effectiveFormat == 3 || isFloat;
    final effectiveIsPCM = effectiveFormat == 1 || isPCM;

    if (!effectiveIsFloat && !effectiveIsPCM) {
      debugPrint('[wav-norm] unsupported WAV format: $audioFormat');
      return null;
    }

    // Find data chunk
    final dataOffset = _findChunk(bytes, 'data');
    if (dataOffset == null) return null;

    final dataSize = bd.getUint32(dataOffset + 4, Endian.little);
    final dataStart = dataOffset + 8;

    debugPrint('[wav-norm] data chunk: offset=$dataStart size=$dataSize');
    onProgress?.call(0.2);

    // Calculate number of samples
    final bytesPerSample = bitsPerSample ~/ 8;
    final totalSamples = dataSize ~/ (bytesPerSample * numChannels);

    // Convert samples to 16-bit PCM
    final outSamples = Int16List(totalSamples * numChannels);

    for (int i = 0; i < totalSamples * numChannels; i++) {
      final offset = dataStart + i * bytesPerSample;
      if (offset + bytesPerSample > bytes.length) break;

      double sample;

      if (effectiveIsFloat && bitsPerSample == 32) {
        // 32-bit IEEE float: range -1.0 to 1.0
        sample = bd.getFloat32(offset, Endian.little);
      } else if (effectiveIsFloat && bitsPerSample == 64) {
        // 64-bit IEEE float
        sample = bd.getFloat64(offset, Endian.little);
      } else if (effectiveIsPCM && bitsPerSample == 24) {
        // 24-bit signed PCM
        final b0 = bytes[offset];
        final b1 = bytes[offset + 1];
        final b2 = bytes[offset + 2];
        int value = b0 | (b1 << 8) | (b2 << 16);
        if (value >= 0x800000) value -= 0x1000000; // sign extend
        sample = value / 8388608.0; // 2^23
      } else if (effectiveIsPCM && bitsPerSample == 32) {
        // 32-bit signed PCM
        final value = bd.getInt32(offset, Endian.little);
        sample = value / 2147483648.0; // 2^31
      } else {
        debugPrint('[wav-norm] unsupported: format=$effectiveFormat bits=$bitsPerSample');
        return null;
      }

      // Clamp and convert to 16-bit
      sample = sample.clamp(-1.0, 1.0);
      outSamples[i] = (sample * 32767).round().clamp(-32768, 32767);

      // Report progress periodically
      if (i % (totalSamples * numChannels ~/ 10 + 1) == 0) {
        onProgress?.call(0.2 + (i / (totalSamples * numChannels)) * 0.6);
      }
    }

    onProgress?.call(0.85);

    // Write output WAV
    final tmpDir = await getTemporaryDirectory();
    final outputPath = p.join(
      tmpDir.path,
      'superwizor_norm_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    final outFile = File(outputPath);
    final outDataSize = outSamples.length * 2; // 16-bit = 2 bytes per sample
    final outFileSize = 36 + outDataSize;
    final outByteRate = sampleRate * numChannels * 2;
    final outBlockAlign = numChannels * 2;

    final out = BytesBuilder();

    // RIFF header
    out.add(Uint8List.fromList('RIFF'.codeUnits));
    out.add(_uint32LE(outFileSize));
    out.add(Uint8List.fromList('WAVE'.codeUnits));

    // fmt chunk
    out.add(Uint8List.fromList('fmt '.codeUnits));
    out.add(_uint32LE(16)); // chunk size
    out.add(_uint16LE(1)); // PCM format
    out.add(_uint16LE(numChannels));
    out.add(_uint32LE(sampleRate));
    out.add(_uint32LE(outByteRate));
    out.add(_uint16LE(outBlockAlign));
    out.add(_uint16LE(16)); // bits per sample

    // data chunk
    out.add(Uint8List.fromList('data'.codeUnits));
    out.add(_uint32LE(outDataSize));
    out.add(outSamples.buffer.asUint8List());

    await outFile.writeAsBytes(out.toBytes());

    final inputSize = bytes.length;
    final outputSize = await outFile.length();
    debugPrint(
      '[wav-norm] converted: ${(inputSize / 1024 / 1024).toStringAsFixed(1)} MB → '
      '${(outputSize / 1024 / 1024).toStringAsFixed(1)} MB '
      '(${bitsPerSample}bit ${effectiveIsFloat ? "float" : "int"} → 16bit PCM)',
    );

    onProgress?.call(1.0);
    return outFile;
  }

  /// Find the offset of a chunk by its 4-char ID in WAV file bytes.
  int? _findChunk(Uint8List bytes, String id) {
    final idBytes = id.codeUnits;
    int offset = 12; // skip RIFF header
    while (offset + 8 <= bytes.length) {
      if (bytes[offset] == idBytes[0] &&
          bytes[offset + 1] == idBytes[1] &&
          bytes[offset + 2] == idBytes[2] &&
          bytes[offset + 3] == idBytes[3]) {
        return offset;
      }
      final chunkSize = ByteData.sublistView(bytes)
          .getUint32(offset + 4, Endian.little);
      offset += 8 + chunkSize;
      if (offset.isOdd) offset++; // chunks are word-aligned
    }
    return null;
  }

  Uint8List _uint32LE(int value) {
    final bd = ByteData(4);
    bd.setUint32(0, value, Endian.little);
    return bd.buffer.asUint8List();
  }

  Uint8List _uint16LE(int value) {
    final bd = ByteData(2);
    bd.setUint16(0, value, Endian.little);
    return bd.buffer.asUint8List();
  }
}
