import SwiftUI
import UIKit

private enum CachedAsyncImageError: Error {
    case invalidImageData
}

private final class SharedImageMemoryCache {
    static let shared = SharedImageMemoryCache()

    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 512
        cache.totalCostLimit = 128 * 1_024 * 1_024
        return cache
    }()

    private init() { }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func insert(_ image: UIImage, for url: URL) {
        let pixelCount = image.size.width * image.size.height * image.scale * image.scale
        let cost = max(1, Int(pixelCount * 4))
        cache.setObject(image, forKey: url as NSURL, cost: cost)
    }
}

private actor SharedImagePipeline {
    static let shared = SharedImagePipeline()

    // Dedykowana sesja z dużym, trwałym URLCache — przeżywa restart aplikacji,
    // więc drugie uruchomienie trafia w dysk zamiast kolejnego pobrania z sieci.
    private nonisolated let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 32 * 1_024 * 1_024,
            diskCapacity: 256 * 1_024 * 1_024,
            diskPath: "com.weeklymeals.imagecache.http"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpMaximumConnectionsPerHost = 8
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    func image(for url: URL) async throws -> UIImage {
        if let cached = SharedImageMemoryCache.shared.image(for: url) {
            return cached
        }

        if let task = inFlight[url] {
            return try await task.value
        }

        let task = makeFetchTask(url: url)
        inFlight[url] = task
        defer { inFlight[url] = nil }
        return try await task.value
    }

    func prefetch(_ urls: [URL]) {
        for url in urls {
            guard SharedImageMemoryCache.shared.image(for: url) == nil,
                  inFlight[url] == nil else { continue }
            // Reuse ten sam tor co zwykły fetch — defer w image(for:) sprząta inFlight,
            // więc nie ma ryzyka wyścigu z równoległym zapotrzebowaniem na ten sam URL.
            Task { [weak self] in
                _ = try? await self?.image(for: url)
            }
        }
    }

    private func makeFetchTask(url: URL) -> Task<UIImage, Error> {
        let session = self.session
        return Task.detached(priority: .userInitiated) {
            let (data, _) = try await session.data(from: url)
            guard let decoded = await Self.decode(data: data) else {
                throw CachedAsyncImageError.invalidImageData
            }
            SharedImageMemoryCache.shared.insert(decoded, for: url)
            return decoded
        }
    }

    private static func decode(data: Data) async -> UIImage? {
        guard let image = UIImage(data: data) else { return nil }
        // byPreparingForDisplay dekoduje poza main threadem — bez tego pierwszy render
        // obrazu blokuje scroll i wywołuje efekt „wyskakiwania”.
        return await image.byPreparingForDisplay() ?? image
    }
}

/// Warmuje cache obrazów dla przyszłych widoków — wołaj gdy znasz URL-e wcześniej
/// niż pojawią się na ekranie (np. po załadowaniu listy przepisów / stronicowaniu).
enum ImagePrefetcher {
    static func prefetch(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task.detached(priority: .utility) {
            await SharedImagePipeline.shared.prefetch(urls)
        }
    }
}

struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase

    init(url: URL?, @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.content = content
        _phase = State(initialValue: Self.initialPhase(for: url))
    }

    var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }

    private func loadImage() async {
        guard let url else {
            phase = .empty
            return
        }

        let cachedPhase = Self.initialPhase(for: url)
        phase = cachedPhase
        if case .success = cachedPhase {
            return
        }

        do {
            let image = try await SharedImagePipeline.shared.image(for: url)
            phase = .success(Image(uiImage: image))
        } catch is CancellationError {
            return
        } catch {
            phase = .failure(error)
        }
    }

    private static func initialPhase(for url: URL?) -> AsyncImagePhase {
        guard let url, let image = SharedImageMemoryCache.shared.image(for: url) else {
            return .empty
        }

        return .success(Image(uiImage: image))
    }
}
