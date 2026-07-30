// BackgroundUploader.swift — iOS-native background-URLSession uploader.
//
// Bridges to Flutter via a MethodChannel
// ("ai.superwizor/background_upload"). The Dart side
// (lib/uploads/background_upload_channel.dart) calls `start`, `cancel`
// and `pendingIds`. It does NOT learn the outcome over the channel — see
// the journal note below.
//
// Why this exists: the upload queue is pure Dart and iOS suspends the
// process seconds after backgrounding, so a PUT in flight simply dies and
// only resumes when the user reopens the app (production incident: one
// recording sat unsent for 19 h 52 min). Handing the bytes to
// `nsurlsessiond` moves the transfer out of our process entirely — it
// survives suspension AND system-initiated termination, and the OS
// relaunches us in the background just to deliver the completion.
//
// The fix is deliberately asymmetric (docs/58): only iOS hands the bytes
// to the system. Android keeps the Dart runner and merely borrows a
// `dataSync` foreground service, because the isolate does keep running
// there.
//
// How results come back: NOT over the channel. iOS relaunches us in the
// background even while the device is LOCKED, and at that moment the Hive
// box key (Keychain, after-first-unlock) can be unreadable and the
// Flutter engine may not be serving channel calls yet. So every
// completion is written to `<Documents>/upload_journal/<localId>.json` —
// a plain file, no PHI, just an identifier plus an HTTP status. Dart
// reads and deletes those files; we only ever write them.
//
// The upload URI is a GCS resumable-session URL that carries its own
// credentials in the query string. It therefore never gets an
// Authorization header and is never logged, not even on failure.

import Flutter
import Foundation

@objc public final class BackgroundUploader: NSObject, URLSessionTaskDelegate {
    // MARK: Channel + session identity
    static let methodChannelName = "ai.superwizor/background_upload"

    /// Identifier of the background session. Stable across launches —
    /// that is how `nsurlsessiond` hands us back the tasks it carried
    /// while the process was dead.
    static let sessionIdentifier = "ai.superwizor.upload"

    static let journalDirName = "upload_journal"

    /// One instance for the whole process. AudioConverter can afford a
    /// per-registration instance; we cannot — the URLSession below must
    /// be a singleton (see `session`) and AppDelegate needs to reach the
    /// same object when the OS wakes us for session events.
    @objc public static let shared = BackgroundUploader()

    /// Completion handler stashed by
    /// `AppDelegate.application(_:handleEventsForBackgroundURLSession:…)`.
    /// Touched only on the main thread.
    private var backgroundCompletionHandler: (() -> Void)?

    // MARK: The one and only session
    //
    // Constructing a second URLSession with an identifier that is
    // already in use traps ("A background URLSession with identifier …
    // already exists!"), so creation is memoized behind a serial queue.
    // `lazy var` would not be enough: the platform thread and the
    // background-launch path can both be first to ask.
    private static let sessionQueue = DispatchQueue(
        label: "ai.superwizor.upload.session")
    private var memoizedSession: URLSession?

    private var session: URLSession {
        BackgroundUploader.sessionQueue.sync {
            if let existing = memoizedSession { return existing }
            let config = URLSessionConfiguration.background(
                withIdentifier: BackgroundUploader.sessionIdentifier)
            // Discretionary transfers get parked until Wi-Fi + charger,
            // which would reproduce exactly the stall we are fixing.
            // (The OS still treats tasks *created* while backgrounded as
            // discretionary regardless — hence Dart only calls `start`
            // from the foreground.)
            config.isDiscretionary = false
            // Let the OS relaunch us into the background to deliver
            // completions. Without this the journal would only be
            // written the next time the user opens the app.
            config.sessionSendsLaunchEvents = true
            let created = URLSession(
                configuration: config, delegate: self, delegateQueue: nil)
            memoizedSession = created
            return created
        }
    }

    /// Registers the method channel on the Flutter binary messenger.
    /// Called from AppDelegate after the engine is up.
    @objc public static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: methodChannelName, binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            shared.handle(call: call, result: result)
        }
        // Materialize the session at registration time so this delegate
        // is attached to any task `nsurlsessiond` is still carrying from
        // a previous launch. Otherwise a completion that landed before
        // Dart's first channel call would have nowhere to go.
        _ = shared.session
    }

    // MARK: Method dispatcher

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            guard let args = call.arguments as? [String: Any],
                  let localId = args["localId"] as? String,
                  let uploadUri = args["uploadUri"] as? String,
                  let filePath = args["filePath"] as? String,
                  let contentType = args["contentType"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGS",
                    message: "localId, uploadUri, filePath and contentType required",
                    details: nil))
                return
            }
            // `totalBytes` also arrives in the map and is deliberately
            // unused: it is Dart's own bookkeeping figure, taken before
            // conversion/trimming could touch the file. The stat below is
            // the truth, and a Content-Range that disagrees with the body
            // makes GCS reject the whole PUT.
            start(localId: localId,
                  uploadUri: uploadUri,
                  filePath: filePath,
                  contentType: contentType,
                  result: result)

        case "cancel":
            guard let args = call.arguments as? [String: Any],
                  let localId = args["localId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "localId required",
                                    details: nil))
                return
            }
            cancel(localId: localId, result: result)

        case "pendingIds":
            pendingIds(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: start

    private func start(
        localId: String,
        uploadUri: String,
        filePath: String,
        contentType: String,
        result: @escaping FlutterResult
    ) {
        // The file on disk is the single source of truth for the length.
        // A missing or empty file must not become a task: a background
        // session would happily PUT zero bytes and GCS would finalize a
        // truncated object.
        let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
        let totalBytes = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        guard totalBytes > 0 else {
            // Lower-case code is what the Dart contract matches on; the
            // rest of this file follows AudioConverter's SCREAMING_SNAKE.
            result(FlutterError(
                code: "file_missing",
                message: "upload source is missing or empty",
                details: filePath))
            return
        }

        guard let url = URL(string: uploadUri) else {
            result(FlutterError(code: "INVALID_ARGS",
                                message: "uploadUri is not a valid URL",
                                details: nil))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("bytes 0-\(totalBytes - 1)/\(totalBytes)",
                         forHTTPHeaderField: "Content-Range")

        // `fromFile:` is mandatory here — a background session ignores
        // `httpBody` and outright rejects a streamed body.
        let task = session.uploadTask(
            with: request, fromFile: URL(fileURLWithPath: filePath))
        // The only thing that survives process death with the task, and
        // therefore the only way the delegate can name the queue row it
        // is reporting on.
        task.taskDescription = localId
        task.resume()
        result(true)
    }

    // MARK: cancel

    private func cancel(localId: String, result: @escaping FlutterResult) {
        session.getAllTasks { tasks in
            var cancelled = false
            for task in tasks where task.taskDescription == localId {
                // NOTE: this still lands in didCompleteWithError with
                // NSURLErrorCancelled, so a `failed` journal row is
                // written for a cancel Dart asked for. Dart drains and
                // deletes it; it must not treat it as news.
                task.cancel()
                cancelled = true
            }
            DispatchQueue.main.async { result(cancelled) }
        }
    }

    // MARK: pendingIds

    private func pendingIds(result: @escaping FlutterResult) {
        session.getAllTasks { tasks in
            let ids = tasks.compactMap { task -> String? in
                // `.canceling` and `.completed` are on their way to the
                // delegate and will report through the journal — from
                // Dart's point of view nothing is in flight for them.
                switch task.state {
                case .running, .suspended:
                    return task.taskDescription
                default:
                    return nil
                }
            }
            DispatchQueue.main.async { result(ids) }
        }
    }

    // MARK: Background launch events
    //
    // Called from AppDelegate when the OS wakes the app purely to finish
    // session bookkeeping. Returns false for identifiers that are not
    // ours so the caller can forward them on.
    @objc public func handleBackgroundSessionEvents(
        identifier: String,
        completionHandler: @escaping () -> Void
    ) -> Bool {
        guard identifier == BackgroundUploader.sessionIdentifier else {
            return false
        }
        backgroundCompletionHandler = completionHandler
        // Re-attach this delegate to the tasks nsurlsessiond carried
        // while we were dead. Without this touch the completions — and
        // the journal writes — never arrive.
        _ = session
        return true
    }

    // MARK: URLSessionTaskDelegate

    public func urlSession(_ session: URLSession,
                           task: URLSessionTask,
                           didCompleteWithError error: Error?) {
        guard let localId = task.taskDescription else {
            // Nothing to map the transfer back to. Should be impossible
            // — `start` always sets it — so shout rather than guess.
            print("[BackgroundUploader] completion without taskDescription")
            return
        }

        let http = task.response as? HTTPURLResponse
        var state = "failed"
        var httpStatus: Int? = http?.statusCode
        var errorMessage: String?

        if let error = error {
            let ns = error as NSError
            // domain + code + localizedDescription only. `userInfo`
            // carries NSURLErrorFailingURLStringErrorKey, i.e. the
            // credentialed upload URI — it must not reach the journal.
            errorMessage = "\(ns.domain) \(ns.code): \(ns.localizedDescription)"
            // A transport error is the real cause even when headers made
            // it back; leaving httpStatus nil keeps Dart's
            // `failureSummary` from reporting a misleading status.
            httpStatus = nil
        } else if let code = http?.statusCode {
            switch code {
            case 200, 201:
                state = "success"
            case 308:
                // GCS answers a resumable PUT with 308 + `Range:
                // bytes=0-<last>` when it wants more bytes. The same 308
                // means "object complete" once <last> is the final byte.
                let range = http?.value(forHTTPHeaderField: "Range")
                if rangeCoversWholeObject(range, total: declaredTotal(for: task)) {
                    state = "success"
                } else {
                    errorMessage = "resume incomplete (Range: \(range ?? "none"))"
                }
            default:
                // 4xx/5xx — httpStatus alone tells Dart the story.
                break
            }
        } else {
            errorMessage = "no HTTP response"
        }

        // FIRST, before anything else and before the stored background
        // completion handler runs: the journal is the durable hand-off,
        // the channel is not. The app may have been relaunched purely for
        // this callback and can be suspended again the moment the handler
        // returns.
        writeJournal(localId: localId,
                     state: state,
                     httpStatus: httpStatus,
                     bytesSent: task.countOfBytesSent,
                     error: errorMessage)
    }

    public func urlSessionDidFinishEvents(
        forBackgroundURLSession session: URLSession
    ) {
        // UIKit requires this on the main queue, and exactly once.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let handler = self.backgroundCompletionHandler
            self.backgroundCompletionHandler = nil
            handler?()
        }
    }

    // MARK: Journal

    /// Object length as we declared it in the outgoing Content-Range.
    /// Read back off the request because that is persisted with the task
    /// and therefore survives the process death a background session may
    /// report through — the file on disk may be long gone by then, and
    /// `countOfBytesExpectedToSend` is only a fallback.
    private func declaredTotal(for task: URLSessionTask) -> Int64 {
        if let header = task.originalRequest?
            .value(forHTTPHeaderField: "Content-Range"),
           let slash = header.lastIndex(of: "/"),
           let total = Int64(header[header.index(after: slash)...]
            .trimmingCharacters(in: .whitespaces)) {
            return total
        }
        return task.countOfBytesExpectedToSend
    }

    /// `bytes=0-<last>` covers the object only when <last> is total-1.
    /// Anything unparseable counts as incomplete — a false "success"
    /// would make Dart drop a recording that never fully landed.
    private func rangeCoversWholeObject(_ header: String?, total: Int64) -> Bool {
        guard total > 0, let header = header,
              let dash = header.lastIndex(of: "-") else { return false }
        let tail = header[header.index(after: dash)...]
            .trimmingCharacters(in: .whitespaces)
        guard let last = Int64(tail) else { return false }
        return last == total - 1
    }

    private static let journalTimestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    /// Writes `<Documents>/upload_journal/<localId>.json`.
    ///
    /// Runs on the session's delegate queue, which is serial, so journal
    /// writes never interleave. The file lands under the default data
    /// protection class (after-first-unlock), which is what lets us write
    /// it while the device is locked — the very case the Hive box cannot
    /// serve.
    private func writeJournal(
        localId: String,
        state: String,
        httpStatus: Int?,
        bytesSent: Int64,
        error: String?
    ) {
        let fm = FileManager.default
        guard let documents = fm.urls(
            for: .documentDirectory, in: .userDomainMask).first else {
            print("[BackgroundUploader] no Documents dir — journal lost")
            return
        }
        let dir = documents.appendingPathComponent(
            BackgroundUploader.journalDirName, isDirectory: true)

        let payload: [String: Any] = [
            "localId": localId,
            "state": state,
            "httpStatus": httpStatus ?? NSNull(),
            "bytesSent": bytesSent,
            "error": error ?? NSNull(),
            "updatedAt": BackgroundUploader.journalTimestampFormatter
                .string(from: Date()),
        ]

        // A localId is a UUID from Dart, so it cannot escape the
        // directory — but a path-traversing one would be a nasty way to
        // find that out.
        let safeId = localId.replacingOccurrences(of: "/", with: "_")
        let dest = dir.appendingPathComponent("\(safeId).json")
        let tmp = dir.appendingPathComponent("\(safeId).json.tmp")

        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: payload)
            try data.write(to: tmp)
            // Publish by rename so a half-written journal is never
            // observable. `moveItem` refuses an existing destination, so
            // the overwrite case (a retried localId) goes through
            // `replaceItemAt`, which is the atomic swap.
            if fm.fileExists(atPath: dest.path) {
                _ = try fm.replaceItemAt(dest, withItemAt: tmp)
            } else {
                try fm.moveItem(at: tmp, to: dest)
            }
        } catch {
            // Nothing left to try. Dart's lease on the row expires on
            // TTL and the recording goes back into the queue, so a lost
            // journal costs a re-upload, not a recording.
            print("[BackgroundUploader] journal write failed for \(localId): \(error)")
            try? fm.removeItem(at: tmp)
        }
    }
}
