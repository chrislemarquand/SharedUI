import Foundation

@MainActor
public final class MainActorCoalescer {
    private var isScheduled = false

    public init() {}

    public func schedule(_ work: @escaping @MainActor () -> Void) {
        guard !isScheduled else { return }
        isScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isScheduled = false
            work()
        }
    }

    public func reset() {
        isScheduled = false
    }
}
