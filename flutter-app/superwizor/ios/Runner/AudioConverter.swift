// AudioConverter.swift — iOS-native M4A → FLAC transcoder.
//
// Bridges to Flutter via a MethodChannel ("ai.superwizor/audio_converter").
// The Dart side (lib/services/audio_converter_service.dart) calls
// `convertM4aToFlac` and awaits the resulting FLAC path. Progress is
// streamed over a sibling EventChannel
// ("ai.superwizor/audio_converter/progress") as Double values in
// [0.0, 1.0].
//
// Why this exists: Chirp 3 (Cloud Speech v2, europe-central2) rejects
// AAC-in-MP4 — iPhone Voice Memos, WhatsApp voice notes, and iOS
// share-sheet exports all hit that rejection. Server-side fallback
// exists via ingestion-svc.ConvertAudio, but it adds 30-60s of upload
// latency and burns server CPU. iOS hardware AAC decode + FLAC encode
// runs at 5-10x realtime, so for the common case we transcode on the
// device.
//
// All APIs used here ship with AudioToolbox.framework / AVFoundation —
// no third-party deps, no extra binary cost. kAudioFormatFLAC has been
// available since iOS 11.0 (2017). Our deployment target is iOS 15.0.
//
// Output spec (matches what Chirp 3 expects from FLAC):
//   • Codec: FLAC
//   • Sample rate: 16 kHz
//   • Channels: 1 (mono)
//   • Bit depth: 16-bit
//
// Concurrency: each convertM4aToFlac call gets its own
// AVAudioFile/AVAudioConverter pair. The progress sink is shared (one
// FlutterEventSink at a time) so the UI assumes serial conversions —
// matching how the upload screen drives this.

import AVFoundation
import AudioToolbox
import Flutter

@objc public final class AudioConverter: NSObject, FlutterStreamHandler {
    // MARK: Channel names
    static let methodChannelName = "ai.superwizor/audio_converter"
    static let progressChannelName = "ai.superwizor/audio_converter/progress"

    private var progressSink: FlutterEventSink?

    /// Registers the method + event channels on the Flutter binary
    /// messenger. Called from AppDelegate after the engine is up.
    @objc public static func register(with messenger: FlutterBinaryMessenger) {
        let instance = AudioConverter()

        let method = FlutterMethodChannel(
            name: methodChannelName, binaryMessenger: messenger)
        method.setMethodCallHandler { call, result in
            instance.handle(call: call, result: result)
        }

        let progress = FlutterEventChannel(
            name: progressChannelName, binaryMessenger: messenger)
        progress.setStreamHandler(instance)
    }

    // MARK: FlutterStreamHandler

    public func onListen(withArguments arguments: Any?,
                         eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        progressSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        progressSink = nil
        return nil
    }

    // MARK: Method dispatcher

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "convertM4aToFlac":
            guard let args = call.arguments as? [String: Any],
                  let inputPath = args["inputPath"] as? String,
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "inputPath and outputPath required",
                                    details: nil))
                return
            }
            // Hop to a background queue so the main thread isn't
            // blocked while ffmpeg-equivalent work happens. The
            // AVAudioConverter loop below is synchronous within this
            // closure.
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                do {
                    try self.convertM4aToFlac(
                        inputPath: inputPath,
                        outputPath: outputPath)
                    DispatchQueue.main.async { result(outputPath) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "CONVERT_FAILED",
                            message: "\(error)",
                            details: String(describing: error)))
                    }
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: The actual transcoder
    //
    // Strategy:
    //   1. Open the M4A via AVAudioFile. AVAudioFile transparently
    //      decodes AAC-in-MP4 using AudioToolbox's hardware AAC
    //      decoder.
    //   2. Pre-allocate an AVAudioFile for writing FLAC at 16 kHz
    //      mono 16-bit.
    //   3. Read source frames into the source's processingFormat,
    //      then run them through AVAudioConverter to the FLAC writer's
    //      format. AVAudioConverter handles resampling + channel
    //      downmix in one shot.
    //   4. Emit progress = framesRead / totalFrames on each chunk.
    //
    // FLAC writer note: AVAudioFile when writing FLAC actually wants
    // the SAME processingFormat as the converter's output (Int16 PCM
    // at 16 kHz mono) — it transparently FLAC-encodes the samples
    // before they hit disk. See Apple docs on Extended Audio File
    // Services if this seems counterintuitive.
    private func convertM4aToFlac(
        inputPath: String,
        outputPath: String
    ) throws {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)

        // 1. Source.
        let srcFile = try AVAudioFile(forReading: inputURL)
        let srcFormat = srcFile.processingFormat
        let srcFrameCount = srcFile.length
        guard srcFrameCount > 0 else {
            throw NSError(domain: "AudioConverter", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Source file has zero frames"
            ])
        }

        // 2. Destination format: 16 kHz mono 16-bit PCM. AVAudioFile
        // recognizes kAudioFormatFLAC + the linear-PCM settings and
        // writes FLAC blocks on the fly.
        let dstSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatFLAC,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
        let dstFile = try AVAudioFile(
            forWriting: outputURL,
            settings: dstSettings,
            commonFormat: .pcmFormatInt16,
            interleaved: true)

        // 3. Converter. Apple's AVAudioConverter chooses an
        // appropriate resampler under the hood (default quality is
        // "medium"; sufficient for speech-only). Channel downmix from
        // stereo Voice Memos → mono is also automatic.
        guard let converter = AVAudioConverter(
            from: srcFormat, to: dstFile.processingFormat) else {
            throw NSError(domain: "AudioConverter", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "AVAudioConverter init failed"
            ])
        }

        // Read in ~1s chunks (sample rate × 1) at the source rate so
        // progress ticks roughly once per second of source audio. The
        // converter's output buffer is sized for the destination rate.
        let srcSampleRate = srcFormat.sampleRate
        let chunkFrames: AVAudioFrameCount = AVAudioFrameCount(srcSampleRate)
        let dstChunkFrames: AVAudioFrameCount = AVAudioFrameCount(
            Double(chunkFrames) * (16000.0 / srcSampleRate) + 1024.0)

        guard let srcBuf = AVAudioPCMBuffer(
            pcmFormat: srcFormat, frameCapacity: chunkFrames) else {
            throw NSError(domain: "AudioConverter", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to allocate source buffer"
            ])
        }

        var framesProcessed: AVAudioFramePosition = 0
        var lastReportedProgress: Double = -1.0

        // 4. Pump the file through the converter. AVAudioConverter
        // accepts a closure that yields source buffers on demand; we
        // read from disk inside it and return .haveData / .endOfStream.
        var done = false
        while !done {
            guard let dstBuf = AVAudioPCMBuffer(
                pcmFormat: dstFile.processingFormat,
                frameCapacity: dstChunkFrames) else {
                throw NSError(domain: "AudioConverter", code: 4, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to allocate dst buffer"
                ])
            }

            var convError: NSError?
            let status = converter.convert(
                to: dstBuf,
                error: &convError
            ) { _, inputStatus in
                do {
                    // Reset frame length so AVAudioFile.read writes
                    // into the start of the buffer each iteration.
                    srcBuf.frameLength = 0
                    try srcFile.read(into: srcBuf, frameCount: chunkFrames)
                } catch {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                if srcBuf.frameLength == 0 {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inputStatus.pointee = .haveData
                framesProcessed += AVAudioFramePosition(srcBuf.frameLength)
                return srcBuf
            }

            if let e = convError {
                throw e
            }

            switch status {
            case .haveData:
                if dstBuf.frameLength > 0 {
                    try dstFile.write(from: dstBuf)
                }
            case .inputRanDry:
                // Need more input; loop again. Shouldn't happen
                // because our closure returns .endOfStream when the
                // file is exhausted, but be defensive.
                continue
            case .endOfStream:
                if dstBuf.frameLength > 0 {
                    try dstFile.write(from: dstBuf)
                }
                done = true
            case .error:
                throw NSError(domain: "AudioConverter", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "Converter reported .error"
                ])
            @unknown default:
                throw NSError(domain: "AudioConverter", code: 6, userInfo: [
                    NSLocalizedDescriptionKey: "Unknown converter status"
                ])
            }

            // Emit progress on the main thread. Throttle to whole
            // percent steps — Flutter's setState() is expensive at
            // 100+ Hz, no point pushing finer than that.
            let progress = min(1.0, Double(framesProcessed) /
                               Double(srcFrameCount))
            let pct = (progress * 100.0).rounded() / 100.0
            if pct != lastReportedProgress {
                lastReportedProgress = pct
                DispatchQueue.main.async { [weak self] in
                    self?.progressSink?(pct)
                }
            }
        }

        // Final 1.0 tick after AVAudioFile is closed (deinit flushes
        // the FLAC tail block). Without this the UI can stick at
        // 0.98 because the rounding never reaches 1.00.
        DispatchQueue.main.async { [weak self] in
            self?.progressSink?(1.0)
        }
    }
}
