import AppKit
import Vision

/// Screenshot-to-text via the system Vision framework: zero extra size,
/// fully offline, same engine Bob/Easydict use. First use asks for the
/// Screen Recording permission (system prompt).
enum OCRService {
    enum OCRError: LocalizedError {
        case captureCancelled
        case noText

        var errorDescription: String? {
            switch self {
            case .captureCancelled: return nil
            case .noText: return L10n.t("ocr.noText")
            }
        }
    }

    /// Interactive region capture using the system screencapture tool
    /// (crosshair selection, Esc cancels). Returns the captured image.
    static func captureRegion() async throws -> CGImage {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("uyiprompt-ocr-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: file) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", "-t", "png", file.path]
        try process.run()
        await withCheckedContinuation { continuation in
            process.terminationHandler = { _ in continuation.resume() }
        }

        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw OCRError.captureCancelled }
        return image
    }

    /// Accurate-level recognition, Chinese-first language priority.
    static func recognize(_ image: CGImage) async throws -> String {
        let text: String = try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja-JP", "ko-KR"]
            let handler = VNImageRequestHandler(cgImage: image)
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw OCRError.noText }
        return trimmed
    }

    /// Capture a region, recognize it, and return the text.
    static func captureText() async throws -> String {
        let image = try await captureRegion()
        return try await recognize(image)
    }
}
