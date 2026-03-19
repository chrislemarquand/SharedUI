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
            Group {
                if let image = snapshotImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    Color(nsColor: .windowBackgroundColor)
                }
            }
            .task(id: taskKey(geometry.size)) {
                snapshotImage = await makeSnapshot(size: geometry.size)
            }
        }
    }

    private func taskKey(_ size: CGSize) -> String {
        "\(coordinate.latitude),\(coordinate.longitude),\(Int(size.width)),\(Int(size.height))"
    }

    @MainActor
    private func makeSnapshot(size: CGSize) async -> NSImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        )
        options.size = size
        guard let snapshot = try? await MKMapSnapshotter(options: options).start() else { return nil }

        // Composite a pin onto the snapshot image.
        // lockFocusFlipped(true) gives a top-left origin / y-down coordinate space,
        // which matches the coordinate space of snapshot.point(for:).
        let baseImage = snapshot.image
        let result = NSImage(size: baseImage.size)
        result.lockFocusFlipped(true)
        baseImage.draw(in: NSRect(origin: .zero, size: baseImage.size))
        let pinPoint = snapshot.point(for: coordinate)
        let pinSize: CGFloat = 22
        if let pin = NSImage(systemSymbolName: "mappin.circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(paletteColors: [.white, .systemRed])) {
            pin.draw(in: NSRect(
                x: pinPoint.x - pinSize / 2,
                y: pinPoint.y - pinSize / 2,
                width: pinSize,
                height: pinSize
            ))
        }
        result.unlockFocus()
        return result
    }
}
