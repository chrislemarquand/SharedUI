import AppKit
import MapKit
import SwiftUI

// Renders a static map snapshot via MKMapSnapshotter — no live MKMapView display link.
public struct InspectorLocationMapView: View {
    let coordinate: CLLocationCoordinate2D
    @State private var snapshotImage: NSImage?

    public init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = snapshotImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    Color(nsColor: .windowBackgroundColor)
                }

                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color(nsColor: .systemRed))
            }
            .clipped()
            .task(id: requestKey(for: geometry.size)) {
                guard let request = requestKey(for: geometry.size) else { return }

                // Debounce resize/scroll churn so we don't re-snapshot on every geometry tick.
                try? await Task.sleep(nanoseconds: 180_000_000)
                guard !Task.isCancelled else { return }

                let image = await InspectorMapSnapshotPipeline.shared.snapshot(for: request)
                guard !Task.isCancelled, let image else { return }
                snapshotImage = image
            }
        }
    }

    private func requestKey(for size: CGSize) -> InspectorMapSnapshotRequest? {
        InspectorMapSnapshotRequest.make(
            coordinate: coordinate,
            size: size
        )
    }
}

private struct InspectorMapSnapshotRequest: Hashable {
    let latitudeE6: Int
    let longitudeE6: Int
    let width: Int
    let height: Int

    var cacheKey: String {
        "\(latitudeE6),\(longitudeE6),\(width),\(height)"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: Double(latitudeE6) / 1_000_000.0,
            longitude: Double(longitudeE6) / 1_000_000.0
        )
    }

    var size: CGSize {
        CGSize(width: width, height: height)
    }

    static func make(
        coordinate: CLLocationCoordinate2D,
        size: CGSize
    ) -> InspectorMapSnapshotRequest? {
        guard size.width > 0, size.height > 0 else { return nil }

        // Quantize size so live resize/scroll doesn't flood snapshot work.
        let width = quantize(size.width)
        let height = quantize(size.height)

        return InspectorMapSnapshotRequest(
            latitudeE6: Int((coordinate.latitude * 1_000_000.0).rounded()),
            longitudeE6: Int((coordinate.longitude * 1_000_000.0).rounded()),
            width: width,
            height: height
        )
    }

    private static func quantize(_ value: CGFloat) -> Int {
        let bucket: CGFloat = 24
        let rounded = (value / bucket).rounded(.toNearestOrEven) * bucket
        return max(Int(rounded), Int(bucket))
    }
}

private final class InspectorMapSnapshotPipeline: @unchecked Sendable {
    static let shared = InspectorMapSnapshotPipeline()

    private let lock = NSLock()
    private let cache = NSCache<NSString, NSImage>()
    private var inFlight: [String: Task<NSImage?, Never>] = [:]

    private init() {
        cache.countLimit = 64
    }

    func snapshot(for request: InspectorMapSnapshotRequest) async -> NSImage? {
        let key = request.cacheKey

        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }

        let existingTask: Task<NSImage?, Never>? = withLock {
            inFlight[key]
        }
        if let existingTask {
            return await existingTask.value
        }

        let task = Task(priority: .utility) { [request] in
            await Self.renderSnapshot(for: request)
        }

        withLock {
            inFlight[key] = task
        }

        let image = await task.value

        if let image {
            cache.setObject(image, forKey: key as NSString)
        }

        _ = withLock {
            inFlight.removeValue(forKey: key)
        }

        return image
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private static func renderSnapshot(for request: InspectorMapSnapshotRequest) async -> NSImage? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: request.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        )
        options.size = request.size
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }
        return snapshot.image
    }
}
