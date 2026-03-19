import Combine

/// Subscribes to a publisher, deduplicating identical consecutive values,
/// and calls `onChange` whenever a new distinct value arrives.
///
/// Use this instead of a plain `.sink` when you only care that the value
/// changed, not what the new value is — and want to avoid redundant work
/// when a published property is set to its existing value.
public func observeEquatable<P: Publisher>(
    _ publisher: P,
    storeIn cancellables: inout [AnyCancellable],
    onChange: @escaping () -> Void
) where P.Output: Equatable, P.Failure == Never {
    publisher
        .removeDuplicates()
        .sink { _ in
            onChange()
        }
        .store(in: &cancellables)
}
