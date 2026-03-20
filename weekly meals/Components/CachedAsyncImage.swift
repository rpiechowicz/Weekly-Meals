import SwiftUI
import UIKit

private enum CachedAsyncImageError: Error {
    case invalidImageData
}

private final class SharedImageMemoryCache {
    static let shared = SharedImageMemoryCache()

    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 256
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

    private var inFlightTasks: [URL: Task<UIImage, Error>] = [:]

    func image(for url: URL) async throws -> UIImage {
        if let cachedImage = SharedImageMemoryCache.shared.image(for: url) {
            return cachedImage
        }

        if let inFlightTask = inFlightTasks[url] {
            return try await inFlightTask.value
        }

        let request = URLRequest(
            url: url,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 60
        )

        let task = Task<UIImage, Error> {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let image = UIImage(data: data) else {
                throw CachedAsyncImageError.invalidImageData
            }
            SharedImageMemoryCache.shared.insert(image, for: url)
            return image
        }

        inFlightTasks[url] = task
        defer { inFlightTasks[url] = nil }
        return try await task.value
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
