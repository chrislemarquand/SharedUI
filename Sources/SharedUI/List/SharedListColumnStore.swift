import Foundation

/// Shared list column persistence used by host apps.
///
/// NSTableView autosave handles width/order. This store handles visibility and
/// initial-fit sentinel keys so host apps can keep existing defaults behavior.
public struct SharedListColumnStore {
    private let defaults: UserDefaults
    private let visibleKey: String
    private let initialFitKey: String

    public init(
        defaults: UserDefaults = .standard,
        visibleKey: String,
        initialFitKey: String
    ) {
        self.defaults = defaults
        self.visibleKey = visibleKey
        self.initialFitKey = initialFitKey
    }

    public func isVisible(_ definition: SharedListColumnDefinition) -> Bool {
        guard let raw = defaults.array(forKey: visibleKey) as? [String] else {
            return definition.defaultIsVisible
        }
        return Set(raw).contains(definition.id)
    }

    public func setVisible(_ columnID: String, _ visible: Bool, allDefinitions: [SharedListColumnDefinition]) {
        var currentVisible = Set(defaults.array(forKey: visibleKey) as? [String] ?? allDefinitions
            .filter(\.defaultIsVisible)
            .map(\.id))
        if visible {
            currentVisible.insert(columnID)
        } else {
            currentVisible.remove(columnID)
        }
        defaults.set(Array(currentVisible), forKey: visibleKey)
    }

    public var hasAppliedInitialFit: Bool {
        get { defaults.bool(forKey: initialFitKey) }
        set { defaults.set(newValue, forKey: initialFitKey) }
    }
}

