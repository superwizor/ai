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
    
    // We use a serial background queue with default QoS to avoid iOS aggressive suspension of .background tasks
    private let queue = DispatchQueue(label: "ai.superwizor.reminderQueue", qos: .default)
    
    private init() {
        preloadAudio()
    }
    
    private func preloadAudio() {
        // Strategy 1: Flutter's official asset lookup API
        // FlutterDartProject.lookupKey(forAsset:) returns the correct
        // bundle-relative path for a Flutter asset (e.g. "flutter_assets/assets/sounds/SFX_session_end_2.mp3")
        let filesToTry = ["SFX_session_end_2.mp3", "SFX_session_end.mp3"]
        
        for filename in filesToTry {
            let assetKey = FlutterDartProject.lookupKey(forAsset: "assets/sounds/\(filename)")
            
            if let url = Bundle.main.url(forResource: assetKey, withExtension: nil) {
                if loadPlayer(from: url) { return }
            }
            
            // Strategy 2: Direct subdirectory lookup (legacy approach)
            if let url = Bundle.main.url(forResource: filename.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3", subdirectory: "flutter_assets/assets/sounds") {
                if loadPlayer(from: url) { return }
            }
            
            // Strategy 3: Construct path manually
            let manualPath = Bundle.main.bundlePath + "/Frameworks/App.framework/flutter_assets/assets/sounds/\(filename)"
            if FileManager.default.fileExists(atPath: manualPath) {
                let url = URL(fileURLWithPath: manualPath)
                if loadPlayer(from: url) { return }
            }
        }
    }
    
    private func loadPlayer(from url: URL) -> Bool {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            return true
        } catch {
            print("[ReminderManager] AVAudioPlayer init failed: \(error)")
            return false
        }
    }
    
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "ai.superwizor/reminder_service", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            shared.handle(call, result: result)
        }
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
                
                self.startTimer()
                
            case "pause":
                self.accumulatedMillis = args?["elapsedMillis"] as? Int ?? 0
                self.stopTimer()
                
            case "resume":
                self.intervalMinutes = args?["intervalMinutes"] as? Int ?? 0
                self.intervalSeconds = args?["intervalSeconds"] as? Int ?? 0
                self.soundEnabled = args?["soundEnabled"] as? Bool ?? false
                self.hapticsEnabled = args?["hapticsEnabled"] as? Bool ?? false
                self.accumulatedMillis = args?["elapsedMillis"] as? Int ?? 0
                
                let intervalMillis = self.intervalSeconds > 0 ? self.intervalSeconds * 1000 : self.intervalMinutes * 60000
                self.expectedRemindersFired = self.accumulatedMillis / (intervalMillis > 0 ? intervalMillis : 1)
                
                self.startTimer()
                
            case "update":
                self.intervalMinutes = args?["intervalMinutes"] as? Int ?? 0
                self.intervalSeconds = args?["intervalSeconds"] as? Int ?? 0
                self.soundEnabled = args?["soundEnabled"] as? Bool ?? false
                self.hapticsEnabled = args?["hapticsEnabled"] as? Bool ?? false
                
            case "stop":
                self.stopTimer()
                
            default:
                break
            }
        }
        
        result(nil)
    }
    
    private func startTimer() {
        stopTimer()
        startTime = Date()
        
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: .milliseconds(500))
        timer?.setEventHandler { [weak self] in
            self?.checkReminder()
        }
        timer?.resume()
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
        startTime = nil
    }
    
    private func checkReminder() {
        guard let start = startTime else { return }
        guard intervalSeconds > 0 || intervalMinutes > 0 else { return }
        
        let elapsedNowMillis = accumulatedMillis + Int(Date().timeIntervalSince(start) * 1000)
        
        let intervalMillis = intervalSeconds > 0 ? intervalSeconds * 1000 : intervalMinutes * 60000
        let expected = elapsedNowMillis / intervalMillis
        
        if expected > expectedRemindersFired {
            expectedRemindersFired = expected
            playReminder()
        }
    }
    
    private func playReminder() {
        if soundEnabled {
            let session = AVAudioSession.sharedInstance()
            
            do {
                try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetooth])
                try session.setActive(true)
            } catch {
                print("[ReminderManager] AVAudioSession config failed: \(error)")
            }
            
            if audioPlayer == nil {
                preloadAudio()
            }
            
            if let player = audioPlayer {
                player.volume = 1.0
                player.currentTime = 0
                player.play()
            }
        }
        
        if hapticsEnabled {
            AudioServicesPlaySystemSound(4095)
        }
    }
}
