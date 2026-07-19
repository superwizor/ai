import Foundation
import Flutter
import AVFoundation
import AudioToolbox

class ReminderManager {
    static let shared = ReminderManager()
    
    private var timer: DispatchSourceTimer?
    private var audioPlayer: AVAudioPlayer?
    
    private var intervalMinutes: Int = 0
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
        guard let url = Bundle.main.url(forResource: "SFX_session_end", withExtension: "mp3", subdirectory: "flutter_assets/assets/sounds") else {
            print("[ReminderManager] Failed to find SFX_session_end.mp3")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        } catch {
            print("[ReminderManager] Failed to load AVAudioPlayer: \(error)")
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
                self.soundEnabled = args?["soundEnabled"] as? Bool ?? false
                self.hapticsEnabled = args?["hapticsEnabled"] as? Bool ?? false
                self.accumulatedMillis = args?["elapsedMillis"] as? Int ?? 0
                
                self.expectedRemindersFired = self.accumulatedMillis / (self.intervalMinutes > 0 ? self.intervalMinutes * 60000 : 1)
                
                self.startTimer()
                
            case "pause":
                self.accumulatedMillis = args?["elapsedMillis"] as? Int ?? 0
                self.stopTimer()
                
            case "resume":
                self.intervalMinutes = args?["intervalMinutes"] as? Int ?? 0
                self.soundEnabled = args?["soundEnabled"] as? Bool ?? false
                self.hapticsEnabled = args?["hapticsEnabled"] as? Bool ?? false
                self.accumulatedMillis = args?["elapsedMillis"] as? Int ?? 0
                
                self.expectedRemindersFired = self.accumulatedMillis / (self.intervalMinutes > 0 ? self.intervalMinutes * 60000 : 1)
                
                self.startTimer()
                
            case "update":
                self.intervalMinutes = args?["intervalMinutes"] as? Int ?? 0
                self.soundEnabled = args?["soundEnabled"] as? Bool ?? false
                self.hapticsEnabled = args?["hapticsEnabled"] as? Bool ?? false
                
            case "stop":
                self.stopTimer()
                
            default:
                break
            }
        }
        
        // Return success immediately on the main thread
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
        guard let start = startTime, intervalMinutes > 0 else { return }
        let elapsedNowMillis = accumulatedMillis + Int(Date().timeIntervalSince(start) * 1000)
        
        let expected = elapsedNowMillis / (intervalMinutes * 60000)
        if expected > expectedRemindersFired {
            expectedRemindersFired = expected
            playReminder()
        }
    }
    
    private func playReminder() {
        if soundEnabled {
            // We use playAndRecord during recording in Dart, so this AVPlayer will automatically
            // bypass the silent switch because the underlying AVAudioSession is playAndRecord + mixWithOthers.
            audioPlayer?.currentTime = 0
            audioPlayer?.play()
        }
        if hapticsEnabled {
            // kSystemSoundID_Vibrate is 4095
            AudioServicesPlaySystemSound(4095)
        }
    }
}
