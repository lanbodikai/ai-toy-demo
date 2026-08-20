@preconcurrency import AVFoundation
import Foundation
import OSLog

@MainActor
final class CueAudioPlayer: NSObject, StoryAudioPlaying, @preconcurrency AVAudioPlayerDelegate {
    var onPlaybackProgress: ((Double) -> Void)?

    private let logger = Logger(subsystem: "com.riselink.aitoy", category: "EdgeTTSAudio")
    private var audioPlayer: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Never>?
    private var progressTask: Task<Void, Never>?

    func play(text _: String, cueID: String) async {
        stop()
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            guard let url = bundledAudioURL(for: cueID) else {
                logger.error("Missing bundled Edge-TTS cue: \(cueID, privacy: .public)")
                finish(reportCompletion: false)
                return
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                audioPlayer = player
                player.delegate = self
                player.prepareToPlay()
                if !player.play() {
                    logger.error("Could not play bundled Edge-TTS cue: \(cueID, privacy: .public)")
                    finish(reportCompletion: false)
                } else {
                    startProgressUpdates()
                }
            } catch {
                logger.error("Could not load bundled Edge-TTS cue \(cueID, privacy: .public): \(error.localizedDescription, privacy: .public)")
                finish(reportCompletion: false)
            }
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        finish(reportCompletion: false)
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        audioPlayer = nil
        finish(reportCompletion: flag)
    }

    private func startProgressUpdates() {
        progressTask?.cancel()
        onPlaybackProgress?(0)
        progressTask = Task { [weak self] in
            while !Task.isCancelled, let self, let player = self.audioPlayer {
                let progress = player.duration > 0 ? player.currentTime / player.duration : 0
                self.onPlaybackProgress?(min(max(progress, 0), 1))
                try? await Task.sleep(for: .milliseconds(120))
            }
        }
    }

    private func finish(reportCompletion: Bool) {
        progressTask?.cancel()
        progressTask = nil
        if reportCompletion {
            onPlaybackProgress?(1)
        }
        let pending = continuation
        continuation = nil
        pending?.resume()
    }

    private func bundledAudioURL(for cueID: String) -> URL? {
        for fileExtension in ["m4a", "mp3"] {
            if let url = Bundle.main.url(
                forResource: cueID,
                withExtension: fileExtension,
                subdirectory: "Audio"
            ) {
                return url
            }
        }
        return nil
    }
}
