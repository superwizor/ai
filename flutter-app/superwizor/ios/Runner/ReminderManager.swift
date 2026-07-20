import Foundation
import Flutter
import AVFoundation
import AudioToolbox

class ReminderManager {
    static let shared = ReminderManager()
    
    private var timer: DispatchSourceTimer?
    private var audioPlayer: AVAudioPlayer?
    
    private var intervalMinutes: Int = 0
    private var intervalSeconds: Int = 0
    private var soundEnabled: Bool = false
    private var hapticsEnabled: Bool = false
    
    private var startTime: Date?
    private var accumulatedMillis: Int = 0
    private var expectedRemindersFired: Int = 0
    
    // Throttle diagnostic logs so we don't spam every 500ms
    private var lastDiagLogTime: Date = .distantPast
    
    // We use a serial background queue with default QoS to avoid iOS aggressive suspension of .background tasks
    private let queue = DispatchQueue(label: "ai.superwizor.reminderQueue", qos: .default)
    
    private init() {
        print("[ReminderManager] 🟢 INIT — singleton created")
        preloadAudio()
    }
    
    private func preloadAudio() {
        // Strategy 1: Flutter's official asset lookup API
        // FlutterDartProject.lookupKey(forAsset:) returns the correct
        // bundle-relative path for a Flutter asset (e.g. "flutter_assets/assets/sounds/SFX_session_end_2.mp3")
        let filesToTry = ["SFX_session_end_2.mp3", "SFX_session_end.mp3"]
        
        for filename in filesToTry {
            let assetKey = FlutterDartProject.lookupKey(forAsset: "assets/sounds/\(filename)")
            print("[ReminderManager] 🔍 lookupKey for assets/sounds/\(filename) → '\(assetKey)'")
            
            if let url = Bundle.main.url(forResource: assetKey, withExtension: nil) {
                print("[ReminderManager] ✅ Found \(filename) via lookupKey at: \(url.path)")
                if loadPlayer(from: url, label: filename) { return }
            }
            
            // Strategy 2: Direct subdirectory lookup (legacy approach)
            if let url = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3", subdirectory: "flutter_assets/assets/sounds") {
                print("[ReminderManager] ✅ Found \(filename) via subdirectory at: \(url.path)")
                if loadPlayer(from: url, label: filename) { return }
            }
            
            // Strategy 3: Construct path manually
            let manualPath = Bundle.main.bundlePath + "/Frameworks/App.framework/flutter_assets/assets/sounds/\(filename)"
            if FileManager.default.fileExists(atPath: manualPath) {
                let url = URL(fileURLWithPath: manualPath)
                print("[ReminderManager] ✅ Found \(filename) via manual path: \(manualPath)")
                if loadPlayer(from: url, label: filename) { return }
            }
        }
        
        // All strategies failed — dump diagnostics
        print("[ReminderManager] ❌❌ ALL STRATEGIES FAILED. Dumping bundle diagnostics...")
        let bundlePath = Bundle.main.bundlePath
        print("[ReminderManager] 📂 Bundle path: \(bundlePath)")
        
        // Check flutter_assets location
        let fm = FileManager.default
        let possiblePaths = [
            "\(bundlePath)/flutter_assets/assets/sounds",
            "\(bundlePath)/Frameworks/App.framework/flutter_assets/assets/sounds",
            "\(bundlePath)/flutter_assets/assets",
            "\(bundlePath)/flutter_assets",
        ]
        for path in possiblePaths {
            if fm.fileExists(atPath: path) {
                let files = (try? fm.contentsOfDirectory(atPath: path)) ?? []
                print("[ReminderManager] 📂 EXISTS: \(path) → \(files)")
            } else {
                print("[ReminderManager] 📂 NOT FOUND: \(path)")
            }
        }
    }
    
    private func loadPlayer(from url: URL, label: String) -> Bool {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            print("[ReminderManager] ✅ AVAudioPlayer loaded [\(label)], duration=\(audioPlayer?.duration ?? -1)s")
            return true
        } catch {
            print("[ReminderManager] ❌ AVAudioPlayer init FAILED for \(label): \(error)")
            return false
        }
    }
    
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "ai.superwizor/reminder_service", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            shared.handle(call, result: result)
        }
        print("[ReminderManager] 🟢 MethodChannel registered")
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            switch call.method {
            case "start":
                self.intervalMinutes = args?["intervalMinutes"] as? Int ?? 0
                self.intervalSeconds = args?["intervalSeconds"] as? Int ?? 0
                self.soundEnabled = args?["soundEnabled"] as? Bool ?? false
                self.hapticsEnabled = args?["hapticsEnabled"] as? Bool ?? false
                self.accumulatedMillis = args?["elapsedMillis"] as? Int ?? 0
                
                let intervalMillis = self.intervalSeconds > 0 ? self.intervalSeconds * 1000 : self.intervalMinutes * 60000
                self.expectedRemindersFired = self.accumulatedMillis / (intervalMillis > 0 ? intervalMillis : 1)
                
                print("[ReminderManager] ▶️ START — intervalMin=\(self.intervalMinutes), intervalSec=\(self.intervalSeconds), sound=\(self.soundEnabled), haptics=\(self.hapticsEnabled), accumulated=\(self.accumulatedMillis)ms, effectiveIntervalMs=\(intervalMillis), expectedFired=\(self.expectedRemindersFired), audioPlayer=\(self.audioPlayer != nil ? "LOADED" : "NIL")")
                
                self.startTimer()
                
            case "pause":
                self.accumulatedMillis = args?["elapsedMillis"] as? Int ?? 0
                print("[ReminderManager] ⏸ PAUSE — accumulated=\(self.accumulatedMillis)ms")
                self.stopTimer()
                
            case "resume":
                self.intervalMinutes = args?["intervalMinutes"] as? Int ?? 0
                self.intervalSeconds = args?["intervalSeconds"] as? Int ?? 0
                self.soundEnabled = args?["soundEnabled"] as? Bool ?? false
                self.hapticsEnabled = args?["hapticsEnabled"] as? Bool ?? false
                self.accumulatedMillis = args?["elapsedMillis"] as? Int ?? 0
                
                let intervalMillis = self.intervalSeconds > 0 ? self.intervalSeconds * 1000 : self.intervalMinutes * 60000
                self.expectedRemindersFired = self.accumulatedMillis / (intervalMillis > 0 ? intervalMillis : 1)
                
                print("[ReminderManager] ▶️ RESUME — intervalMin=\(self.intervalMinutes), intervalSec=\(self.intervalSeconds), sound=\(self.soundEnabled), haptics=\(self.hapticsEnabled), accumulated=\(self.accumulatedMillis)ms")
                
                self.startTimer()
                
            case "update":
                self.intervalMinutes = args?["intervalMinutes"] as? Int ?? 0
                self.intervalSeconds = args?["intervalSeconds"] as? Int ?? 0
                self.soundEnabled = args?["soundEnabled"] as? Bool ?? false
                self.hapticsEnabled = args?["hapticsEnabled"] as? Bool ?? false
                print("[ReminderManager] 🔄 UPDATE — intervalMin=\(self.intervalMinutes), intervalSec=\(self.intervalSeconds), sound=\(self.soundEnabled), haptics=\(self.hapticsEnabled)")
                
            case "stop":
                print("[ReminderManager] ⏹ STOP")
                self.stopTimer()
                
            default:
                print("[ReminderManager] ⚠️ Unknown method: \(call.method)")
                break
            }
        }
        
        // Return success immediately on the main thread
        result(nil)
    }
    
    private func startTimer() {
        stopTimer()
        startTime = Date()
        
        print("[ReminderManager] ⏱ Timer STARTED (500ms tick)")
        
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: .milliseconds(500))
        timer?.setEventHandler { [weak self] in
            self?.checkReminder()
        }
        timer?.resume()
    }
    
    private func stopTimer() {
        let wasRunning = timer != nil
        timer?.cancel()
        timer = nil
        startTime = nil
        if wasRunning {
            print("[ReminderManager] ⏱ Timer STOPPED")
        }
    }
    
    private func checkReminder() {
        guard let start = startTime else {
            // Throttled log
            let now = Date()
            if now.timeIntervalSince(lastDiagLogTime) > 10 {
                lastDiagLogTime = now
                print("[ReminderManager] ⚠️ checkReminder: startTime is nil")
            }
            return
        }
        guard intervalSeconds > 0 || intervalMinutes > 0 else {
            let now = Date()
            if now.timeIntervalSince(lastDiagLogTime) > 10 {
                lastDiagLogTime = now
                print("[ReminderManager] ⚠️ checkReminder: intervalSec=\(intervalSeconds), intervalMin=\(intervalMinutes) — both zero, skipping")
            }
            return
        }
        
        let elapsedNowMillis = accumulatedMillis + Int(Date().timeIntervalSince(start) * 1000)
        
        let intervalMillis = intervalSeconds > 0 ? intervalSeconds * 1000 : intervalMinutes * 60000
        let expected = elapsedNowMillis / intervalMillis
        
        // Diagnostic log every 10 seconds
        let now = Date()
        if now.timeIntervalSince(lastDiagLogTime) > 10 {
            lastDiagLogTime = now
            print("[ReminderManager] 🔍 TICK — elapsed=\(elapsedNowMillis)ms, intervalMs=\(intervalMillis), expected=\(expected), fired=\(expectedRemindersFired), sound=\(soundEnabled), player=\(audioPlayer != nil ? "OK" : "NIL")")
        }
        
        if expected > expectedRemindersFired {
            expectedRemindersFired = expected
            print("[ReminderManager] 🔔 FIRING reminder #\(expectedRemindersFired) at elapsed=\(elapsedNowMillis)ms")
            playReminder()
        }
    }
    
    private func playReminder() {
        print("[ReminderManager] 🔊 playReminder() — sound=\(soundEnabled), haptics=\(hapticsEnabled), audioPlayer=\(audioPlayer != nil ? "LOADED" : "NIL")")
        
        if soundEnabled {
            // Ensure audio session is configured for playback during recording
            let session = AVAudioSession.sharedInstance()
            print("[ReminderManager] 🔊 Current AVAudioSession: category=\(session.category.rawValue), mode=\(session.mode.rawValue), options=\(session.categoryOptions.rawValue)")
            
            do {
                try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth])
                try session.setActive(true)
                print("[ReminderManager] 🔊 AVAudioSession configured for playAndRecord+mixWithOthers")
            } catch {
                print("[ReminderManager] ❌ AVAudioSession config FAILED: \(error)")
            }
            
            if audioPlayer == nil {
                print("[ReminderManager] ⚠️ audioPlayer is NIL — attempting lazy reload...")
                preloadAudio()
            }
            
            if let player = audioPlayer {
                player.volume = 1.0
                player.currentTime = 0
                let success = player.play()
                print("[ReminderManager] 🔊 player.play() returned \(success), isPlaying=\(player.isPlaying), duration=\(player.duration)s, volume=\(player.volume)")
            } else {
                print("[ReminderManager] ❌❌ audioPlayer STILL NIL after reload — no sound will play!")
            }
        } else {
            print("[ReminderManager] 🔇 sound disabled — skipping audio")
        }
        
        if hapticsEnabled {
            AudioServicesPlaySystemSound(4095)
            print("[ReminderManager] 📳 Vibration triggered")
        }
    }
}
