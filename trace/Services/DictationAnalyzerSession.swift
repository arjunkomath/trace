import AVFoundation
import CoreMedia
import Foundation
import Speech

final class DictationAnalyzerSession {
    enum SessionError: LocalizedError {
        case unsupportedAudioFormat
        case missingInputNodeFormat
        case conversionFailed
        case noAnalyzer

        var errorDescription: String? {
            switch self {
            case .unsupportedAudioFormat:
                return "Dictation could not find a compatible audio format."
            case .missingInputNodeFormat:
                return "Trace could not read the microphone input format."
            case .conversionFailed:
                return "Trace could not convert microphone audio for dictation."
            case .noAnalyzer:
                return "Dictation session was not started."
            }
        }
    }

    private let locale: Locale
    private let logger = AppLogger.dictation
    private let audioEngine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzeTask: Task<CMTime?, Error>?
    private var resultTask: Task<String, Error>?
    private var converter: DictationBufferConverter?
    private var lastAudioLevelEmitTime: TimeInterval = 0

    var onAudioLevel: ((Float) -> Void)?

    init(locale: Locale) {
        self.locale = locale
    }

    func start() async throws {
        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
        let analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .lingering)
        )
        self.analyzer = analyzer

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw SessionError.missingInputNodeFormat
        }

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber], considering: inputFormat) else {
            throw SessionError.unsupportedAudioFormat
        }

        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        try Task.checkCancellation()

        let streamPair = AsyncStream<AnalyzerInput>.makeStream(bufferingPolicy: .bufferingNewest(32))
        inputContinuation = streamPair.continuation
        converter = DictationBufferConverter(inputFormat: inputFormat, outputFormat: analyzerFormat)

        resultTask = Task {
            var finalText = ""
            var latest = ""

            for try await result in transcriber.results {
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    latest = text
                }
                if result.isFinal, !text.isEmpty {
                    if !finalText.isEmpty { finalText += " " }
                    finalText += text
                }
            }

            return finalText.isEmpty ? latest : finalText
        }

        analyzeTask = Task {
            try await analyzer.analyzeSequence(streamPair.stream)
        }

        try Task.checkCancellation()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.handleAudioBuffer(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    func stop() async throws -> String {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        inputContinuation?.finish()
        inputContinuation = nil

        guard let analyzer else { throw SessionError.noAnalyzer }
        defer { cleanup() }

        let lastSampleTime = try await analyzeTask?.value

        try await withTimeout(seconds: 8) {
            if let lastSampleTime, lastSampleTime.isValid {
                try await analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
            }
        }

        let transcript = (try await resultTask?.value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return transcript
    }

    func cancel() async {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        inputContinuation?.finish()
        await analyzer?.cancelAndFinishNow()
        cleanup()
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let inputContinuation else { return }

        emitAudioLevel(from: buffer)

        do {
            if let converted = try converter?.convert(buffer) {
                inputContinuation.yield(AnalyzerInput(buffer: converted))
            }
        } catch {
            logger.error("Dictation audio conversion failed: \(error.localizedDescription)")
        }
    }

    private func emitAudioLevel(from buffer: AVAudioPCMBuffer) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastAudioLevelEmitTime >= 1.0 / 60.0 else { return }

        lastAudioLevelEmitTime = now
        onAudioLevel?(DictationAudioLevelMeter.normalizedLevel(from: buffer))
    }

    private func cleanup() {
        analyzeTask?.cancel()
        resultTask?.cancel()
        analyzeTask = nil
        resultTask = nil
        analyzer = nil
        converter = nil
    }
}

private enum DictationAudioLevelMeter {
    static func normalizedLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        guard channelCount > 0, frameLength > 0 else { return 0 }

        var squareSum: Double = 0
        for channel in 0..<channelCount {
            let samples = channelData[channel]
            for frame in 0..<frameLength {
                let sample = Double(samples[frame])
                squareSum += sample * sample
            }
        }

        let rms = sqrt(squareSum / Double(channelCount * frameLength))
        guard rms.isFinite else { return 0 }

        let decibels = 20 * log10(max(rms, 0.000_01))
        let normalized = (decibels + 55) / 45
        let clamped = max(0, min(1, normalized))
        return Float(pow(clamped, 0.7))
    }
}

private final class DictationBufferConverter {
    private let outputFormat: AVAudioFormat
    private let converter: AVAudioConverter?
    private let lock = NSLock()

    init(inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) {
        self.outputFormat = outputFormat
        self.converter = inputFormat == outputFormat ? nil : AVAudioConverter(from: inputFormat, to: outputFormat)
    }

    func convert(_ buffer: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        guard let converter else { return buffer }

        lock.lock()
        defer { lock.unlock() }

        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 8
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw DictationAnalyzerSession.SessionError.conversionFailed
        }

        var didProvideInput = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if didProvideInput {
                outStatus.pointee = .noDataNow
                return nil
            }

            didProvideInput = true
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error || conversionError != nil {
            throw conversionError ?? DictationAnalyzerSession.SessionError.conversionFailed
        }

        return outputBuffer
    }
}

private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw CancellationError()
        }

        guard let result = try await group.next() else { throw CancellationError() }
        group.cancelAll()
        return result
    }
}
