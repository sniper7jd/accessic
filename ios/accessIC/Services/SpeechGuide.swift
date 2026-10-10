import Foundation

#if canImport(AVFoundation)
import AVFoundation

@MainActor
final class SpeechGuide {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func announceRoute(_ route: RouteResult) {
        if route.isPrototype {
            speak("Prototype route only. Not a verified Whalen navigation path.")
        }
        if let first = route.steps.first {
            speak(first.instruction)
        } else {
            speak("You have arrived.")
        }
    }
}
#else
@MainActor
final class SpeechGuide {
    func speak(_ text: String) {}
    func stop() {}
    func announceRoute(_ route: RouteResult) {}
}
#endif
