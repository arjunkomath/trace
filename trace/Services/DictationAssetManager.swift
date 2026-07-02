import Foundation
import Speech

@MainActor
final class DictationAssetManager: ObservableObject {
    static let shared = DictationAssetManager()

    enum AssetState: Equatable {
        case checking
        case unsupported
        case supportedNeedsDownload(Locale)
        case downloading(Locale, Double)
        case installed(Locale)
        case failed(String)

        var isReady: Bool {
            if case .installed = self { return true }
            return false
        }
    }

    @Published private(set) var state: AssetState = .checking

    private let logger = AppLogger.dictation
    private var progressTask: Task<Void, Never>?

    var resolvedLocale: Locale? {
        switch state {
        case .supportedNeedsDownload(let locale), .downloading(let locale, _), .installed(let locale):
            return locale
        case .checking, .unsupported, .failed:
            return nil
        }
    }

    private init() {}

    func refresh() async {
        state = .checking

        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale.current) else {
            state = .unsupported
            return
        }

        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)
        let status = await AssetInventory.status(forModules: [transcriber])

        switch status {
        case .installed:
            state = .installed(locale)
        case .supported, .downloading:
            state = .supportedNeedsDownload(locale)
        case .unsupported:
            state = .unsupported
        @unknown default:
            state = .failed("Unknown dictation asset status.")
        }
    }

    func download() async {
        let locale: Locale?
        if let resolvedLocale {
            locale = resolvedLocale
        } else {
            locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale.current)
        }
        guard let locale else {
            state = .unsupported
            return
        }

        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveShortDictation)

        do {
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                state = .installed(locale)
                return
            }

            state = .downloading(locale, request.progress.fractionCompleted)
            observeProgress(request.progress, locale: locale)
            try await request.downloadAndInstall()
            progressTask?.cancel()
            progressTask = nil
            state = .installed(locale)
        } catch {
            progressTask?.cancel()
            progressTask = nil
            logger.error("Dictation asset download failed: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    private func observeProgress(_ progress: Progress, locale: Locale) {
        progressTask?.cancel()
        progressTask = Task { @MainActor [weak self] in
            while !Task.isCancelled && !progress.isFinished {
                self?.state = .downloading(locale, progress.fractionCompleted)
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }
}
