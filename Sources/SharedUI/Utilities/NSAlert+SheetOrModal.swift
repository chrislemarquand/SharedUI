import AppKit

public extension NSAlert {
    @MainActor
    func runSheetOrModal(
        for window: NSWindow?,
        completion: @escaping (NSApplication.ModalResponse) -> Void
    ) {
        if let window {
            beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(runModal())
        }
    }

    @MainActor
    func runSheetOrModal(for window: NSWindow?) async -> NSApplication.ModalResponse {
        if let window {
            return await withCheckedContinuation { continuation in
                beginSheetModal(for: window) { response in
                    continuation.resume(returning: response)
                }
            }
        }
        return runModal()
    }
}
